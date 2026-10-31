import 'package:flutter/material.dart';

import 'features/auth/auth_gate.dart';

class SnowSpeaksApp extends StatelessWidget {
  const SnowSpeaksApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'glb模型能力',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansSC',
      scaffoldBackgroundColor: const Color(0xFF555555),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4263EB),
        primary: const Color(0xFF4263EB),
        surface: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFF283344)),
      ),
    ),
    home: const AuthGate(),
  );
}
