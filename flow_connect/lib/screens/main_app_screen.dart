import 'package:flutter/material.dart';
import 'package:flow_connect/theme/app_theme.dart';
import 'package:flow_connect/screens/flow_chat_screen.dart';
import 'package:flow_connect/screens/voice_space_screen.dart';
import 'package:flow_connect/services/backend_service.dart';

class MainAppScreen extends StatefulWidget {
  final String pattern;
  final String username;

  const MainAppScreen({
    super.key,
    required this.pattern,
    required this.username,
  });

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  bool _isConnected = false;
  int _activeUsersCount = 1;

  @override
  void initState() {
    super.initState();
    _connectToBackend();
  }

  Future<void> _connectToBackend() async {
    final success = await BackendService().connect(widget.pattern, widget.username);
    if (mounted) {
      setState(() => _isConnected = success);
    }
    
    BackendService().systemEvents.listen((event) {
       // Rough approximation - in a real app we'd fetch the actual array
       if (event['event'] == 'user-joined') {
         if (mounted) setState(() => _activeUsersCount++);
       } else if (event['event'] == 'user-left') {
         if (mounted && _activeUsersCount > 1) setState(() => _activeUsersCount--);
       }
    });
  }

  @override
  void dispose() {
    BackendService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          title: Text(
            _isConnected ? 'FlowConnect (Live)' : 'FlowConnect (Connecting...)',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppTheme.textPrimary,
            ),
          ),
          actions: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt, size: 16, color: AppTheme.aiAvailableBlue),
                    const SizedBox(width: 6),
                    Text(
                      '$_activeUsersCount',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: AppTheme.textSecondary),
              onPressed: () {},
            ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            indicatorColor: AppTheme.aiAvailableBlue,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppTheme.textPrimary,
            unselectedLabelColor: AppTheme.normalGray,
            dividerColor: AppTheme.surfaceHighlight,
            tabs: [
              Tab(text: "Flow Chat"),
              Tab(text: "Voice Space"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FlowChatScreen(),
            VoiceSpaceScreen(),
          ],
        ),
      ),
    );
  }
}
