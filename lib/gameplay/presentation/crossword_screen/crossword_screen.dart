import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      appBar: AppBar(
        title: const Text('Korsord'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: CrosswordGrid(state: state),
            ),
          ),
        ),
      ),
    );
  }
}
