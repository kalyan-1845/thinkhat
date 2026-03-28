import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flow_connect/theme/app_theme.dart';
import 'package:flow_connect/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const FlowConnectApp());
}

class FlowConnectApp extends StatelessWidget {
  const FlowConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
