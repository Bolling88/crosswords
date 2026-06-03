import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'common/data/constants/app_colors.dart';
import 'common/data/constants/strings.dart';
import 'gameplay/presentation/crossword_screen/crossword_screen.dart';
import 'settings/domain/services/font_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final fontService = FontService(prefs: prefs);
  runApp(CrosswordsApp(fontService: fontService));
}

class CrosswordsApp extends StatelessWidget {
  final FontService fontService;

  const CrosswordsApp({required this.fontService, super.key});

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
        home: const CrosswordScreen(),
      ),
    );
  }
}
