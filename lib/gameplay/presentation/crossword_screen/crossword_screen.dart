import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../common/data/constants/app_colors.dart';
import '../../../common/data/constants/app_text_styles.dart';
import '../../../common/data/constants/strings.dart';
import '../../../gameplay/domain/entities/crossword_puzzle.dart';
import '../../../settings/domain/services/font_service.dart';
import 'cubit/crossword_cubit.dart';
import 'cubit/crossword_state.dart';
import '../../../settings/presentation/settings_screen/settings_screen.dart';
import 'widgets/crossword_grid.dart';

class CrosswordScreen extends StatelessWidget {
  final CrosswordPuzzle puzzle;

  const CrosswordScreen({required this.puzzle, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrosswordCubit(
        puzzle: puzzle,
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
            icon: const Icon(Icons.settings),
            tooltip: Strings.settingsTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
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
              final viewportHeight = constraints.maxHeight - gridPadding * 2;

              // Fit the whole puzzle within the viewport on BOTH axes: derive a
              // cell size from the available width and from the available
              // height, then take the smaller so neither dimension overflows.
              // Width-only sizing clips the bottom on wide/short viewports
              // (e.g. tablets) where the height-fit is the binding constraint.
              final cellSizeByWidth =
                  (viewportWidth - CrosswordGrid.borderWidth * 2) /
                      state.puzzle.cols;
              final cellSizeByHeight =
                  (viewportHeight - CrosswordGrid.borderWidth * 2) /
                      state.puzzle.rows;
              final cellSize = min(cellSizeByWidth, cellSizeByHeight);

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
    );
  }
}
