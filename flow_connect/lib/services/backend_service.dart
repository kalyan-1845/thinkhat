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

  String? currentUsername;
  String? currentGroupId;

  Future<bool> connect(String pattern, String username) async {
    try {
      currentUsername = username;
      final response = await http.post(Uri.parse('$baseUrl/group/generate?pattern=$pattern'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentGroupId = data['group_id'];
        
        _channel = WebSocketChannel.connect(
          Uri.parse('$wsUrl/ws/$currentGroupId/$username'),
        );

        _channel!.stream.listen(_onMessageReceived, 
          onDone: () => print('WebSocket connection closed'),
          onError: (error) => print('WebSocket error: $error')
        );

        return true;
      }
      return false;
    } catch (e) {
      print('Failed to connect: $e');
      return false;
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
        _systemEventController.add(data);
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
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
  }
}
