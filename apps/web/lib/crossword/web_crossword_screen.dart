import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

class WebCrosswordScreen extends StatelessWidget {
  final CrosswordPuzzle puzzle;

  const WebCrosswordScreen({required this.puzzle, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrosswordCubit(
        puzzle: puzzle,
        fontService: context.read<FontService>(),
        settingsService: context.read<GameplaySettingsService>(),
        progressService: context.read<ProgressService>(),
      ),
      child: const _WebCrosswordView(),
    );
  }
}

class _WebCrosswordView extends StatelessWidget {
  const _WebCrosswordView();

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
          const CrosswordMenuButton(),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: Strings.resetViewTooltip,
            onPressed: cubit.resetView,
          ),
        ],
      ),
      // Full-bleed: the player uses the whole width so a zoomed-in grid can be
      // panned across the entire screen (the grid still fits-and-centres at
      // rest via its own LayoutBuilder).
      body: const CrosswordPlayer(),
    );
  }
}
