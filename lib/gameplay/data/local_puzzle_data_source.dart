import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/entities/crossword_puzzle.dart';
import 'entities/dto/puzzle_dto.dart';
import 'puzzle_resolver.dart';

/// Loads the bundled, hardcoded crossword from assets. A backend-backed
/// source can replace this later behind the same return type.
class LocalPuzzleDataSource {
  static const String _assetPath = 'assets/puzzles/generated_crossword.json';

  final AssetBundle _bundle;

  LocalPuzzleDataSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  Future<CrosswordPuzzle> loadGeneratedPuzzle() async {
    final raw = await _bundle.loadString(_assetPath);
    final dto = PuzzleDto.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return PuzzleResolver.resolve(dto);
  }
}
