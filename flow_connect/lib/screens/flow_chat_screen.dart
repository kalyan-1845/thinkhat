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
             targetMsg.replies.add(
               ChatMessage(
                 id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                 username: 'Flow AI',
                 text: replyText,
                 timestamp: DateTime.fromMillisecondsSinceEpoch(
                   (data['timestamp'] as num).toInt() * 1000
                 ),
                 type: MessageType.aiResponse,
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline connector
          Container(
            width: isReply ? 40 : 20, 
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
                      blurRadius: 10,
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
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(
                      child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                         decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.surfaceHighlight),
                         ),
                         child: Text(
                           "${message.username} joined the chat",
                           style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                         ),
                      ),
                    ),
                  )
                else
                  MessageCard(
                    message: message,
                    onAiTrigger: () => _triggerAi(message),
                    onReply: () {}, 
                  ).animate().fade(duration: 400.ms).slideX(begin: 0.05),
                
                if (isPending)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, bottom: 16),
                    child: Row(
                       children: [
                         const SizedBox(
                           width: 12, height: 12,
                           child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.aiAvailableBlue),
                         ),
                         const SizedBox(width: 12),
                         Text("AI is thinking...", style: TextStyle(color: AppTheme.aiAvailableBlue, fontSize: 12, fontStyle: FontStyle.italic))
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
            padding: const EdgeInsets.only(left: 8, right: 16, top: 24, bottom: 20),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return _buildMessageTree(_messages[index]);
            },
          ),
        ),
        FloatingInputBar(onSend: _sendMessage)
              .animate()
              .fade(duration: 600.ms)
              .slideY(begin: 0.2, curve: Curves.easeOutCubic),
      ],
    );
  }
}
