import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/data/constants/strings.dart';
import '../cubit/crossword_cubit.dart';

enum _MenuAction {
  checkWord,
  checkPuzzle,
  revealLetter,
  revealWord,
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
    return PopupMenuButton<_MenuAction>(
      tooltip: Strings.gameMenuTooltip,
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
          case _MenuAction.clearWord:
            cubit.clearWord();
          case _MenuAction.restart:
            _confirmRestart(context, cubit);
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<_MenuAction>>[
        PopupMenuItem(
          value: _MenuAction.checkWord,
          child: Text(Strings.checkWordAction),
        ),
        PopupMenuItem(
          value: _MenuAction.checkPuzzle,
          child: Text(Strings.checkPuzzleAction),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.revealLetter,
          child: Text(Strings.revealLetterAction),
        ),
        PopupMenuItem(
          value: _MenuAction.revealWord,
          child: Text(Strings.revealWordAction),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.clearWord,
          child: Text(Strings.clearWordAction),
        ),
        PopupMenuItem(
          value: _MenuAction.restart,
          child: Text(Strings.restartAction),
        ),
      ],
    );
  }

  /// Restart is destructive, so it confirms first. View-local dialog flow,
  /// matching how screens push routes directly from buttons.
  Future<void> _confirmRestart(
    BuildContext context,
    CrosswordCubit cubit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.restartConfirmTitle),
        content: const Text(Strings.restartConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(Strings.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(Strings.restartAction),
          ),
        ],
      ),
    );
    if (confirmed == true) cubit.restartPuzzle();
  }
}
