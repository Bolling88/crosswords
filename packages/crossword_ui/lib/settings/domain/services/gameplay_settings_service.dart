import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds gameplay preferences as cross-feature shared state and persists them
/// locally. Only cubits should touch this service.
class GameplaySettingsService {
  static const String _autocheckKey = 'autocheck_enabled';

  final SharedPreferences _prefs;

  /// Whether wrong letters are marked the moment they are typed.
  final ValueNotifier<bool> autocheck;

  GameplaySettingsService({
    required SharedPreferences prefs,
    bool? initial,
  })  : _prefs = prefs,
        autocheck = ValueNotifier(initial ?? readStored(prefs));

  /// Reads the persisted setting, defaulting to off (unassisted solving).
  static bool readStored(SharedPreferences prefs) {
    return prefs.getBool(_autocheckKey) ?? false;
  }

  /// Sets autocheck, notifies listeners, and persists the choice. A failed
  /// write is non-fatal — the in-memory value still applies this session.
  Future<void> setAutocheck(bool enabled) async {
    autocheck.value = enabled;
    try {
      await _prefs.setBool(_autocheckKey, enabled);
    } catch (_) {
      // Persistence failure is non-fatal.
    }
  }

  void dispose() => autocheck.dispose();
}
