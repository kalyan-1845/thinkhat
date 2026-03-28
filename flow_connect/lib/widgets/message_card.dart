import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flow_connect/theme/app_theme.dart';
import 'package:flow_connect/models/chat_message.dart';

class MessageCard extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback onAiTrigger;
  final VoidCallback onReply;
  final bool isMe;

  const MessageCard({
    super.key,
    required this.message,
    required this.onAiTrigger,
    required this.onReply,
    this.isMe = false,
  });

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  Color _getBubbleColor() {
    if (widget.isMe) return const Color(0xFF104A41); // Dark WhatsApp Green
    switch (widget.message.type) {
       case MessageType.aiResponse: return const Color(0xFF232D36);
       case MessageType.important: return const Color(0xFF3B3110);
       default: return const Color(0xFF1F2C34); // Standard Dark WhatsApp Bubble
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceHighlight,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOption(Icons.star_rounded, "Important", AppTheme.importantYellow, () {
               setState(() => widget.message.type = widget.message.type == MessageType.important ? MessageType.normal : MessageType.important);
               Navigator.pop(context);
            }),
            _buildOption(Icons.copy_rounded, "Copy", AppTheme.textPrimary, () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canShowAiButton = !widget.message.isAiTriggered && 
                            widget.message.type != MessageType.aiResponse && 
                            widget.message.type != MessageType.system;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(
                left: widget.isMe ? 50 : 0, 
                right: widget.isMe ? 0 : 50,
                bottom: 4,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _getBubbleColor(),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
                  bottomRight: Radius.circular(widget.isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   if (!widget.isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        widget.message.username,
                        style: TextStyle(
                          color: widget.message.type == MessageType.aiResponse ? AppTheme.aiUsedGreen : AppTheme.aiAvailableBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  
                  if (widget.message.parentMessageText != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: AppTheme.aiAvailableBlue, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.message.parentMessageUser ?? "Reply",
                            style: const TextStyle(color: AppTheme.aiAvailableBlue, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.message.parentMessageText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                  Text(
                    widget.message.text,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Spacer(),
                      Text(
                        "${widget.message.timestamp.hour}:${widget.message.timestamp.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canShowAiButton)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 2),
                child: InkWell(
                  onTap: widget.onAiTrigger,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.aiAvailableBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.aiAvailableBlue.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: AppTheme.aiAvailableBlue, size: 12),
                        SizedBox(width: 4),
                        Text("ASK AI", style: TextStyle(color: AppTheme.aiAvailableBlue, fontSize: 10, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
