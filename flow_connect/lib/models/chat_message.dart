enum MessageType { normal, question, aiResponse, important, system }

class ChatMessage {
  final String id;
  final String username; // maps to 'user' in json
  final String text;
  final DateTime timestamp;
  MessageType type;
  bool isAiTriggered; // maps to 'aiUsed' in json
  List<ChatMessage> replies;

  ChatMessage({
    required this.id,
    required this.username,
    required this.text,
    required this.timestamp,
    this.type = MessageType.normal,
    this.isAiTriggered = false,
    List<ChatMessage>? replies,
  }) : replies = replies ?? [];

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    MessageType parsedType = MessageType.normal;
    bool isAi = json['aiUsed'] ?? false;
    
    if (json['type'] == 'system') {
      parsedType = MessageType.system;
    } else if (isAi) {
      parsedType = MessageType.question; // Assume it was asked
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
