import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../common/data/constants/app_colors.dart';
import '../../../common/data/constants/app_text_styles.dart';
import '../../../common/data/constants/strings.dart';
import '../../../gameplay/data/sample_puzzle.dart';
import 'cubit/crossword_cubit.dart';
import 'cubit/crossword_state.dart';
import 'widgets/crossword_grid.dart';

class CrosswordScreen extends StatelessWidget {
  const CrosswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrosswordCubit(puzzle: buildSamplePuzzle()),
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
              return InteractiveViewer(
                transformationController: cubit.transformationController,
                minScale: 0.5,
                maxScale: 4.0,
                constrained: false,
                // Zero margin pins panning to the grid's own bounds, so the
                // puzzle can never be dragged off-screen — including when
                // fully zoomed out, where the grid is smaller than the
                // viewport. The gridPadding below keeps a small visual gutter.
                boundaryMargin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(gridPadding),
                  child: CrosswordGrid(state: state, cellSize: cellSize),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
