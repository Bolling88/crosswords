import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';

import '../../../common/data/constants/app_colors.dart';
import '../../../common/data/constants/strings.dart';
import '../../../common/presentation/widgets/brand_app_bar.dart';
import 'cubit/generate_cubit.dart';
import 'cubit/generate_state.dart';

/// Callback type used to build the gameplay screen once a puzzle is ready.
typedef GameplayBuilder = Widget Function(
  BuildContext context,
  CrosswordPuzzle puzzle,
);

/// Landing screen for generating a crossword puzzle.
///
/// Provides [GeneratePuzzleCubit] (reading [PuzzleGenerationService] from the
/// nearest [RepositoryProvider]) and delegates rendering to
/// [_GenerateScreenBuilder].
class GenerateScreen extends StatelessWidget {
  final GameplayBuilder gameplayBuilder;

  const GenerateScreen({
    required this.gameplayBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          GeneratePuzzleCubit(service: context.read<PuzzleGenerationService>()),
      child: _GenerateScreenBuilder(gameplayBuilder: gameplayBuilder),
    );
  }
}

/// Handles BlocConsumer logic: navigation on success, SnackBar on error.
class _GenerateScreenBuilder extends StatelessWidget {
  final GameplayBuilder gameplayBuilder;

  const _GenerateScreenBuilder({required this.gameplayBuilder});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GeneratePuzzleCubit, GenerateState>(
      listener: (context, state) {
        if (state is GenerationSucceeded) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => gameplayBuilder(context, state.puzzle),
            ),
          );
        } else if (state is ShowGenerationError) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) => _GenerateScreenContent(state: state),
    );
  }
}

/// Pure UI rendering from [GenerateState].
class _GenerateScreenContent extends StatelessWidget {
  final GenerateState state;

  const _GenerateScreenContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GeneratePuzzleCubit>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BrandAppBar(title: Strings.generateTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(Strings.generateSizeLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final size in GenerateState.sizePresets)
                    ChoiceChip(
                      label: Text('$size×$size'),
                      selected: state.width == size,
                      onSelected: state.isGenerating
                          ? null
                          : (_) => cubit.selectSize(size),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(Strings.generateMaxWordLenLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final len in GenerateState.maxWordLenPresets)
                    ChoiceChip(
                      label: Text('$len'),
                      selected: state.maxWordLen == len,
                      onSelected: state.isGenerating
                          ? null
                          : (_) => cubit.selectMaxWordLen(len),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(Strings.generateSeedWordsLabel),
              const SizedBox(height: 8),
              TextField(
                controller: cubit.seedWordsController,
                enabled: !state.isGenerating,
                decoration: const InputDecoration(
                  hintText: Strings.generateSeedWordsHint,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state.isGenerating ? null : cubit.generate,
                  child: state.isGenerating
                      ? const Text(Strings.generatingLabel)
                      : const Text(Strings.generateAction),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed:
                      state.isGenerating ? null : cubit.openTestPuzzle,
                  child: const Text(Strings.generateTestPuzzleAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
