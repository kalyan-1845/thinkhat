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
  String? _token;
  
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

  Future<bool> login(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        currentUsername = username;
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> connect(String pattern, String username, {bool isCreating = false}) async {
    try {
      // Step 1: Login to get JWT if not already logged in as this user
      if (_token == null || currentUsername != username) {
        final loginSuccess = await login(username);
        if (!loginSuccess) return false;
      }

      print('Attempting to ${isCreating ? 'create' : 'join'} room: $pattern');
      
      final body = {
        'pattern': pattern,
        'username': username,
        'mode': isCreating ? 'create' : 'join',
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/group/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentGroupId = data['group_id'];
        isCreator = data['is_creator'] ?? false;
        
        final wsUri = Uri.parse('$wsUrl/ws/$currentGroupId/$username?token=$_token');
        print('Connecting to WebSocket: $wsUri');
        
        _channel = WebSocketChannel.connect(wsUri);
        
        _channel!.stream.listen(_onMessageReceived, onError: (e) {
             print('WebSocket Stream Error: $e');
        }, onDone: () {
             print('WebSocket Closed: ${_channel?.closeCode}');
        });

        return true;
      } else {
        print('API Error (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      print('Failed to connect to backend: $e');
      return false;
    }
  }

  Future<void> destroyRoom() async {
    if (currentGroupId == null || _token == null) return;
    try {
      final uri = Uri.parse('$baseUrl/group/$currentGroupId/destroy');
      await http.post(
        uri,
        headers: {'Authorization': 'Bearer $_token'}
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
        _chatMessagesController.add(ChatMessage.fromJson({
          ...data,
          'type': 'ai_response',
          'user': 'Flow AI',
          'aiUsed': true,
        }));
      } else if (msgType == 'webrtc_signaling') {
        _signalingController.add(data);
      } else if (msgType == 'system') {
        final eventName = data['event'];
        if (eventName == 'initial-node-positions') {
           initialNodePositions = Map<String, Map<String, double>>.from(
             (data['positions'] as Map).map((k, v) => MapEntry(k as String, Map<String, double>.from((v as Map).map((k2, v2) => MapEntry(k2 as String, (v2 as num).toDouble())))))
           );
        } else if (eventName == 'initial-history') {
           final List messages = data['messages'] ?? [];
           for (var m in messages) {
             _chatMessagesController.add(ChatMessage.fromJson(m));
           }
        }
        _systemEventController.add(data);
        if (data['user'] != null && eventName != 'initial-history') {
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
    _channel!.sink.add(jsonEncode({
      'type': 'node_position_update',
      'messageId': messageId,
      'x': x,
      'y': y,
    }));
  }

  void sendChatMessage(String text, {bool aiUsed = false, String? id}) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'id': id ?? const Uuid().v4(),
      'type': 'chat',
      'user': currentUsername,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'aiUsed': aiUsed,
    }));
  }

  void askAi(String messageId) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'ask_ai',
      'messageId': messageId
    }));
  }

  void sendVoiceSignal(bool isSpeaking) {
     if (_channel == null) return;
     _channel!.sink.add(jsonEncode({
        'id': const Uuid().v4(),
        'type': 'webrtc_signaling',
        'event': 'user-speaking',
        'user': currentUsername,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'data': { 'isSpeaking': isSpeaking }
     }));
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
