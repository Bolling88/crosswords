import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../common/data/constants/app_colors.dart';
import '../../../common/data/constants/app_text_styles.dart';
import '../../../common/data/constants/strings.dart';
import '../../../gameplay/data/sample_puzzle.dart';
import '../../../settings/domain/services/font_service.dart';
import 'cubit/crossword_cubit.dart';
import 'cubit/crossword_state.dart';
import 'widgets/crossword_grid.dart';

class CrosswordScreen extends StatelessWidget {
  const CrosswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrosswordCubit(
        puzzle: buildSamplePuzzle(),
        fontService: context.read<FontService>(),
      ),
      child: const CrosswordScreenBuilder(),
    );
  }
}

class CrosswordScreenBuilder extends StatelessWidget {
  const CrosswordScreenBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CrosswordCubit, CrosswordState>(
      builder: (context, state) => CrosswordScreenContent(state: state),
    );
  }
}

class CrosswordScreenContent extends StatelessWidget {
  final CrosswordState state;

  const CrosswordScreenContent({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CrosswordCubit>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(Strings.appTitle, style: AppTextStyles.appBarTitle()),
        centerTitle: true,
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: Strings.resetViewTooltip,
            onPressed: cubit.resetView,
          ),
        ],
      ),
      body: Focus(
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
          return KeyEventResult.ignored;
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gridPadding = 16.0;
              final viewportWidth = constraints.maxWidth - gridPadding * 2;
              final cellSize =
                  (viewportWidth - CrosswordGrid.borderWidth * 2) /
                      state.puzzle.cols;

              // Full rendered height of the grid (cells + frame border +
              // surrounding padding).
              final contentHeight = state.puzzle.rows * cellSize +
                  CrosswordGrid.borderWidth * 2 +
                  gridPadding * 2;
              // The viewer's child must be at least as large as the viewport in
              // both axes. If it were smaller (e.g. a grid shorter than the
              // screen), InteractiveViewer forces a minimum scale > 1.0 to keep
              // the child covering the viewport — making it impossible to zoom
              // back out to the whole puzzle. Sizing to max(content, viewport)
              // keeps fit-to-screen reachable while still growing for puzzles
              // taller than the screen so they can be scrolled.
              final boxHeight = contentHeight > constraints.maxHeight
                  ? contentHeight
                  : constraints.maxHeight;

              return InteractiveViewer(
                transformationController: cubit.transformationController,
                // Fit-to-screen (scale 1.0) is the most zoomed-out state;
                // zoom only goes inward from there up to 4x. Combined with the
                // zero boundaryMargin this guarantees the puzzle always returns
                // cleanly to fit and can never be dragged off-screen.
                minScale: 1.0,
                maxScale: 4.0,
                constrained: false,
                // Zero margin pins panning to the child's bounds. The
                // gridPadding below keeps a small visual gutter at the edges.
                boundaryMargin: EdgeInsets.zero,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: boxHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
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
    );
  }
}
