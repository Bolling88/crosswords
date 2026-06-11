import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

import 'crossword/mobile_crossword_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final fontService = FontService(prefs: prefs);
  final puzzle = await loadBundledPuzzle();
  runApp(CrosswordsApp(fontService: fontService, puzzle: puzzle));
}

class CrosswordsApp extends StatelessWidget {
  final FontService fontService;
  final CrosswordPuzzle puzzle;

  const CrosswordsApp({
    required this.fontService,
    required this.puzzle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<FontService>.value(
      value: fontService,
      child: MaterialApp(
        title: Strings.appTitle,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brand,
            surface: AppColors.background,
          ),
          scaffoldBackgroundColor: AppColors.background,
          useMaterial3: true,
        ),
        home: MobileCrosswordScreen(puzzle: puzzle),
      ),
    );
  }
}
