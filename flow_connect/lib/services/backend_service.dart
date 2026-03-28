import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:flow_connect/models/chat_message.dart';

class BackendService {
  static const String baseUrl = 'http://localhost:8000';
  static const String wsUrl = 'ws://localhost:8000';
  
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  WebSocketChannel? _channel;
  
  final _chatMessagesController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get chatMessages => _chatMessagesController.stream;

  final _aiResponsesController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get aiResponses => _aiResponsesController.stream;

  final _signalingController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get signaling => _signalingController.stream;

  final _systemEventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get systemEvents => _systemEventController.stream;

  final _nodeUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get nodeUpdates => _nodeUpdateController.stream;

  Map<String, Map<String, double>> initialNodePositions = {};

  String? currentUsername;
  String? currentGroupId;
  bool isCreator = false;

  Future<bool> connect(String pattern, String username, {bool isCreating = false}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/group/generate?pattern=$pattern&username=$username&mode=${isCreating ? 'create' : 'join'}'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentGroupId = data['group_id'];
        currentUsername = username;
        isCreator = data['is_creator'] ?? false;
        
        final wsUri = Uri.parse('$wsUrl/ws/$currentGroupId/$username');
        _channel = WebSocketChannel.connect(wsUri);
        
        // Wrap the stream to handle its lifecycle and check for early closure
        _channel!.stream.listen(_onMessageReceived, onError: (e) {
             print('WS Error: $e');
        }, onDone: () {
             final closeCode = _channel?.closeCode;
             if (closeCode == 1008) {
               print('Connection rejected: Room is full (Policy Violation)');
             } else {
               print('WS Connection Closed with code: $closeCode');
             }
        });

        return true;
      }
      return false;
    } catch (e) {
      print('Failed to connect: $e');
      return false;
    }
  }

  Future<void> destroyRoom() async {
    if (currentGroupId == null || currentUsername == null) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/group/$currentGroupId/destroy?username=$currentUsername'),
      );
    } catch (e) {
      print('Failed to destroy room: $e');
    }
  }

  void _onMessageReceived(dynamic event) {
    try {
      final Map<String, dynamic> data = jsonDecode(event as String);
      final msgType = data['type'];

      if (msgType == 'chat') {
        _chatMessagesController.add(ChatMessage.fromJson(data));
      } else if (msgType == 'ai_response') {
        _aiResponsesController.add(data);
      } else if (msgType == 'webrtc_signaling') {
        _signalingController.add(data);
      } else if (msgType == 'system') {
        if (data['event'] == 'initial-node-positions') {
           initialNodePositions = Map<String, Map<String, double>>.from(
             (data['positions'] as Map).map((k, v) => MapEntry(k as String, Map<String, double>.from((v as Map).map((k2, v2) => MapEntry(k2 as String, (v2 as num).toDouble())))))
           );
        }
        _systemEventController.add(data);
        if (data['username'] != null) {
          _chatMessagesController.add(ChatMessage.fromJson(data));
        }
      } else if (msgType == 'node_position_update') {
        _nodeUpdateController.add(data);
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  void updateNodePosition(String messageId, double x, double y) {
    if (_channel == null) return;
    
    final msg = {
      'type': 'node_position_update',
      'messageId': messageId,
      'x': x,
      'y': y,
    };
    
    _channel!.sink.add(jsonEncode(msg));
  }

  void sendChatMessage(String text, {bool aiUsed = false, String? id}) {
    if (_channel == null) return;
    
    final msg = {
      'id': id ?? const Uuid().v4(),
      'type': 'chat',
      'user': currentUsername,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'aiUsed': aiUsed,
    };
    
    _channel!.sink.add(jsonEncode(msg));
  }

  void askAi(String messageId) {
    if (_channel == null) return;
    final msg = {
      'type': 'ask_ai',
      'messageId': messageId
    };
    _channel!.sink.add(jsonEncode(msg));
  }

  void sendVoiceSignal(bool isSpeaking) {
     if (_channel == null) return;
     
     final msg = {
        'id': const Uuid().v4(),
        'type': 'webrtc_signaling',
        'event': 'user-speaking',
        'user': currentUsername,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'data': { 'isSpeaking': isSpeaking }
     };

     _channel!.sink.add(jsonEncode(msg));
  }

  void dispose() {
    _channel?.sink.close();
    _chatMessagesController.close();
    _aiResponsesController.close();
    _signalingController.close();
    _systemEventController.close();
    _nodeUpdateController.close();
  }
}
