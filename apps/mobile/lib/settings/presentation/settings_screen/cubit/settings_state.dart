import 'package:equatable/equatable.dart';

import 'package:crossword_ui/crossword_ui.dart';

class SettingsState extends Equatable {
  final List<AppFont> fonts;
  final AppFont selectedFont;

  const SettingsState({
    required this.fonts,
    required this.selectedFont,
  });

  @override
  List<Object?> get props => [fonts, selectedFont];

  SettingsState copyWith({
    List<AppFont>? fonts,
    AppFont? selectedFont,
  }) {
    return SettingsState(
      fonts: fonts ?? this.fonts,
      selectedFont: selectedFont ?? this.selectedFont,
    );
  }
}
