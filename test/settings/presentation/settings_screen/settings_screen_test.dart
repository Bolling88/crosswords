import 'package:crosswords/settings/domain/entities/app_font.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:crosswords/settings/presentation/settings_screen/settings_screen.dart';
import 'package:crosswords/settings/presentation/settings_screen/widgets/font_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _settingsUnderTest() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return RepositoryProvider<FontService>.value(
    value: FontService(prefs: prefs),
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
}
