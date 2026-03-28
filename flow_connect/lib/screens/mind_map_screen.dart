import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flow_connect/models/chat_message.dart';
import 'package:flow_connect/services/backend_service.dart';
import 'package:flow_connect/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  final Map<String, ChatMessage> _nodes = {};
  final Map<String, Offset> _positions = {};
  late StreamSubscription _chatSub;
  late StreamSubscription _nodeSub;
  late StreamSubscription _aiSub;

  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    
    // Load initial positions from service
    BackendService().initialNodePositions.forEach((id, pos) {
      _positions[id] = Offset(pos['x']!, pos['y']!);
    });

    _chatSub = BackendService().chatMessages.listen((msg) {
      if (mounted) {
        setState(() {
          _nodes[msg.id] = msg;
          // Assign random initial position if not set
          if (!_positions.containsKey(msg.id)) {
             _positions[msg.id] = Offset(200.0 + (msg.id.hashCode % 300), 200.0 + (msg.id.hashCode % 500));
          }
        });
      }
    });

    _nodeSub = BackendService().nodeUpdates.listen((data) {
      if (mounted) {
        setState(() {
          _positions[data['messageId']] = Offset(data['x'].toDouble(), data['y'].toDouble());
        });
      }
    });

    _aiSub = BackendService().aiResponses.listen((data) {
       final messageId = data['messageId'];
       if (mounted && _nodes.containsKey(messageId)) {
          setState(() {
            _nodes[messageId]!.type = MessageType.aiResponse;
            // The actual AI text is in the reply which adds as a new message usually
          });
       }
    });
  }

  @override
  void dispose() {
    _chatSub.cancel();
    _nodeSub.cancel();
    _aiSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: InteractiveViewer(
        transformationController: _transformationController,
        boundaryMargin: const EdgeInsets.all(2000),
        minScale: 0.1,
        maxScale: 2.0,
        child: Stack(
          children: [
            // Background grid or connections could go here
            CustomPaint(
              size: const Size(5000, 5000),
              painter: ConnectionPainter(nodes: _nodes.values.toList(), positions: _positions),
            ),
            ..._nodes.values.map((node) {
              final pos = _positions[node.id] ?? Offset.zero;
              return Positioned(
                left: pos.dx,
                top: pos.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _positions[node.id] = Offset(pos.dx + details.delta.dx, pos.dy + details.delta.dy);
                    });
                    BackendService().updateNodePosition(node.id, _positions[node.id]!.dx, _positions[node.id]!.dy);
                  },
                  child: _buildNodeCard(node),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeCard(ChatMessage node) {
    final bool isAi = node.type == MessageType.aiResponse;
    final bool isQuestion = node.type == MessageType.question;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAi ? AppTheme.aiUsedGreen : (isQuestion ? AppTheme.aiAvailableBlue : AppTheme.surfaceHighlight),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAi ? AppTheme.aiUsedGreen : (isQuestion ? AppTheme.aiAvailableBlue : Colors.black)).withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: AppTheme.surfaceHighlight,
                child: Text(node.username[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: AppTheme.textPrimary)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.username,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            node.text,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);
  }
}

class ConnectionPainter extends CustomPainter {
  final List<ChatMessage> nodes;
  final Map<String, Offset> positions;

  ConnectionPainter({required this.nodes, required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.surfaceHighlight.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Direct connections for nested replies
    for (var node in nodes) {
      final startPos = positions[node.id];
      if (startPos == null) continue;

      for (var reply in node.replies) {
        final endPos = positions[reply.id];
        if (endPos == null) continue;

        // Draw a smooth curve
        final path = Path();
        path.moveTo(startPos.dx + 90, startPos.dy + 40); // Centerish of card
        path.cubicTo(
          startPos.dx + 90, startPos.dy + 100, 
          endPos.dx + 90, endPos.dy - 60,
          endPos.dx + 90, endPos.dy
        );
        
        final linePaint = Paint()
          ..color = (reply.type == MessageType.aiResponse ? AppTheme.aiUsedGreen : AppTheme.aiAvailableBlue).withOpacity(0.4)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        canvas.drawPath(path, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter oldDelegate) => true;
}
