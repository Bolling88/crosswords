import 'package:equatable/equatable.dart';

import 'package:crossword_ui/crossword_ui.dart';

class SettingsState extends Equatable {
  final List<AppFont> fonts;
  final AppFont selectedFont;
  final bool autocheck;

  const SettingsState({
    required this.fonts,
    required this.selectedFont,
    required this.autocheck,
  });

  @override
  List<Object?> get props => [fonts, selectedFont, autocheck];

  SettingsState copyWith({
    List<AppFont>? fonts,
    AppFont? selectedFont,
    bool? autocheck,
  }) {
    return SettingsState(
      fonts: fonts ?? this.fonts,
      selectedFont: selectedFont ?? this.selectedFont,
      autocheck: autocheck ?? this.autocheck,
    );
  }
}
