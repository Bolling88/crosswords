import 'package:crosswords/settings/domain/entities/app_font.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('readStored returns the default when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(FontService.readStored(prefs), AppFont.defaultFont);
  });

  test('readStored returns the stored font', () async {
    SharedPreferences.setMockInitialValues({
      'selected_font': AppFont.kalam.name,
    });
    final prefs = await SharedPreferences.getInstance();

    expect(FontService.readStored(prefs), AppFont.kalam);
  });

  test('selectFont updates the notifier and persists the value', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = FontService(prefs: prefs);

    expect(service.selectedFont.value, AppFont.defaultFont);

    await service.selectFont(AppFont.caveat);

    expect(service.selectedFont.value, AppFont.caveat);
    expect(prefs.getString('selected_font'), AppFont.caveat.name);
  });

  test('a new service restores the previously selected font (restart)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await FontService(prefs: prefs).selectFont(AppFont.indieFlower);

    // Simulate a fresh launch: a new service built from the same storage.
    final restarted = FontService(prefs: prefs);
    expect(restarted.selectedFont.value, AppFont.indieFlower);
  });
}
