import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/font_service.dart';
import '../../domain/services/gameplay_settings_service.dart';
import '../../../common/data/constants/app_colors.dart';
import '../../../common/data/constants/app_text_styles.dart';
import '../../../common/presentation/widgets/brand_app_bar.dart';
import '../../../l10n/gen/crossword_ui_l10n.dart';

import 'cubit/settings_cubit.dart';
import 'cubit/settings_state.dart';
import 'widgets/font_option_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsCubit(
        fontService: context.read<FontService>(),
        settingsService: context.read<GameplaySettingsService>(),
      ),
      child: const SettingsScreenBuilder(),
    );
  }
}

class SettingsScreenBuilder extends StatelessWidget {
  const SettingsScreenBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => SettingsScreenContent(state: state),
    );
  }
}

class SettingsScreenContent extends StatelessWidget {
  final SettingsState state;

  const SettingsScreenContent({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    final l10n = CrosswordUiL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandAppBar(title: l10n.settingsTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.fontSettingLabel,
                  style: AppTextStyles.clue(16),
                ),
              ),
              for (final font in state.fonts)
                FontOptionTile(
                  font: font,
                  isSelected: font == state.selectedFont,
                  onTap: () => cubit.selectFont(font),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  l10n.gameplaySettingLabel,
                  style: AppTextStyles.clue(16),
                ),
              ),
              SwitchListTile(
                title: Text(l10n.autocheckLabel),
                subtitle: Text(l10n.autocheckDescription),
                value: state.autocheck,
                onChanged: cubit.setAutocheck,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
