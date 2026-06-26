import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:crossword_auth/crossword_auth.dart';

import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_ui/crossword_ui.dart';

import 'crossword/mobile_crossword_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final prefs = await SharedPreferences.getInstance();
  final fontService = FontService(prefs: prefs);
  final settingsService = GameplaySettingsService(prefs: prefs);
  final progressService = ProgressService(prefs: prefs);
  // The web OAuth client id; google_sign_in needs it as serverClientId on
  // Android so the minted ID token's audience is one Firebase accepts.
  final authService = FirebaseAuthService(
    googleServerClientId:
        '905506199750-up9vmj0qgh31fhm8eejf83vjsvuf5iee.apps.googleusercontent.com',
  );
  final generationService = PuzzleGenerationService(
    repository: CrosswordGenerationRepository(
      remoteDataSource: CrosswordGenerationRemoteDataSource(),
    ),
  );
  runApp(CrosswordsApp(
    fontService: fontService,
    settingsService: settingsService,
    progressService: progressService,
    authService: authService,
    generationService: generationService,
  ));
}

class CrosswordsApp extends StatelessWidget {
  final FontService fontService;
  final GameplaySettingsService settingsService;
  final ProgressService progressService;
  final AuthService authService;
  final PuzzleGenerationService generationService;

  const CrosswordsApp({
    required this.fontService,
    required this.settingsService,
    required this.progressService,
    required this.authService,
    required this.generationService,
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
        RepositoryProvider<AuthService>.value(value: authService),
        RepositoryProvider<PuzzleGenerationService>.value(
          value: generationService,
        ),
      ],
      child: MaterialApp(
        onGenerateTitle: (context) => CrosswordUiL10n.of(context).appTitle,
        localizationsDelegates: const [
          CrosswordUiL10n.delegate,
          CrosswordAuthL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('sv'), Locale('en')],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brand,
            surface: AppColors.background,
          ),
          scaffoldBackgroundColor: AppColors.background,
          useMaterial3: true,
        ),
        home: AuthGate(
          authService: authService,
          child: GenerateScreen(
            gameplayBuilder: (context, puzzle) =>
                MobileCrosswordScreen(puzzle: puzzle),
          ),
        ),
      ),
    );
  }
}
