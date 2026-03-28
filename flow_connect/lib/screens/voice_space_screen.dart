import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flow_connect/theme/app_theme.dart';
import 'package:flow_connect/services/backend_service.dart';

class VoiceSpaceScreen extends StatefulWidget {
  const VoiceSpaceScreen({super.key});

  @override
  State<VoiceSpaceScreen> createState() => _VoiceSpaceScreenState();
}

class _VoiceSpaceScreenState extends State<VoiceSpaceScreen> {
  bool _isSpeaking = false;
  
  // Map of username -> isSpeaking
  final Map<String, bool> _users = {};
  
  late StreamSubscription _systemSub;
  late StreamSubscription _signalSub;

  @override
  void initState() {
    super.initState();
    _fetchInitialUsers();
    
    _systemSub = BackendService().systemEvents.listen((event) {
      if (!mounted) return;
      final username = event['user'];
      if (event['event'] == 'user-joined') {
        setState(() => _users[username] = false);
      } else if (event['event'] == 'user-left') {
        setState(() => _users.remove(username));
      }
    });

    _signalSub = BackendService().signaling.listen((event) {
      if (!mounted) return;
      if (event['event'] == 'user-speaking') {
         final username = event['user'];
         final isSpeaking = event['data']['isSpeaking'] == true;
         if (_users.containsKey(username)) {
            setState(() => _users[username] = isSpeaking);
         }
      }
    });
  }

  Future<void> _fetchInitialUsers() async {
    final groupId = BackendService().currentGroupId;
    if (groupId == null) return;
    
    try {
      final res = await http.get(Uri.parse('${BackendService.baseUrl}/group/$groupId/users'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> fetchedUsers = data['users'];
        if (mounted) {
          setState(() {
            for (var u in fetchedUsers) {
              _users[u.toString()] = false;
            }
            // Ensure self is in list
            if (BackendService().currentUsername != null) {
              _users[BackendService().currentUsername!] = _isSpeaking;
            }
          });
        }
      }
    } catch (e) {
      print('Failed to fetch initial users: $e');
    }
  }

  @override
  void dispose() {
    _systemSub.cancel();
    _signalSub.cancel();
    super.dispose();
  }

  void _toggleSelfSpeaking(bool speaking) {
    if (_isSpeaking == speaking) return;
    setState(() {
      _isSpeaking = speaking;
      if (BackendService().currentUsername != null) {
        _users[BackendService().currentUsername!] = speaking;
      }
    });
    BackendService().sendVoiceSignal(speaking);
  }

  @override
  Widget build(BuildContext context) {
    final userList = _users.entries.toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            itemCount: userList.length,
            itemBuilder: (context, index) {
              final user = userList[index];
              final username = user.key;
              final isActive = user.value;
              final isMe = username == BackendService().currentUsername;
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.surfaceHighlight : AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? AppTheme.aiUsedGreen : AppTheme.surfaceHighlight,
                    width: isActive ? 1.5 : 1,
                  ),
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: AppTheme.aiUsedGreen.withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ] : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.aiUsedGreen.withOpacity(0.2) : AppTheme.normalGray.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: isActive ? AppTheme.aiUsedGreen : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      isMe ? '$username (You)' : username,
                      style: TextStyle(
                        color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (isActive)
                      const Icon(Icons.graphic_eq, color: AppTheme.aiUsedGreen, size: 20)
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(color: AppTheme.aiAvailableBlue, duration: 1000.ms),
                  ],
                ),
              ).animate().fade(duration: 400.ms, delay: (index * 100).ms).slideY(begin: 0.1);
            },
          ),
        ),
        
        Container(
          padding: const EdgeInsets.only(bottom: 40, top: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppTheme.background,
                AppTheme.background.withOpacity(0.0),
              ],
            ),
          ),
          child: Column(
            children: [
              const Text(
                "Live Signaling Mode (MVP)",
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                     padding: const EdgeInsets.all(12),
                     decoration: const BoxDecoration(
                       color: AppTheme.surfaceColor,
                       shape: BoxShape.circle,
                     ),
                     child: const Icon(Icons.volume_off_rounded, color: AppTheme.normalGray),
                  ),
                  const SizedBox(width: 32),
                  GestureDetector(
                    onTapDown: (_) => _toggleSelfSpeaking(true),
                    onTapUp: (_) => _toggleSelfSpeaking(false),
                    onTapCancel: () => _toggleSelfSpeaking(false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isSpeaking ? 90 : 80,
                      height: _isSpeaking ? 90 : 80,
                      decoration: BoxDecoration(
                        color: _isSpeaking ? AppTheme.aiUsedGreen : AppTheme.surfaceHighlight,
                        shape: BoxShape.circle,
                        boxShadow: _isSpeaking ? [
                          BoxShadow(
                            color: AppTheme.aiUsedGreen.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ] : [],
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        color: _isSpeaking ? AppTheme.background : AppTheme.textPrimary,
                        size: _isSpeaking ? 40 : 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.importantYellow.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.exit_to_app_rounded, color: AppTheme.importantYellow),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

