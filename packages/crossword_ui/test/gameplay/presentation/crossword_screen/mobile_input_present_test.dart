import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fontService = FontService(prefs: prefs);
  final puzzle = await LocalPuzzleDataSource().loadGeneratedPuzzle();
  return MaterialApp(
    home: RepositoryProvider<FontService>.value(
      value: fontService,
      child: BlocProvider(
        create: (context) => CrosswordCubit(
          puzzle: puzzle,
          fontService: fontService,
          settingsService: GameplaySettingsService(prefs: prefs),
          progressService: ProgressService(prefs: prefs),
        ),
        child: const Scaffold(body: CrosswordPlayer()),
      ),
    ),
  );
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('hidden mobile text field is present on a touch platform', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobileTextInput')), findsOneWidget);

    // Reset here too: with tearDown alone this Flutter version asserts the
    // override was left set (debugAssertAllFoundationVarsUnset runs before
    // tearDown).
    debugDefaultTargetPlatformOverride = null;
  });
}
