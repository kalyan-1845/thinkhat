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
  final Set<String> _pendingAiRequests = {};
  final ScrollController _scrollController = ScrollController();
  late StreamSubscription _chatSub;
  late StreamSubscription _aiSub;

  @override
  void initState() {
    super.initState();
    
    _chatSub = BackendService().chatMessages.listen((msg) {
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == msg.id)) {
             _messages.add(msg);
          }
        });
        _scrollToBottom();
      }
    });

    _aiSub = BackendService().aiResponses.listen((data) {
       final messageId = data['messageId'];
       final replyText = data['aiReply'];
       
       if (mounted) {
         setState(() {
           _pendingAiRequests.remove(messageId);
           final targetMsgIndex = _messages.indexWhere((m) => m.id == messageId);
           if (targetMsgIndex != -1) {
             final targetMsg = _messages[targetMsgIndex];
             targetMsg.type = MessageType.aiResponse;
             // Link the AI response as a reply with parent info
             targetMsg.replies.add(
               ChatMessage(
                 id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                 username: 'Flow AI',
                 text: replyText,
                 timestamp: DateTime.fromMillisecondsSinceEpoch(
                   (data['timestamp'] as num).toInt() * 1000
                 ),
                 type: MessageType.aiResponse,
                 parentMessageText: targetMsg.text,
                 parentMessageUser: targetMsg.username,
               )
             );
           }
         });
         _scrollToBottom();
       }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatSub.cancel();
    _aiSub.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    BackendService().sendChatMessage(text);
  }

  void _triggerAi(ChatMessage message) {
    setState(() {
      _pendingAiRequests.add(message.id);
      message.isAiTriggered = true;
      message.type = MessageType.question;
    });

    BackendService().askAi(message.id);
  }

  Widget _buildMessageTree(ChatMessage message, {bool isReply = false}) {
    final isPending = _pendingAiRequests.contains(message.id);
    final isMe = message.username == BackendService().currentUsername;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isMe)
            Container(
              width: isReply ? 20 : 10, 
              alignment: Alignment.center,
              child: Container(
                width: 1.5,
                color: (message.type == MessageType.system || isMe) ? Colors.transparent : AppTheme.surfaceHighlight.withOpacity(0.3),
              ),
            ),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.type == MessageType.system)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(
                      child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                         decoration: BoxDecoration(
                            color: AppTheme.surfaceColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                         ),
                         child: Text(
                           message.text,
                           style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                         ),
                      ),
                    ),
                  )
                else
                  MessageCard(
                    message: message,
                    isMe: isMe,
                    onAiTrigger: () => _triggerAi(message),
                    onReply: () {}, 
                  ).animate().fade(duration: 300.ms).slideX(begin: isMe ? 0.02 : -0.02),
                
                if (isPending)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 12),
                    child: Row(
                       children: [
                         const SizedBox(
                           width: 10, height: 10,
                           child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.aiAvailableBlue),
                         ),
                         const SizedBox(width: 8),
                         Text("AI is thinking...", style: TextStyle(color: AppTheme.aiAvailableBlue, fontSize: 11, fontStyle: FontStyle.italic))
                            .animate(onPlay: (controller) => controller.repeat(reverse: true))
                            .fade(begin: 0.5, end: 1.0, duration: 800.ms),
                       ],
                    ),
                  ),

                if (message.replies.isNotEmpty)
                  ...message.replies.map((reply) => _buildMessageTree(reply, isReply: true)),
              ],
            ),
          ),
          
          if (isMe)
            const SizedBox(width: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return _buildMessageTree(_messages[index]);
            },
          ),
        ),
        FloatingInputBar(onSend: _sendMessage)
              .animate()
              .fade(duration: 400.ms)
              .slideY(begin: 0.1, curve: Curves.easeOutCubic),
      ],
    );
  }
}
