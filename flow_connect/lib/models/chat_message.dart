enum MessageType { normal, question, aiResponse, important, system }

class ChatMessage {
  final String id;
  final String username; // maps to 'user' in json
  final String text;
  final DateTime timestamp;
  MessageType type;
  bool isAiTriggered; // maps to 'aiUsed' in json
  final String? parentMessageText;
  final String? parentMessageUser;
  List<ChatMessage> replies;

  ChatMessage({
    required this.id,
    required this.username,
    required this.text,
    required this.timestamp,
    this.type = MessageType.normal,
    this.isAiTriggered = false,
    this.parentMessageText,
    this.parentMessageUser,
    List<ChatMessage>? replies,
  }) : replies = replies ?? [];

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    MessageType parsedType = MessageType.normal;
    bool isAi = json['aiUsed'] ?? false;
    
    if (json['type'] == 'system') {
      parsedType = MessageType.system;
    } else if (isAi) {
      parsedType = MessageType.question;
    } else if (json['type'] == 'ai_response') {
      parsedType = MessageType.aiResponse;
    }

    return ChatMessage(
      id: json['id'] ?? '',
      username: json['user'] ?? 'Unknown',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt() * 1000) 
          : DateTime.now(),
      type: parsedType,
      isAiTriggered: isAi,
      parentMessageText: json['parent_text'],
      parentMessageUser: json['parent_user'],
      replies: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type == MessageType.system ? 'system' : 'chat',
      'user': username,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'aiUsed': isAiTriggered,
    };
  }
}
