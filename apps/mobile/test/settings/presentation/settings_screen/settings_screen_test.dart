import 'package:crossword_ui/crossword_ui.dart';
import 'package:crosswords/settings/presentation/settings_screen/settings_screen.dart';
import 'package:crosswords/settings/presentation/settings_screen/widgets/font_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _settingsUnderTest() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FontService>.value(value: FontService(prefs: prefs)),
      RepositoryProvider<GameplaySettingsService>.value(
        value: GameplaySettingsService(prefs: prefs),
      ),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  testWidgets('SettingsScreen lists all fonts without throwing', (tester) async {
    await tester.pumpWidget(await _settingsUnderTest());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(FontOptionTile), findsNWidgets(AppFont.values.length));
  });

  testWidgets('shows the autocheck switch', (tester) async {
    await tester.pumpWidget(await _settingsUnderTest());
    await tester.pumpAndSettle();

    expect(find.text(Strings.autocheckLabel), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
