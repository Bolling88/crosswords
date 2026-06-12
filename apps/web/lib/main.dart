import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

import 'crossword/web_crossword_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final fontService = FontService(prefs: prefs);
  final settingsService = GameplaySettingsService(prefs: prefs);
  final progressService = ProgressService(prefs: prefs);
  final puzzle = await loadBundledPuzzle();
  runApp(CrosswordsWebApp(
    fontService: fontService,
    settingsService: settingsService,
    progressService: progressService,
    puzzle: puzzle,
  ));
}

class CrosswordsWebApp extends StatelessWidget {
  final FontService fontService;
  final GameplaySettingsService settingsService;
  final ProgressService progressService;
  final CrosswordPuzzle puzzle;

  const CrosswordsWebApp({
    required this.fontService,
    required this.settingsService,
    required this.progressService,
    required this.puzzle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FontService>.value(value: fontService),
        RepositoryProvider<GameplaySettingsService>.value(
          value: settingsService,
        ),
        RepositoryProvider<ProgressService>.value(value: progressService),
      ],
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
        home: WebCrosswordScreen(puzzle: puzzle),
      ),
    );
  }
}
