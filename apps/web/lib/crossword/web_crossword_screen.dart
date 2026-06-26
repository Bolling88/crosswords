import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_auth/crossword_auth.dart';
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
    final l10n = CrosswordUiL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandAppBar(
        title: l10n.appTitle,
        actions: [
          const CrosswordMenuButton(),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settingsTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: CrosswordAuthL10n.of(context).accountTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: l10n.resetViewTooltip,
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
