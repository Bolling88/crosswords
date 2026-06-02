import 'package:crosswords/gameplay/data/entities/cell.dart';
import 'package:crosswords/gameplay/data/entities/crossword_puzzle.dart';
import 'package:crosswords/gameplay/data/entities/direction.dart';
import 'package:crosswords/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

CrosswordPuzzle _buildTestPuzzle() {
  // 4x4 test grid:
  // H→↓  A    A    A
  // A    H→↓  A    A
  // A    A    A    #
  // H→   A    A    A
  return const CrosswordPuzzle(
    rows: 4,
    cols: 4,
    cells: {
      (0, 0): HintCell(
        clueText: 'Test',
        arrows: [Direction.right, Direction.down],
      ),
      (0, 1): AnswerCell(solution: 'A'),
      (0, 2): AnswerCell(solution: 'B'),
      (0, 3): AnswerCell(solution: 'C'),
      (1, 0): AnswerCell(solution: 'D'),
      (1, 1): HintCell(
        clueText: 'Test 2',
        arrows: [Direction.right, Direction.down],
      ),
      (1, 2): AnswerCell(solution: 'E'),
      (1, 3): AnswerCell(solution: 'F'),
      (2, 0): AnswerCell(solution: 'G'),
      (2, 1): AnswerCell(solution: 'H'),
      (2, 2): AnswerCell(solution: 'I'),
      (2, 3): BlockedCell(),
      (3, 0): HintCell(
        clueText: 'Test 3',
        arrows: [Direction.right],
      ),
      (3, 1): AnswerCell(solution: 'J'),
      (3, 2): AnswerCell(solution: 'K'),
      (3, 3): AnswerCell(solution: 'L'),
    },
  );
}

void main() {
  late CrosswordCubit cubit;

  setUp(() {
    cubit = CrosswordCubit(puzzle: _buildTestPuzzle());
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state has no selection', () {
    expect(cubit.state.selectedCell, isNull);
    expect(cubit.state.highlightedCells, isEmpty);
  });

  test('selecting an answer cell highlights the horizontal word', () {
    cubit.selectCell(0, 1);

    expect(cubit.state.selectedCell, equals((0, 1)));
    expect(cubit.state.currentDirection, equals(Direction.right));
    expect(
      cubit.state.highlightedCells,
      equals({(0, 1), (0, 2), (0, 3)}),
    );
  });

  test('selecting a hint cell selects first answer cell in arrow direction', () {
    cubit.selectCell(0, 0);

    expect(cubit.state.selectedCell, equals((0, 1)));
    expect(cubit.state.currentDirection, equals(Direction.right));
  });

  test('selecting a blocked cell does nothing', () {
    cubit.selectCell(2, 3);

    expect(cubit.state.selectedCell, isNull);
  });

  test('tapping already-selected cell at crossing toggles direction', () {
    // (2,1) is at a crossing: horizontal (2,0)(2,1)(2,2) and vertical (2,1)(3,1)
    cubit.selectCell(2, 1);
    expect(cubit.state.currentDirection, equals(Direction.right));
    expect(
      cubit.state.highlightedCells,
      equals({(2, 0), (2, 1), (2, 2)}),
    );

    cubit.selectCell(2, 1);
    expect(cubit.state.currentDirection, equals(Direction.down));
    expect(
      cubit.state.highlightedCells,
      equals({(2, 1), (3, 1)}),
    );
  });

  test('typing a letter fills cell and auto-advances', () {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('X');

    expect(cubit.state.userInputs[(0, 1)], equals('X'));
    expect(cubit.state.selectedCell, equals((0, 2)));
  });

  test('backspace clears current cell and moves back', () {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('X');
    cubit.onLetterInput('Y');
    // Now at (0,3), inputs: (0,1)=X, (0,2)=Y

    cubit.onBackspace();
    // (0,3) was empty, so move back to (0,2) and clear it
    expect(cubit.state.selectedCell, equals((0, 2)));
    expect(cubit.state.userInputs.containsKey((0, 2)), isFalse);
  });

  test('resetView resets the transformation to identity', () {
    // Simulate a zoomed/panned state.
    cubit.transformationController.value = Matrix4.identity()
      ..scale(2.0)
      ..translate(30.0, 40.0);
    expect(
      cubit.transformationController.value,
      isNot(equals(Matrix4.identity())),
    );

    cubit.resetView();

    expect(cubit.transformationController.value, equals(Matrix4.identity()));
  });

  test('close disposes the transformation controller without throwing', () async {
    final cubit = CrosswordCubit(puzzle: _buildTestPuzzle());
    await cubit.close();
    // Using a disposed ChangeNotifier throws; confirm it was disposed.
    expect(
      () => cubit.transformationController.addListener(() {}),
      throwsA(isA<FlutterError>()),
    );
  });
}
