import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

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

    await openMenuAndTap(tester, Strings.revealLetterAction);

    expect(cubit.state.userInputs[(0, 1)], 'A');
    expect(cubit.state.revealedCells, {(0, 1)});
  });

  testWidgets('check word marks wrong letters', (tester) async {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('X');
    await tester.pumpWidget(harness());

    await openMenuAndTap(tester, Strings.checkWordAction);

    expect(cubit.state.incorrectCells, {(0, 1)});
  });

  testWidgets('restart asks for confirmation before wiping', (tester) async {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A');
    await tester.pumpWidget(harness());

    await openMenuAndTap(tester, Strings.restartAction);
    // Confirmation dialog is showing; cancel keeps the progress.
    await tester.tap(find.text(Strings.cancelAction));
    await tester.pumpAndSettle();
    expect(cubit.state.userInputs, isNotEmpty);

    await openMenuAndTap(tester, Strings.restartAction);
    expect(find.text(Strings.restartConfirmBody), findsOneWidget);
    await tester.tap(find.text(Strings.restartAction).last);
    await tester.pumpAndSettle();
    expect(cubit.state.userInputs, isEmpty);
  });
}
