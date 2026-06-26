import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/gen/crossword_ui_l10n.dart';
import '../cubit/crossword_cubit.dart';

enum _MenuAction {
  checkWord,
  checkPuzzle,
  revealLetter,
  revealWord,
  revealSolution,
  clearWord,
  restart,
}

/// App-bar menu with the game's check/reveal/clear/restart actions. Expects a
/// [CrosswordCubit] above it in the tree.
class CrosswordMenuButton extends StatelessWidget {
  const CrosswordMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CrosswordCubit>();
    final l10n = CrosswordUiL10n.of(context);
    return PopupMenuButton<_MenuAction>(
      tooltip: l10n.gameMenuTooltip,
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _MenuAction.checkWord:
            cubit.checkWord();
          case _MenuAction.checkPuzzle:
            cubit.checkPuzzle();
          case _MenuAction.revealLetter:
            cubit.revealCell();
          case _MenuAction.revealWord:
            cubit.revealWord();
          case _MenuAction.revealSolution:
            _confirmRevealSolution(context, cubit);
          case _MenuAction.clearWord:
            cubit.clearWord();
          case _MenuAction.restart:
            _confirmRestart(context, cubit);
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_MenuAction>>[
        PopupMenuItem(
          value: _MenuAction.checkWord,
          child: Text(l10n.checkWordAction),
        ),
        PopupMenuItem(
          value: _MenuAction.checkPuzzle,
          child: Text(l10n.checkPuzzleAction),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.revealLetter,
          child: Text(l10n.revealLetterAction),
        ),
        PopupMenuItem(
          value: _MenuAction.revealWord,
          child: Text(l10n.revealWordAction),
        ),
        PopupMenuItem(
          value: _MenuAction.revealSolution,
          child: Text(l10n.revealSolutionAction),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.clearWord,
          child: Text(l10n.clearWordAction),
        ),
        PopupMenuItem(
          value: _MenuAction.restart,
          child: Text(l10n.restartAction),
        ),
      ],
    );
  }

  /// Revealing the whole solution ends the game, so it confirms first.
  Future<void> _confirmRevealSolution(
    BuildContext context,
    CrosswordCubit cubit,
  ) async {
    final l10n = CrosswordUiL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.revealSolutionConfirmTitle),
        content: Text(l10n.revealSolutionConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.revealSolutionAction),
          ),
        ],
      ),
    );
    if (confirmed == true) cubit.revealSolution();
  }

  /// Restart is destructive, so it confirms first. View-local dialog flow,
  /// matching how screens push routes directly from buttons.
  Future<void> _confirmRestart(
    BuildContext context,
    CrosswordCubit cubit,
  ) async {
    final l10n = CrosswordUiL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.restartConfirmTitle),
        content: Text(l10n.restartConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.restartAction),
          ),
        ],
      ),
    );
    if (confirmed == true) cubit.restartPuzzle();
  }
}
