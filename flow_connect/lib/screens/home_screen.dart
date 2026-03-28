import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flow_connect/theme/app_theme.dart';
import 'package:flow_connect/screens/pattern_join_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.hub_rounded,
                size: 80,
                color: AppTheme.aiAvailableBlue,
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .shimmer(duration: 2000.ms, color: AppTheme.aiUsedGreen)
                  .scaleXY(begin: 0.95, end: 1.05, duration: 2000.ms, curve: Curves.easeInOut),
              const SizedBox(height: 32),
              const Text(
                "FlowConnect",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ).animate().fade().slideY(begin: 0.2),
              const SizedBox(height: 16),
              const Text(
                "Secure, patterned-based rooms.\nReady to flow?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
              ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
              const Spacer(),
              _buildBigButton(
                context,
                title: 'Create a Room',
                subtitle: 'Draw a new pattern to open a space',
                icon: Icons.add_circle_outline_rounded,
                color: AppTheme.aiAvailableBlue,
                isCreating: true,
                delay: 400.ms,
              ),
              const SizedBox(height: 16),
              _buildBigButton(
                context,
                title: 'Join a Room',
                subtitle: 'Enter an existing pattern',
                icon: Icons.login_rounded,
                color: AppTheme.aiUsedGreen,
                isCreating: false,
                delay: 600.ms,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigButton(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required bool isCreating,
        required Duration delay,
      }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => PatternJoinScreen(isCreating: isCreating),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          )
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary, size: 16),
          ],
        ),
      ).animate().fade(delay: delay, duration: 400.ms).slideY(begin: 0.2),
    );
  }
}
