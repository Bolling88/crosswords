import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart';

/// 1x3 grid: clue, a seed cell with given letter 'Å', and one normal cell
/// whose solution is 'B'.
CrosswordPuzzle _puzzle() {
  const w = Word(id: 'w', direction: Direction.right, cells: [(0, 1), (0, 2)]);
  return const CrosswordPuzzle(
    rows: 1,
    cols: 3,
    cells: {
      (0, 0): ClueCell(
        arrows: [
          ClueArrow(
            direction: Direction.right,
            shape: ArrowShape.straightRight,
            wordId: 'w',
          ),
        ],
      ),
      (0, 1): AnswerCell(value: 'Å', isSeed: true),
      (0, 2): AnswerCell(value: 'B'),
    },
    words: [w],
    seedPositions: {(0, 1)},
    title: 't',
    languageCode: 'sv',
  );
}

void main() {
  late CrosswordCubit cubit;
  late GameplaySettingsService settingsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    settingsService = GameplaySettingsService(prefs: prefs);
    cubit = CrosswordCubit(
      puzzle: _puzzle(),
      fontService: FontService(prefs: prefs),
      settingsService: settingsService,
      progressService: ProgressService(prefs: prefs),
    );
  });

  tearDown(() => cubit.close());

  Widget harness() => MaterialApp(
    home: BlocProvider.value(
      value: cubit,
      child: Scaffold(
        body: BlocBuilder<CrosswordCubit, CrosswordState>(
          builder: (context, state) =>
              CrosswordGrid(state: state, cellSize: 48),
        ),
      ),
    ),
  );

  Color? letterColor(WidgetTester tester, String letter) =>
      tester.widget<Text>(find.text(letter)).style?.color;

  testWidgets('seed cells render their given letter', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Å'), findsOneWidget);
  });

  testWidgets('clue arrows are painted above the grid', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ClueArrowLayerPainter,
      ),
      findsOneWidget,
    );
  });

  testWidgets('wrong letters render in error ink under autocheck', (
    tester,
  ) async {
    await settingsService.setAutocheck(true);
    cubit.selectCell(0, 2);
    cubit.onLetterInput('X');

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(letterColor(tester, 'X'), AppColors.errorInk);
  });

  testWidgets('revealed letters render in muted ink', (tester) async {
    cubit.selectCell(0, 2);
    cubit.revealCell();

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(letterColor(tester, 'B'), AppColors.inkMuted);
  });

  testWidgets('the active word\'s clue cell is highlighted', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    Color? hintColor() {
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(HintCellWidget),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = box.decoration;
      return decoration is BoxDecoration ? decoration.color : null;
    }

    expect(hintColor(), AppColors.clueCell);

    cubit.selectCell(0, 2);
    await tester.pumpAndSettle();

    expect(hintColor(), AppColors.clueCellActive);
  });
}
