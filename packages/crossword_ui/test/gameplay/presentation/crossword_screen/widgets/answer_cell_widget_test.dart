import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _arrowLayerPaints() => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is ClueArrowLayerPainter,
);

Widget _host({String? letter}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: AnswerCellWidget(
        size: 48,
        onTap: () {},
        fontFamily: 'Roboto',
        letter: letter,
      ),
    ),
  ),
);

void main() {
  testWidgets('plain answer box draws no arrow', (tester) async {
    await tester.pumpWidget(_host());
    expect(_arrowLayerPaints(), findsNothing);
  });

  testWidgets('the typed letter renders without clue-cell arrows', (
    tester,
  ) async {
    await tester.pumpWidget(_host(letter: 'A'));
    expect(find.text('A'), findsOneWidget);
    expect(_arrowLayerPaints(), findsNothing);
  });
}
