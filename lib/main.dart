import 'package:flutter/material.dart';

import 'gameplay/presentation/crossword_screen/crossword_screen.dart';

void main() {
  runApp(const CrosswordsApp());
}

class CrosswordsApp extends StatelessWidget {
  const CrosswordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Korsord',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
      ),
      home: const CrosswordScreen(),
    );
  }
}
