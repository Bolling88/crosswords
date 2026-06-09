import 'package:crosswords/gameplay/data/local_puzzle_data_source.dart';
import 'package:crosswords/gameplay/presentation/crossword_screen/crossword_screen.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final puzzle = await LocalPuzzleDataSource().loadGeneratedPuzzle();
  return RepositoryProvider<FontService>.value(
    value: FontService(prefs: prefs),
    child: MaterialApp(home: CrosswordScreen(puzzle: puzzle)),
  );
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('hidden mobile text field is absent on a desktop platform', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobileTextInput')), findsNothing);

    // Reset here too: with tearDown alone this Flutter version asserts the
    // override was left set (debugAssertAllFoundationVarsUnset runs before
    // tearDown).
    debugDefaultTargetPlatformOverride = null;
  });
}
