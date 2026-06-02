import 'package:crosswords/gameplay/presentation/crossword_screen/crossword_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'CrosswordScreen renders the sample puzzle inside an InteractiveViewer '
    'without throwing',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CrosswordScreen()));
      await tester.pumpAndSettle();

      // No exception was thrown while laying out the real 15x13 sample puzzle
      // inside InteractiveViewer(constrained: false) — guards against the
      // boundary assertion that finite boundaryMargin could otherwise trigger.
      expect(tester.takeException(), isNull);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    },
  );

  testWidgets('tapping the reset icon resets zoom/pan to identity', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CrosswordScreen()));
    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final controller = viewer.transformationController;
    controller?.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);

    await tester.tap(find.byIcon(Icons.fit_screen));
    await tester.pumpAndSettle();

    expect(controller?.value, equals(Matrix4.identity()));
  });
}
