import 'package:crosswords/gameplay/presentation/crossword_screen/crossword_screen.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:crosswords/settings/presentation/settings_screen/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _appUnderTest() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return RepositoryProvider<FontService>.value(
    value: FontService(prefs: prefs),
    child: const MaterialApp(home: CrosswordScreen()),
  );
}

void main() {
  testWidgets(
    'CrosswordScreen renders the sample puzzle inside an InteractiveViewer '
    'without throwing',
    (tester) async {
      await tester.pumpWidget(await _appUnderTest());
      await tester.pumpAndSettle();

      // No exception was thrown while laying out the real 15x13 sample puzzle
      // inside InteractiveViewer(constrained: false) — guards against the
      // boundary assertion that finite boundaryMargin could otherwise trigger.
      expect(tester.takeException(), isNull);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    },
  );

  testWidgets('tapping the settings icon opens the settings screen', (
    tester,
  ) async {
    await tester.pumpWidget(await _appUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('tapping the reset icon resets zoom/pan to identity', (
    tester,
  ) async {
    await tester.pumpWidget(await _appUnderTest());
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
