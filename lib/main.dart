import 'package:flutter/material.dart';
import 'screens/model_picker_screen.dart';

void main() {
  runApp(const LocalLLMApp());
}

class LocalLLMApp extends StatelessWidget {
  const LocalLLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00E5FF),
          surface: const Color(0xFF0D1117),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
      home: const ModelPickerScreen(),
    );
  }
}
