import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:crosswords/crossword/mobile_crossword_screen.dart';
import 'package:crosswords/settings/presentation/settings_screen/settings_screen.dart';

void main() {
  late FontService fontService;
  late CrosswordPuzzle puzzle;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fontService = FontService(prefs: prefs);
    puzzle = await loadBundledPuzzle();
  });

  Widget harness() => RepositoryProvider<FontService>.value(
        value: fontService,
        child: MaterialApp(home: MobileCrosswordScreen(puzzle: puzzle)),
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
