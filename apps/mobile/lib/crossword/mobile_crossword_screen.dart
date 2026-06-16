import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

class MobileCrosswordScreen extends StatelessWidget {
  final CrosswordPuzzle puzzle;

  const MobileCrosswordScreen({required this.puzzle, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrosswordCubit(
        puzzle: puzzle,
        fontService: context.read<FontService>(),
        settingsService: context.read<GameplaySettingsService>(),
        progressService: context.read<ProgressService>(),
      ),
      child: const _MobileCrosswordView(),
    );
  }
}

class _MobileCrosswordView extends StatelessWidget {
  const _MobileCrosswordView();

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
      body: const CrosswordPlayer(),
    );
  }
}
