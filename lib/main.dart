import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MoodWidgetApp());
}

class MoodWidgetApp extends StatelessWidget {
  const MoodWidgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood Widget',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        colorSchemeSeed: const Color(0xFF00B050),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E0E0E),
        colorSchemeSeed: const Color(0xFF00E676),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
