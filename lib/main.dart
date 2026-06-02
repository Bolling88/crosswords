import 'package:flutter/material.dart';

import 'common/data/constants/app_colors.dart';
import 'common/data/constants/strings.dart';
import 'gameplay/presentation/crossword_screen/crossword_screen.dart';

void main() {
  runApp(const CrosswordsApp());
}

class CrosswordsApp extends StatelessWidget {
  const CrosswordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: const CrosswordScreen(),
    );
  }
}
