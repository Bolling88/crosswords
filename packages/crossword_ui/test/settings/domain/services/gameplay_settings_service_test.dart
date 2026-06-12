import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('autocheck defaults to off', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(GameplaySettingsService(prefs: prefs).autocheck.value, isFalse);
  });

  test('setAutocheck updates the notifier and persists the value', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = GameplaySettingsService(prefs: prefs);

    await service.setAutocheck(true);

    expect(service.autocheck.value, isTrue);
    expect(prefs.getBool('autocheck_enabled'), isTrue);
  });

  test('a new service restores the stored setting (restart)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GameplaySettingsService(prefs: prefs).setAutocheck(true);

    expect(GameplaySettingsService(prefs: prefs).autocheck.value, isTrue);
  });
}
