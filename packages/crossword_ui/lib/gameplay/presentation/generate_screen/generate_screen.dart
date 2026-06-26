import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';

import '../../../common/data/constants/app_colors.dart';
import '../../../common/presentation/widgets/brand_app_bar.dart';
import '../../../l10n/gen/crossword_ui_l10n.dart';
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
    // Resolve the localized default title here (a normal build context that
    // may listen), not in the `create` callback below — `Localizations.of`
    // depends on an InheritedWidget and must not run in that one-shot lifecycle.
    final generatedPuzzleTitle = CrosswordUiL10n.of(context).generatedPuzzleTitle;
    return BlocProvider(
      create: (_) => GeneratePuzzleCubit(
        service: context.read<PuzzleGenerationService>(),
        generatedPuzzleTitle: generatedPuzzleTitle,
      ),
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
            ..showSnackBar(
              SnackBar(
                content: Text(
                  CrosswordUiL10n.of(context).generationErrorMessage,
                ),
              ),
            );
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
    final l10n = CrosswordUiL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandAppBar(title: l10n.generateTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.generateLanguageLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l10n.generateLanguageSwedish),
                    selected: state.languageCode == 'sv',
                    onSelected: state.isGenerating
                        ? null
                        : (_) => cubit.selectLanguage('sv'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(l10n.generateSizeLabel),
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
              Text(l10n.generateMaxWordLenLabel),
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
              _LabeledStepper(
                label: l10n.generateMaxSecondsLabel,
                value: state.maxSeconds,
                enabled: !state.isGenerating,
                onDecrement: cubit.decrementMaxSeconds,
                onIncrement: cubit.incrementMaxSeconds,
              ),
              const SizedBox(height: 16),
              _LabeledStepper(
                label: l10n.generatePictureColsLabel,
                value: state.pictureCols,
                enabled: !state.isGenerating,
                onDecrement: cubit.decrementPictureCols,
                onIncrement: cubit.incrementPictureCols,
              ),
              const SizedBox(height: 16),
              _LabeledStepper(
                label: l10n.generatePictureRowsLabel,
                value: state.pictureRows,
                enabled: !state.isGenerating,
                onDecrement: cubit.decrementPictureRows,
                onIncrement: cubit.incrementPictureRows,
              ),
              const SizedBox(height: 24),
              Text(l10n.generateSeedWordsLabel),
              const SizedBox(height: 8),
              TextField(
                controller: cubit.seedWordsController,
                enabled: !state.isGenerating,
                decoration: InputDecoration(
                  hintText: l10n.generateSeedWordsHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Text(l10n.generateRandomSeedLabel),
              const SizedBox(height: 8),
              TextField(
                controller: cubit.randomSeedController,
                enabled: !state.isGenerating,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.generateRandomSeedHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state.isGenerating ? null : cubit.generate,
                  child: Text(
                    state.isGenerating
                        ? l10n.generatingLabel
                        : l10n.generateAction,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed:
                      state.isGenerating ? null : cubit.openTestPuzzle,
                  child: Text(l10n.generateTestPuzzleAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label with `−`/`+` buttons around a current numeric [value]. Buttons are
/// disabled when [enabled] is false or when the corresponding callback is null.
class _LabeledStepper extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final bool enabled;

  const _LabeledStepper({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            IconButton(
              onPressed: enabled ? onDecrement : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: enabled ? onIncrement : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
