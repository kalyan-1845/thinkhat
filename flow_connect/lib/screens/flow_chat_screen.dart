import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flow_connect/theme/app_theme.dart';
import 'package:flow_connect/models/chat_message.dart';
import 'package:flow_connect/widgets/message_card.dart';
import 'package:flow_connect/widgets/floating_input_bar.dart';
import 'package:flow_connect/services/backend_service.dart';

class FlowChatScreen extends StatefulWidget {
  const FlowChatScreen({super.key});

  @override
  State<FlowChatScreen> createState() => _FlowChatScreenState();
}

class _FlowChatScreenState extends State<FlowChatScreen> {
  final List<ChatMessage> _messages = [];
  late StreamSubscription _chatSub;
  late StreamSubscription _aiSub;

  @override
  void initState() {
    super.initState();
    
    _chatSub = BackendService().chatMessages.listen((msg) {
      if (mounted) {
        setState(() {
          // Prevent duplicates visually
          if (!_messages.any((m) => m.id == msg.id)) {
             _messages.add(msg);
          }
        });
      }
    });

    _aiSub = BackendService().aiResponses.listen((data) {
       final messageId = data['messageId'];
       final replyText = data['aiReply'];
       
       if (mounted) {
         setState(() {
           final targetMsgIndex = _messages.indexWhere((m) => m.id == messageId);
           if (targetMsgIndex != -1) {
             final targetMsg = _messages[targetMsgIndex];
             targetMsg.type = MessageType.aiResponse;
             targetMsg.replies.add(
               ChatMessage(
                 id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                 username: 'Flow AI',
                 text: replyText,
                 timestamp: DateTime.fromMicrosecondsSinceEpoch(
                   data['timestamp'] is int 
                     ? data['timestamp'] * 1000000 
                     : int.parse(data['timestamp'].toString()) * 1000000
                 ),
                 type: MessageType.aiResponse,
               )
             );
           }
         });
       }
    });
  }

  @override
  void dispose() {
    _chatSub.cancel();
    _aiSub.cancel();
    super.dispose();
  }

  void _sendMessage(String text) {
    BackendService().sendChatMessage(text);
  }

  void _triggerAi(ChatMessage message) {
    setState(() {
      message.isAiTriggered = true;
      message.type = MessageType.question;
    });

    // Send original message with aiUsed flag set to true
    BackendService().sendChatMessage(message.text, aiUsed: true, id: message.id);
  }

  Widget _buildMessageTree(ChatMessage message, {bool isReply = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline connector
          Container(
            width: isReply ? 40 : 20, // Indent replies
            alignment: isReply ? Alignment.centerRight : Alignment.center,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: message.type == MessageType.aiResponse 
                    ? AppTheme.aiUsedGreen.withOpacity(0.5) 
                    : message.type == MessageType.question 
                        ? AppTheme.aiAvailableBlue.withOpacity(0.5)
                        : (message.type == MessageType.system ? Colors.transparent : AppTheme.surfaceHighlight),
                boxShadow: [
                  if (message.type == MessageType.aiResponse)
                    const BoxShadow(
                      color: AppTheme.aiUsedGreen,
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.type == MessageType.system)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(
                      child: Text(
                        "${message.username} joined the chat",
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  )
                else
                  MessageCard(
                    message: message,
                    onAiTrigger: () => _triggerAi(message),
                    onReply: () {}, 
                  ).animate().fade(duration: 400.ms).slideX(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic),
                if (message.replies.isNotEmpty)
                  ...message.replies.map((reply) => _buildMessageTree(reply, isReply: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(left: 8, right: 16, top: 24, bottom: 100),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            return _buildMessageTree(_messages[index]);
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FloatingInputBar(onSend: _sendMessage)
              .animate()
              .fade(duration: 600.ms, delay: 200.ms)
              .slideY(begin: 0.5, curve: Curves.easeOutCubic),
        ),
      ],
    );
  }
}
