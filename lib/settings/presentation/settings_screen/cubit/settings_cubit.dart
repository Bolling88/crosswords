import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/app_font.dart';
import '../../../domain/services/font_service.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final FontService _fontService;

  SettingsCubit({required FontService fontService})
      : _fontService = fontService,
        super(SettingsState(
          fonts: AppFont.values,
          selectedFont: fontService.selectedFont.value,
        ));

  Future<void> selectFont(AppFont font) async {
    await _fontService.selectFont(font);
    emit(state.copyWith(selectedFont: font));
  }
}
