import 'package:flutter/material.dart';
import 'package:flow_connect/theme/app_theme.dart';

class FloatingInputBar extends StatefulWidget {
  final Function(String) onSend;

  const FloatingInputBar({super.key, required this.onSend});

  @override
  State<FloatingInputBar> createState() => _FloatingInputBarState();
}

class _FloatingInputBarState extends State<FloatingInputBar> {
  final TextEditingController _controller = TextEditingController();

  void _handleSend() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onSend(_controller.text.trim());
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.surfaceHighlight, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: "Add a thought...",
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.aiAvailableBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: AppTheme.aiAvailableBlue, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
