import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

final CrosswordUiL10n _l10n = lookupCrosswordUiL10n(const Locale('sv'));

CrosswordPuzzle _puzzle() {
  const w = Word(
    id: 'w',
    direction: Direction.right,
    cells: [(0, 1), (0, 2)],
  );
  return const CrosswordPuzzle(
    rows: 1,
    cols: 3,
    cells: {
      (0, 0): ClueCell(arrows: [
        ClueArrow(
          direction: Direction.right,
          shape: ArrowShape.straightRight,
          wordId: 'w',
        ),
      ]),
      (0, 1): AnswerCell(value: 'A'),
      (0, 2): AnswerCell(value: 'B'),
    },
    words: [w],
    title: 't',
    languageCode: 'sv',
  );
}

void main() {
  late CrosswordCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cubit = CrosswordCubit(
      puzzle: _puzzle(),
      fontService: FontService(prefs: prefs),
      settingsService: GameplaySettingsService(prefs: prefs),
      progressService: ProgressService(prefs: prefs),
    );
  });

  tearDown(() => cubit.close());

  Widget harness() => MaterialApp(
        locale: const Locale('sv'),
        localizationsDelegates: const [
          CrosswordUiL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('sv'), Locale('en')],
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: CrosswordPlayer()),
        ),
      );

  testWidgets('solving the puzzle shows the celebration dialog',
      (tester) async {
    await tester.pumpWidget(harness());
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A');
    cubit.onLetterInput('B');
    await tester.pumpAndSettle();

    expect(find.text(_l10n.solvedTitle), findsOneWidget);
    expect(find.text(_l10n.solvedBody), findsOneWidget);
  });

  testWidgets('a full but wrong grid shows the nudge snackbar',
      (tester) async {
    await tester.pumpWidget(harness());
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A');
    cubit.onLetterInput('X');
    await tester.pump();

    expect(find.text(_l10n.puzzleFilledButIncorrect), findsOneWidget);
    expect(find.text(_l10n.solvedTitle), findsNothing);
  });
}
