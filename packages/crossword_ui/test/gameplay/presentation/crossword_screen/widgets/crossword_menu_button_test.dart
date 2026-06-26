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
          child: Scaffold(
            appBar: AppBar(actions: const [CrosswordMenuButton()]),
          ),
        ),
      );

  Future<void> openMenuAndTap(WidgetTester tester, String action) async {
    await tester.tap(find.byType(CrosswordMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('reveal letter fills the selected cell', (tester) async {
    cubit.selectCell(0, 1);
    await tester.pumpWidget(harness());

    await openMenuAndTap(tester, _l10n.revealLetterAction);

    expect(cubit.state.userInputs[(0, 1)], 'A');
    expect(cubit.state.revealedCells, {(0, 1)});
  });

  testWidgets('check word marks wrong letters', (tester) async {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('X');
    await tester.pumpWidget(harness());

    await openMenuAndTap(tester, _l10n.checkWordAction);

    expect(cubit.state.incorrectCells, {(0, 1)});
  });

  testWidgets('reveal solution confirms, then fills the whole grid',
      (tester) async {
    await tester.pumpWidget(harness());

    await openMenuAndTap(tester, _l10n.revealSolutionAction);
    // Confirmation dialog is showing; cancel leaves the grid empty.
    await tester.tap(find.text(_l10n.cancelAction));
    await tester.pumpAndSettle();
    expect(cubit.state.userInputs, isEmpty);

    await openMenuAndTap(tester, _l10n.revealSolutionAction);
    expect(find.text(_l10n.revealSolutionConfirmBody), findsOneWidget);
    await tester.tap(find.text(_l10n.revealSolutionAction).last);
    await tester.pumpAndSettle();

    expect(cubit.state.userInputs, {(0, 1): 'A', (0, 2): 'B'});
    expect(cubit.state.revealedCells, {(0, 1), (0, 2)});
    expect(cubit.state.isSolved, isTrue);
  });

  testWidgets('restart asks for confirmation before wiping', (tester) async {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A');
    await tester.pumpWidget(harness());

    await openMenuAndTap(tester, _l10n.restartAction);
    // Confirmation dialog is showing; cancel keeps the progress.
    await tester.tap(find.text(_l10n.cancelAction));
    await tester.pumpAndSettle();
    expect(cubit.state.userInputs, isNotEmpty);

    await openMenuAndTap(tester, _l10n.restartAction);
    expect(find.text(_l10n.restartConfirmBody), findsOneWidget);
    await tester.tap(find.text(_l10n.restartAction).last);
    await tester.pumpAndSettle();
    expect(cubit.state.userInputs, isEmpty);
  });
}
