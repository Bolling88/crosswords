import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../common/data/constants/app_colors.dart';
import '../../../common/data/constants/strings.dart';
import 'cubit/crossword_cubit.dart';
import 'cubit/crossword_state.dart';
import 'widgets/crossword_grid.dart';

/// The reusable crossword play surface. Embed inside any [Scaffold]. Expects a
/// [CrosswordCubit] provided above it in the tree so host app bars can drive it
/// (e.g. `cubit.resetView`). Also hosts the one-shot feedback for solving the
/// puzzle (celebration dialog) and filling it incorrectly (SnackBar nudge).
class CrosswordPlayer extends StatelessWidget {
  const CrosswordPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CrosswordCubit, CrosswordState>(
      listener: (context, state) {
        if (state is PuzzleSolved) {
          _showSolvedDialog(context);
        } else if (state is PuzzleFilledButIncorrect) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(Strings.puzzleFilledButIncorrect),
            ),
          );
        }
      },
      builder: (context, state) => _CrosswordPlayerBody(state: state),
    );
  }

  /// Subtle, paper-styled celebration: congratulations plus the choice to
  /// keep admiring the grid or start over.
  void _showSolvedDialog(BuildContext context) {
    final cubit = context.read<CrosswordCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text(Strings.solvedTitle),
        content: const Text(Strings.solvedBody),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              cubit.restartPuzzle();
            },
            child: const Text(Strings.restartAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(Strings.closeAction),
          ),
        ],
      ),
    );
  }
}

class _CrosswordPlayerBody extends StatelessWidget {
  final CrosswordState state;

  const _CrosswordPlayerBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CrosswordCubit>();
    return Stack(
      children: [
        Focus(
          focusNode: cubit.focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final char = event.character;
            if (char != null &&
                char.length == 1 &&
                RegExp(r'[a-zA-ZåäöÅÄÖ]').hasMatch(char)) {
              cubit.onLetterInput(char.toUpperCase());
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.backspace) {
              cubit.onBackspace();
              return KeyEventResult.handled;
            }
            switch (event.logicalKey) {
              case LogicalKeyboardKey.arrowUp:
                cubit.moveSelection(-1, 0);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowDown:
                cubit.moveSelection(1, 0);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowLeft:
                cubit.moveSelection(0, -1);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowRight:
                cubit.moveSelection(0, 1);
                return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gridPadding = 16.0;
                final viewportWidth = constraints.maxWidth - gridPadding * 2;
                final viewportHeight = constraints.maxHeight - gridPadding * 2;
                final cellSizeByWidth =
                    (viewportWidth - CrosswordGrid.borderWidth * 2) /
                        state.puzzle.cols;
                final cellSizeByHeight =
                    (viewportHeight - CrosswordGrid.borderWidth * 2) /
                        state.puzzle.rows;
                final cellSize = min(cellSizeByWidth, cellSizeByHeight);

                return InteractiveViewer(
                  transformationController: cubit.transformationController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  constrained: false,
                  boundaryMargin: EdgeInsets.zero,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Align(
                      child: Padding(
                        padding: const EdgeInsets.all(gridPadding),
                        child: CrosswordGrid(state: state, cellSize: cellSize),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (cubit.isTouchPlatform)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  key: const Key('mobileTextInput'),
                  controller: cubit.inputController,
                  focusNode: cubit.keyboardFocusNode,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  showCursor: false,
                  onChanged: cubit.onInputChanged,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
