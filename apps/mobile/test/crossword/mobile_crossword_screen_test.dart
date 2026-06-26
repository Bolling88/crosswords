import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_auth/crossword_auth.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:crosswords/crossword/mobile_crossword_screen.dart';

void main() {
  late FontService fontService;
  late GameplaySettingsService settingsService;
  late ProgressService progressService;
  late CrosswordPuzzle puzzle;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fontService = FontService(prefs: prefs);
    settingsService = GameplaySettingsService(prefs: prefs);
    progressService = ProgressService(prefs: prefs);
    puzzle = await loadBundledPuzzle();
  });

  Widget harness() => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FontService>.value(value: fontService),
          RepositoryProvider<GameplaySettingsService>.value(
            value: settingsService,
          ),
          RepositoryProvider<ProgressService>.value(value: progressService),
        ],
        child: MaterialApp(
          locale: const Locale('sv'),
          localizationsDelegates: const [
            CrosswordUiL10n.delegate,
            CrosswordAuthL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('sv'), Locale('en')],
          home: MobileCrosswordScreen(puzzle: puzzle),
        ),
      );

  testWidgets('renders the play surface with app-bar actions', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(CrosswordPlayer), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.fit_screen), findsOneWidget);
  });

  testWidgets('settings action opens the settings screen', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
