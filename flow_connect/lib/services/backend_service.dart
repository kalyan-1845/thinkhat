import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:flow_connect/models/chat_message.dart';

class BackendService {
  static const String domain = '127.0.0.1:8000';
  static const String baseUrl = 'http://$domain';
  static const String wsUrl = 'ws://$domain';
  
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
      print('Attempting to ${isCreating ? 'create' : 'join'} room with pattern: $pattern');
      
      final body = {
        'pattern': pattern,
        'username': username,
        'mode': isCreating ? 'create' : 'join',
      };
      
      final url = Uri.parse('$baseUrl/group/generate');
      print('API URL: $url');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      
      print('API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentGroupId = data['group_id'];
        currentUsername = username;
        isCreator = data['is_creator'] ?? false;
        
        final wsUri = Uri.parse('$wsUrl/ws/$currentGroupId/$username');
        print('Connecting to WebSocket: $wsUri');
        
        _channel = WebSocketChannel.connect(wsUri);
        
        _channel!.stream.listen(_onMessageReceived, onError: (e) {
             print('WebSocket Stream Error: $e');
        }, onDone: () {
             final closeCode = _channel?.closeCode;
             print('WebSocket Closed with code: $closeCode');
        });

        return true;
      } else {
        print('API Error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Failed to connect to backend: $e');
      return false;
    }
  }

  Future<void> destroyRoom() async {
    if (currentGroupId == null || currentUsername == null) return;
    try {
      final uri = Uri.parse('$baseUrl/group/$currentGroupId/destroy?username=$currentUsername');
      await http.post(uri);
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
        
        _chatMessagesController.add(
          ChatMessage(
            id: data['id'] ?? 'ai_${data['messageId']}',
            username: 'Flow AI',
            text: data['aiReply'] ?? '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (data['timestamp'] as num).toInt() * 1000
            ),
            type: MessageType.aiResponse,
          )
        );
      } else if (msgType == 'webrtc_signaling') {
        _signalingController.add(data);
      } else if (msgType == 'system') {
        if (data['event'] == 'initial-node-positions') {
           initialNodePositions = Map<String, Map<String, double>>.from(
             (data['positions'] as Map).map((k, v) => MapEntry(k as String, Map<String, double>.from((v as Map).map((k2, v2) => MapEntry(k2 as String, (v2 as num).toDouble())))))
           );
        }
        _systemEventController.add(data);
        
        if (data['user'] != null) {
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
