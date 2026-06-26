import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _arrowPaints() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ClueArrowPainter,
    );

Widget _host({List<ClueArrow> arrows = const [], String? letter}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: AnswerCellWidget(
            size: 48,
            onTap: () {},
            fontFamily: 'Roboto',
            letter: letter,
            arrows: arrows,
          ),
        ),
      ),
    );

void main() {
  testWidgets('plain answer box draws no arrow', (tester) async {
    await tester.pumpWidget(_host());
    expect(_arrowPaints(), findsNothing);
  });

  testWidgets('a deviating word-start box draws its arrow', (tester) async {
    await tester.pumpWidget(_host(arrows: const [
      ClueArrow(
        direction: Direction.right,
        shape: ArrowShape.bentDownThenRight,
        wordId: 'w1',
      ),
    ]));
    expect(_arrowPaints(), findsOneWidget);
  });

  testWidgets('a box starting two deviating words draws two arrows',
      (tester) async {
    await tester.pumpWidget(_host(arrows: const [
      ClueArrow(
        direction: Direction.right,
        shape: ArrowShape.bentUpThenRight,
        wordId: 'across',
      ),
      ClueArrow(
        direction: Direction.down,
        shape: ArrowShape.bentLeftThenDown,
        wordId: 'down',
      ),
    ]));
    expect(_arrowPaints(), findsNWidgets(2));
  });

  testWidgets('the typed letter still renders over an arrow', (tester) async {
    await tester.pumpWidget(_host(
      letter: 'A',
      arrows: const [
        ClueArrow(
          direction: Direction.right,
          shape: ArrowShape.bentDownThenRight,
          wordId: 'w1',
        ),
      ],
    ));
    expect(find.text('A'), findsOneWidget);
    expect(_arrowPaints(), findsOneWidget);
  });
}
