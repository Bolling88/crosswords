import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _arrowPaints() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ClueArrowPainter,
    );

Finder _clueTexts() => find.descendant(
      of: find.byType(HintCellWidget),
      matching: find.byType(Text),
    );

Widget _host(ClueCell cell) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: HintCellWidget(
            cell: cell,
            size: 48,
            onTap: () {},
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );

void main() {
  testWidgets('empty clue cell renders no text and no arrow', (tester) async {
    await tester.pumpWidget(_host(const ClueCell()));
    expect(_clueTexts(), findsNothing);
    expect(_arrowPaints(), findsNothing);
  });

  testWidgets('clue cell is text-only — arrows live in the answer boxes',
      (tester) async {
    await tester.pumpWidget(_host(const ClueCell(arrows: [
      ClueArrow(
        direction: Direction.right,
        shape: ArrowShape.bentDownThenRight,
        wordId: 'w1',
      ),
    ])));
    expect(_clueTexts(), findsOneWidget);
    expect(_arrowPaints(), findsNothing);
    expect(
      find.descendant(
        of: find.byType(HintCellWidget),
        matching: find.byType(Column),
      ),
      findsNothing,
    );
  });

  testWidgets('two-clue cell splits with a divider and one text per half',
      (tester) async {
    await tester.pumpWidget(_host(const ClueCell(arrows: [
      ClueArrow(
        direction: Direction.right,
        shape: ArrowShape.straightRight,
        wordId: 'top',
      ),
      ClueArrow(
        direction: Direction.down,
        shape: ArrowShape.straightDown,
        wordId: 'bottom',
      ),
    ])));
    expect(_clueTexts(), findsNWidgets(2));
    expect(_arrowPaints(), findsNothing);
    expect(
      find.descendant(
        of: find.byType(HintCellWidget),
        matching: find.byType(Column),
      ),
      findsOneWidget,
    );
  });
}
