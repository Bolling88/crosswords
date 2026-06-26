import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_ui/crossword_ui.dart';

import '../../../l10n/gen/crossword_auth_l10n.dart';
import '../../domain/services/auth_service.dart';
import 'cubit/account_cubit.dart';
import 'cubit/account_state.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AccountCubit(authService: context.read<AuthService>()),
      child: const AccountScreenBuilder(),
    );
  }
}

class AccountScreenBuilder extends StatelessWidget {
  const AccountScreenBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountCubit, AccountState>(
      listenWhen: (_, state) =>
          state is AccountSignedOut || state is AccountSignOutError,
      listener: (context, state) {
        if (state is AccountSignedOut) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (state is AccountSignOutError) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(CrosswordAuthL10n.of(context).errorGeneric),
              ),
            );
        }
      },
      builder: (context, state) => AccountScreenContent(state: state),
    );
  }
}

class AccountScreenContent extends StatelessWidget {
  final AccountState state;

  const AccountScreenContent({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountCubit>();
    final l10n = CrosswordAuthL10n.of(context);
    final email = state.user?.email ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandAppBar(title: l10n.accountTitle),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.signedInAs, style: AppTextStyles.clue(14)),
              const SizedBox(height: 4),
              Text(email, style: AppTextStyles.clue(18)),
              const Spacer(),
              FilledButton(
                onPressed: () => _confirmSignOut(context, cubit),
                child: Text(l10n.signOutAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AccountCubit cubit) async {
    final l10n = CrosswordAuthL10n.of(context);
    final uiL10n = CrosswordUiL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(uiL10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.signOutAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await cubit.signOut();
    }
  }
}
