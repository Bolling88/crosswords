import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _arrowLayerPaints() => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is ClueArrowLayerPainter,
);

Widget _host({String? letter, bool isSelected = false}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: AnswerCellWidget(
        size: 48,
        onTap: () {},
        fontFamily: 'Roboto',
        semanticLabel: 'rad 1, kolumn 1',
        isSelected: isSelected,
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

  testWidgets('exposes its position label to the screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(letter: 'A'));
    expect(
      tester.getSemantics(find.byType(AnswerCellWidget)),
      matchesSemantics(
        label: 'rad 1, kolumn 1',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('selected cell is marked selected in semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(letter: 'A', isSelected: true));
    expect(
      tester.getSemantics(find.byType(AnswerCellWidget)),
      matchesSemantics(
        label: 'rad 1, kolumn 1',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
