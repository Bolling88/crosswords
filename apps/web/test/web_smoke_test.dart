import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:crosswords_web/crossword/web_crossword_screen.dart';

void main() {
  testWidgets('web screen renders the shared player', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fontService = FontService(prefs: prefs);
    final puzzle = await loadBundledPuzzle();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FontService>.value(value: fontService),
          RepositoryProvider<GameplaySettingsService>.value(
            value: GameplaySettingsService(prefs: prefs),
          ),
          RepositoryProvider<ProgressService>.value(
            value: ProgressService(prefs: prefs),
          ),
        ],
        child: MaterialApp(home: WebCrosswordScreen(puzzle: puzzle)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CrosswordPlayer), findsOneWidget);
    expect(find.byIcon(Icons.fit_screen), findsOneWidget);
  });
}
