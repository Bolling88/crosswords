import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_ui/crossword_ui.dart';

import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final FontService _fontService;
  final GameplaySettingsService _settingsService;

  SettingsCubit({
    required FontService fontService,
    required GameplaySettingsService settingsService,
  })  : _fontService = fontService,
        _settingsService = settingsService,
        super(SettingsState(
          fonts: AppFont.values,
          selectedFont: fontService.selectedFont.value,
          autocheck: settingsService.autocheck.value,
        ));

  Future<void> selectFont(AppFont font) async {
    await _fontService.selectFont(font);
    emit(state.copyWith(selectedFont: font));
  }

  Future<void> setAutocheck(bool enabled) async {
    await _settingsService.setAutocheck(enabled);
    emit(state.copyWith(autocheck: enabled));
  }
}
