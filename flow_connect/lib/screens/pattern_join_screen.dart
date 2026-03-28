import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flow_connect/theme/app_theme.dart';
import 'package:flow_connect/screens/main_app_screen.dart';

class PatternJoinScreen extends StatefulWidget {
  const PatternJoinScreen({super.key});

  @override
  State<PatternJoinScreen> createState() => _PatternJoinScreenState();
}

class _PatternJoinScreenState extends State<PatternJoinScreen> {
  final List<int> _selectedDots = [];
  Offset? _currentTouchPosition;
  late List<Offset> _dotPositions;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _dotPositions = List.filled(9, Offset.zero);
  }

  void _onPanStart(DragStartDetails details) {
    if (_isSuccess) return;
    _selectedDots.clear();
    _updatePattern(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isSuccess) return;
    setState(() {
      _currentTouchPosition = details.localPosition;
    });
    _updatePattern(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isSuccess) return;
    setState(() {
      _currentTouchPosition = null;
      if (_selectedDots.length >= 4) {
        _isSuccess = true;
        HapticFeedback.heavyImpact();
        
        final pattern = _selectedDots.join('-');
        final randomNum = DateTime.now().millisecondsSinceEpoch % 10000;
        final username = '@user_$randomNum';
        
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => MainAppScreen(
                pattern: pattern,
                username: username,
              ),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            )
          );
        });
      } else {
        _selectedDots.clear();
        HapticFeedback.lightImpact();
      }
    });
  }

  void _updatePattern(Offset touchPos) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    for (int i = 0; i < 9; i++) {
      if (!_selectedDots.contains(i)) {
        final dotPos = _dotPositions[i];
        if (dotPos != Offset.zero) {
          final distance = (dotPos - touchPos).distance;
          if (distance < 40) {
            setState(() {
              _selectedDots.add(i);
            });
            HapticFeedback.selectionClick();
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text(
              "Draw to Connect",
              style: TextStyle(
                color: _isSuccess ? AppTheme.aiUsedGreen : AppTheme.aiAvailableBlue,
                fontSize: 24,
                letterSpacing: 2,
                fontWeight: FontWeight.w300,
              ),
            ).animate(target: _isSuccess ? 1 : 0)
             .tint(color: AppTheme.aiUsedGreen, duration: 300.ms),
            const SizedBox(height: 60),
            Center(
              child: SizedBox(
                width: 320,
                height: 320,
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: PatternPainter(
                      selectedDots: _selectedDots,
                      dotPositions: _dotPositions,
                      currentTouchPosition: _currentTouchPosition,
                      isSuccess: _isSuccess,
                    ),
                    size: const Size(320, 320),
                  ),
                ),
              ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class PatternPainter extends CustomPainter {
  final List<int> selectedDots;
  final List<Offset> dotPositions;
  final Offset? currentTouchPosition;
  final bool isSuccess;

  PatternPainter({
    required this.selectedDots,
    required this.dotPositions,
    required this.currentTouchPosition,
    required this.isSuccess,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double padding = 40.0;
    final double innerWidth = size.width - padding * 2;
    final double innerHeight = size.height - padding * 2;
    final double spacingX = innerWidth / 2;
    final double spacingY = innerHeight / 2;

    for (int i = 0; i < 9; i++) {
      final int row = i ~/ 3;
      final int col = i % 3;
      final dx = padding + spacingX * col;
      final dy = padding + spacingY * row;
      dotPositions[i] = Offset(dx, dy);
    }

    final Color primaryColor = isSuccess ? AppTheme.aiUsedGreen : AppTheme.aiAvailableBlue;

    final dotPaint = Paint()
      ..color = AppTheme.normalGray.withOpacity(0.3)
      ..style = PaintingStyle.fill;
      
    final selectedDotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      
    final linePaint = Paint()
      ..color = primaryColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);

    if (selectedDots.isNotEmpty) {
      final path = Path();
      path.moveTo(dotPositions[selectedDots.first].dx, dotPositions[selectedDots.first].dy);
      
      for (int i = 1; i < selectedDots.length; i++) {
        path.lineTo(dotPositions[selectedDots[i]].dx, dotPositions[selectedDots[i]].dy);
      }
      
      if (currentTouchPosition != null) {
        path.lineTo(currentTouchPosition!.dx, currentTouchPosition!.dy);
      }
      
      canvas.drawPath(path, linePaint);
    }

    // Draw dots over lines
    for (int i = 0; i < 9; i++) {
      final bool isSelected = selectedDots.contains(i);
      canvas.drawCircle(
        dotPositions[i], 
        isSelected ? 8 : 6, 
        isSelected ? selectedDotPaint : dotPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) {
    return oldDelegate.selectedDots != selectedDots ||
           oldDelegate.currentTouchPosition != currentTouchPosition ||
           oldDelegate.isSuccess != isSuccess;
  }
}
