import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flow_connect/theme/app_theme.dart';
import 'package:flow_connect/screens/flow_chat_screen.dart';
import 'package:flow_connect/screens/voice_space_screen.dart';
import 'package:flow_connect/screens/mind_map_screen.dart';
import 'package:flow_connect/services/backend_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

class MainAppScreen extends StatefulWidget {
  final String pattern;
  final String username;
  final bool isCreating;

  const MainAppScreen({
    super.key,
    required this.pattern,
    required this.username,
    required this.isCreating,
  });

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  bool _isConnected = false;
  int _activeUsersCount = 1;

  final TextEditingController _groqController = TextEditingController();
  final TextEditingController _openaiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKeys();
    _connectToBackend();
  }

  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _groqController.text = prefs.getString('groq_key') ?? '';
      _openaiController.text = prefs.getString('openai_key') ?? '';
    });
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_key', _groqController.text);
    await prefs.setString('openai_key', _openaiController.text);

    // Update backend config
    try {
       await http.post(
         Uri.parse('${BackendService.baseUrl}/config?groq_key=${_groqController.text}&openai_key=${_openaiController.text}')
       );
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("API Keys Updated!")));
       }
    } catch (e) {
       print('Failed to sync keys: $e');
    }
  }

  Future<void> _connectToBackend() async {
    final success = await BackendService().connect(widget.pattern, widget.username, isCreating: widget.isCreating);
    if (mounted) {
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
               content: Text(widget.isCreating ? 'Failed to create room. Try again.' : 'Room not found. Pattern incorrect or room expired.'),
               backgroundColor: AppTheme.importantYellow,
               behavior: SnackBarBehavior.floating,
               margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
           )
        );
        Navigator.of(context).pop();
        return;
      }
      setState(() => _isConnected = success);
    }
    
    // Fetch Initial count
    try {
       final res = await http.get(Uri.parse('${BackendService.baseUrl}/group/${BackendService().currentGroupId}/users'));
       if (res.statusCode == 200) {
         final usersData = jsonDecode(res.body);
         if (mounted) setState(() => _activeUsersCount = (usersData['users'] as List).length);
       }
    } catch (e) {
       print('Failed to fetch initial count: $e');
    }

    BackendService().systemEvents.listen((event) {
       if (event['event'] == 'user-joined') {
         if (event['user'] != BackendService().currentUsername) {
            if (mounted) setState(() => _activeUsersCount++);
         }
       } else if (event['event'] == 'user-left') {
         if (mounted && _activeUsersCount > 1) setState(() => _activeUsersCount--);
       } else if (event['event'] == 'room-destroyed') {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("The creator has closed the room and wiped the data."))
           );
           Navigator.of(context).pop();
         }
       }
    });

    // Auto-sync keys upon connect if they exist
    if (_groqController.text.isNotEmpty || _openaiController.text.isNotEmpty) {
       _saveConfig();
    }
  }

  void _showSettings() {
    final isCreator = BackendService().isCreator;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 32, left: 24, right: 24
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Configuration & Keys", 
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildInputField("Groq API Key", _groqController),
            const SizedBox(height: 16),
            _buildInputField("OpenAI API Key (Optional)", _openaiController),
            const SizedBox(height: 24),
            const Text("ROOM INFO:", style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12)),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text("24H Auto-Clear: ACTIVE", style: const TextStyle(color: AppTheme.importantYellow, fontSize: 13, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 4),
                   Text("Group Hash: ${BackendService().currentGroupId}", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                 ],
               ),
            ),
            const SizedBox(height: 24),
            if (isCreator)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    BackendService().destroyRoom();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("DESTROY & WIPE ROOM (CREATOR ONLY)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                   _saveConfig();
                   Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.aiAvailableBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("SAVE CONFIG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _groqController.dispose();
    _openaiController.dispose();
    BackendService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
              icon: const Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary),
              onPressed: _showSettings,
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
              Tab(text: "Idea Map"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FlowChatScreen(),
            VoiceSpaceScreen(),
            MindMapScreen(),
          ],
        ),
      ),
    );
  }
}
