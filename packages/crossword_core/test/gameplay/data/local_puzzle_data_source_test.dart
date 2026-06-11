import 'package:crossword_core/crossword_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled puzzle from assets into the domain model', () async {
    final puzzle = await LocalPuzzleDataSource().loadGeneratedPuzzle();

    expect(puzzle.rows, 15);
    expect(puzzle.cols, 13);
    expect(puzzle.title, 'Generated crossword');
    expect(puzzle.words, isNotEmpty);
    expect(puzzle.seedPositions, isNotEmpty);
  });
}
