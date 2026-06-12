import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A player's saved fill state for one puzzle.
class ProgressSnapshot extends Equatable {
  final Map<(int, int), String> userInputs;
  final Set<(int, int)> revealedCells;

  const ProgressSnapshot({
    this.userInputs = const <(int, int), String>{},
    this.revealedCells = const <(int, int)>{},
  });

  bool get isEmpty => userInputs.isEmpty && revealedCells.isEmpty;

  @override
  List<Object?> get props => [userInputs, revealedCells];
}

/// Persists puzzle fill progress locally so the grid survives an app restart.
/// Keyed per puzzle; the format has no stable puzzle id yet, so callers pass
/// the title while puzzles are bundled. Only cubits should touch this service.
class ProgressService {
  static const String _prefix = 'progress_';

  final SharedPreferences _prefs;

  ProgressService({required SharedPreferences prefs}) : _prefs = prefs;

  /// The saved snapshot for [puzzleKey], or null when absent or unreadable
  /// (corrupt data falls back to a clean grid rather than crashing).
  ProgressSnapshot? read(String puzzleKey) {
    final raw = _prefs.getString('$_prefix$puzzleKey');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final inputs = <(int, int), String>{
        for (final entry in (json['inputs'] as Map<String, dynamic>).entries)
          _parsePos(entry.key): entry.value as String,
      };
      final revealed = <(int, int)>{
        for (final pos in json['revealed'] as List<dynamic>)
          _parsePos(pos as String),
      };
      return ProgressSnapshot(userInputs: inputs, revealedCells: revealed);
    } catch (_) {
      return null;
    }
  }

  /// Persist [snapshot]. An empty snapshot removes the entry instead. A
  /// failed write is non-fatal — the in-memory state still applies.
  Future<void> save(String puzzleKey, ProgressSnapshot snapshot) async {
    if (snapshot.isEmpty) return clear(puzzleKey);
    try {
      await _prefs.setString(
        '$_prefix$puzzleKey',
        jsonEncode({
          'inputs': {
            for (final entry in snapshot.userInputs.entries)
              _keyOf(entry.key): entry.value,
          },
          'revealed': [
            for (final pos in snapshot.revealedCells) _keyOf(pos),
          ],
        }),
      );
    } catch (_) {
      // Persistence failure is non-fatal.
    }
  }

  /// Remove any saved progress for [puzzleKey].
  Future<void> clear(String puzzleKey) async {
    try {
      await _prefs.remove('$_prefix$puzzleKey');
    } catch (_) {
      // Persistence failure is non-fatal.
    }
  }

  static String _keyOf((int, int) pos) => '${pos.$1},${pos.$2}';

  static (int, int) _parsePos(String key) {
    final parts = key.split(',');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }
}
