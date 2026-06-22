import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements PuzzleGenerationService {
  final CrosswordPuzzle? puzzle;
  final Object? error;
  _FakeService({this.puzzle, this.error});

  @override
  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
  }) async {
    final err = error;
    if (err != null) throw err;
    final p = puzzle;
    if (p == null) throw StateError('puzzle not set');
    return p;
  }

  @override
  Future<CrosswordPuzzle> loadTestPuzzle() async {
    final err = error;
    if (err != null) throw err;
    final p = puzzle;
    if (p == null) throw StateError('puzzle not set');
    return p;
  }
}

CrosswordPuzzle _puzzle() => const CrosswordPuzzle(
      rows: 1,
      cols: 1,
      cells: {},
      words: [],
      title: 'X',
      languageCode: 'sv',
    );

/// Runs [action], collecting every state the cubit emits during it.
/// The extra [Future.delayed] flush ensures microtask-scheduled stream events
/// (non-sync broadcast controller) are delivered before we cancel.
Future<List<GenerateState>> _collect(
  GeneratePuzzleCubit cubit,
  Future<void> Function() action,
) async {
  final states = <GenerateState>[];
  final sub = cubit.stream.listen(states.add);
  await action();
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return states;
}

void main() {
  test('selectSize updates width and height', () async {
    final cubit = GeneratePuzzleCubit(service: _FakeService());
    cubit.selectSize(17);
    expect(cubit.state.width, 17);
    expect(cubit.state.height, 17);
    await cubit.close();
  });

  test('selectMaxWordLen updates maxWordLen', () async {
    final cubit = GeneratePuzzleCubit(service: _FakeService());
    cubit.selectMaxWordLen(8);
    expect(cubit.state.maxWordLen, 8);
    await cubit.close();
  });

  test('generate emits generating then GenerationSucceeded', () async {
    final cubit = GeneratePuzzleCubit(service: _FakeService(puzzle: _puzzle()));
    final states = await _collect(cubit, cubit.generate);
    expect(states.first.isGenerating, isTrue);
    expect(states.last, isA<GenerationSucceeded>());
    expect((states.last as GenerationSucceeded).puzzle.title, 'X');
    await cubit.close();
  });

  test('generate emits ShowGenerationError on failure', () async {
    final cubit = GeneratePuzzleCubit(
      service: _FakeService(error: const CrosswordGenerationException('x')),
    );
    final states = await _collect(cubit, cubit.generate);
    expect(states.first.isGenerating, isTrue);
    expect(states.last, isA<ShowGenerationError>());
    expect(states.last.isGenerating, isFalse);
    await cubit.close();
  });

  test('openTestPuzzle emits GenerationSucceeded', () async {
    final cubit = GeneratePuzzleCubit(service: _FakeService(puzzle: _puzzle()));
    final states = await _collect(cubit, cubit.openTestPuzzle);
    expect(states.last, isA<GenerationSucceeded>());
    await cubit.close();
  });
}
