import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _arrowPaints() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ClueArrowPainter,
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
  testWidgets('empty clue cell paints no arrows', (tester) async {
    await tester.pumpWidget(_host(const ClueCell()));
    expect(_arrowPaints(), findsNothing);
  });

  testWidgets('non-default (bent) clue paints one arrow, no divider column',
      (tester) async {
    await tester.pumpWidget(_host(const ClueCell(arrows: [
      ClueArrow(
        direction: Direction.right,
        shape: ArrowShape.bentDownThenRight,
        wordId: 'w1',
      ),
    ])));
    expect(_arrowPaints(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HintCellWidget),
        matching: find.byType(Column),
      ),
      findsNothing,
    );
  });

  testWidgets('default straight clues draw no arrow (logical reading order)',
      (tester) async {
    await tester.pumpWidget(_host(const ClueCell(arrows: [
      ClueArrow(
        direction: Direction.right,
        shape: ArrowShape.straightRight,
        wordId: 'w1',
      ),
    ])));
    expect(_arrowPaints(), findsNothing);
    // The clue text is still rendered.
    expect(
      find.descendant(
        of: find.byType(HintCellWidget),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('two-clue cell splits into two compartments with a divider',
      (tester) async {
    await tester.pumpWidget(_host(const ClueCell(arrows: [
      ClueArrow(
        direction: Direction.right,
        shape: ArrowShape.bentDownThenRight,
        wordId: 'top',
      ),
      ClueArrow(
        direction: Direction.down,
        shape: ArrowShape.bentRightThenDown,
        wordId: 'bottom',
      ),
    ])));
    expect(_arrowPaints(), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(HintCellWidget),
        matching: find.byType(Column),
      ),
      findsOneWidget,
    );
  });

  testWidgets('single clue renders its (mock) clue text', (tester) async {
    await tester.pumpWidget(_host(const ClueCell(arrows: [
      ClueArrow(
        direction: Direction.right,
        shape: ArrowShape.straightRight,
        wordId: 'w1',
      ),
    ])));
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(HintCellWidget),
        matching: find.byType(Text),
      ),
    );
    expect(text.data, isNotNull);
    expect(text.data, isNotEmpty);
  });

  testWidgets('two-clue cell renders one clue text per compartment',
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
    expect(
      find.descendant(
        of: find.byType(HintCellWidget),
        matching: find.byType(Text),
      ),
      findsNWidgets(2),
    );
  });
}
