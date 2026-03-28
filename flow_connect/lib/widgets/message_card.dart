import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flow_connect/theme/app_theme.dart';
import 'package:flow_connect/models/chat_message.dart';

class MessageCard extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onAiTrigger;
  final VoidCallback onReply;

  const MessageCard({
    super.key,
    required this.message,
    required this.onAiTrigger,
    required this.onReply,
  });

  Color _getCardColor() {
    switch (message.type) {
      case MessageType.question:
        return AppTheme.aiAvailableBlue.withOpacity(0.15);
      case MessageType.aiResponse:
        return AppTheme.aiUsedGreen.withOpacity(0.15);
      case MessageType.important:
        return AppTheme.importantYellow.withOpacity(0.15);
      case MessageType.normal:
        return AppTheme.surfaceColor;
    }
  }

  Color _getBorderColor() {
    switch (message.type) {
      case MessageType.question:
        return AppTheme.aiAvailableBlue.withOpacity(0.5);
      case MessageType.aiResponse:
        return AppTheme.aiUsedGreen.withOpacity(0.5);
      case MessageType.important:
        return AppTheme.importantYellow.withOpacity(0.5);
      case MessageType.normal:
        return AppTheme.surfaceHighlight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor(), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
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
              Text(
                message.username,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.text,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!message.isAiTriggered && message.type != MessageType.aiResponse)
                GestureDetector(
                  onTap: onAiTrigger,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.aiAvailableBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: AppTheme.aiAvailableBlue, size: 18),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .shimmer(duration: 2000.ms, color: AppTheme.aiAvailableBlue.withOpacity(0.5)),
                ),
              const SizedBox(width: 8),
              if (message.type != MessageType.aiResponse)
                GestureDetector(
                  onTap: onReply,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHighlight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.reply_rounded, color: AppTheme.textSecondary, size: 18),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(6),
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
