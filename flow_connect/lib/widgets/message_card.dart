import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flow_connect/theme/app_theme.dart';
import 'package:flow_connect/models/chat_message.dart';

class MessageCard extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback onAiTrigger;
  final VoidCallback onReply;

  const MessageCard({
    super.key,
    required this.message,
    required this.onAiTrigger,
    required this.onReply,
  });

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  Color _getCardColor() {
    switch (widget.message.type) {
      case MessageType.question:
        return AppTheme.aiAvailableBlue.withOpacity(0.15);
      case MessageType.aiResponse:
        return AppTheme.aiUsedGreen.withOpacity(0.15);
      case MessageType.important:
        return AppTheme.importantYellow.withOpacity(0.15);
      case MessageType.normal:
      case MessageType.system:
        return AppTheme.surfaceColor;
    }
  }

  Color _getBorderColor() {
    switch (widget.message.type) {
      case MessageType.question:
        return AppTheme.aiAvailableBlue.withOpacity(0.5);
      case MessageType.aiResponse:
        return AppTheme.aiUsedGreen.withOpacity(0.5);
      case MessageType.important:
        return AppTheme.importantYellow.withOpacity(0.5);
      case MessageType.normal:
      case MessageType.system:
        return AppTheme.surfaceHighlight;
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceHighlight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOption(
              Icons.star_rounded, 
              "Mark as Important", 
              AppTheme.importantYellow,
              () {
                 setState(() {
                   widget.message.type = widget.message.type == MessageType.important ? MessageType.normal : MessageType.important;
                 });
                 Navigator.pop(context);
              }
            ),
            const SizedBox(height: 16),
            _buildOption(
              Icons.copy_rounded, 
              "Copy Message Content", 
              AppTheme.textPrimary,
              () {
                Navigator.pop(context);
              }
            ),
            const SizedBox(height: 16),
            _buildOption(
              Icons.report_gmailerrorred_rounded, 
              "Report Message", 
              Colors.redAccent,
              () => Navigator.pop(context)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canShowAiButton = !widget.message.isAiTriggered && 
                            widget.message.type != MessageType.aiResponse && 
                            widget.message.type != MessageType.system;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getCardColor(),
            _getCardColor().withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getBorderColor(), width: 1.5),
        boxShadow: [
          if (widget.message.type == MessageType.important)
            BoxShadow(
              color: AppTheme.importantYellow.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getBorderColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.message.username.toUpperCase(),
                  style: TextStyle(
                    color: _getBorderColor().withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                "${widget.message.timestamp.hour.toString().padLeft(2, '0')}:${widget.message.timestamp.minute.toString().padLeft(2, '0')}",
                style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.message.text,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (canShowAiButton)
                GestureDetector(
                  onTap: widget.onAiTrigger,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.aiAvailableBlue, Color(0xFF60A5FA)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.aiAvailableBlue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 8),
                        const Text(
                          "ASK AI", 
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 11, 
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          )
                        ),
                      ],
                    ),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.3))
                   .scaleXY(begin: 1.0, end: 1.05, duration: 1000.ms),
                ),
              const SizedBox(width: 8),
              if (widget.message.type != MessageType.system)
                GestureDetector(
                  onTap: widget.onReply,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHighlight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.reply_rounded, color: AppTheme.textSecondary, size: 18),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showOptions(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHighlight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
