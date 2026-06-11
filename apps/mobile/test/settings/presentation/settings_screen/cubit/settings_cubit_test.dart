import 'package:crossword_ui/crossword_ui.dart';
import 'package:crosswords/settings/presentation/settings_screen/cubit/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FontService fontService;
  late SettingsCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fontService = FontService(prefs: prefs);
    cubit = SettingsCubit(fontService: fontService);
  });

  tearDown(() {
    cubit.close();
    fontService.dispose();
  });

  test('initial state lists all fonts and the current selection', () {
    expect(cubit.state.fonts, AppFont.values);
    expect(cubit.state.selectedFont, AppFont.defaultFont);
  });

  test('selectFont updates state and the service', () async {
    await cubit.selectFont(AppFont.gloriaHallelujah);

    expect(cubit.state.selectedFont, AppFont.gloriaHallelujah);
    expect(fontService.selectedFont.value, AppFont.gloriaHallelujah);
  });
}
