import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../entities/app_font.dart';

/// Holds the currently selected [AppFont] as cross-feature shared state and
/// persists it locally. Only cubits should touch this service.
class FontService {
  static const String _key = 'selected_font';

  final SharedPreferences _prefs;

  /// The active font. Listeners (cubits) react to changes.
  final ValueNotifier<AppFont> selectedFont;

  FontService({
    required SharedPreferences prefs,
    AppFont? initial,
  })  : _prefs = prefs,
        selectedFont = ValueNotifier(initial ?? readStored(prefs));

  /// Reads the persisted font, falling back to [AppFont.defaultFont].
  static AppFont readStored(SharedPreferences prefs) {
    return AppFont.fromName(prefs.getString(_key));
  }

  /// Selects [font], notifies listeners, and persists the choice. A failed
  /// write is non-fatal — the in-memory selection still applies this session.
  Future<void> selectFont(AppFont font) async {
    selectedFont.value = font;
    try {
      await _prefs.setString(_key, font.name);
    } catch (_) {
      // Persistence failure is non-fatal.
    }
  }

  void dispose() => selectedFont.dispose();
}
