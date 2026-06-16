import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/font_service.dart';
import '../../domain/services/gameplay_settings_service.dart';
import '../../../common/data/constants/app_colors.dart';
import '../../../common/data/constants/app_text_styles.dart';
import '../../../common/data/constants/strings.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(Strings.settingsTitle, style: AppTextStyles.appBarTitle()),
        centerTitle: true,
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  Strings.fontSettingLabel,
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
                  Strings.gameplaySettingLabel,
                  style: AppTextStyles.clue(16),
                ),
              ),
              SwitchListTile(
                title: const Text(Strings.autocheckLabel),
                subtitle: const Text(Strings.autocheckDescription),
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
