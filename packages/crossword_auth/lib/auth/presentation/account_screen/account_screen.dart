import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_ui/crossword_ui.dart';

import '../../common/strings/auth_strings.dart';
import '../../domain/services/auth_service.dart';
import 'cubit/account_cubit.dart';
import 'cubit/account_state.dart';

class AccountScreen extends StatelessWidget {
  final AuthService authService;

  const AccountScreen({required this.authService, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AccountCubit(authService: authService),
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
            ..showSnackBar(SnackBar(content: Text(state.message)));
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
    final email = state.user?.email ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AuthStrings.accountTitle, style: AppTextStyles.appBarTitle()),
        centerTitle: true,
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AuthStrings.signedInAs, style: AppTextStyles.clue(14)),
              const SizedBox(height: 4),
              Text(email, style: AppTextStyles.clue(18)),
              const Spacer(),
              FilledButton(
                onPressed: () => _confirmSignOut(context, cubit),
                child: const Text(AuthStrings.signOutAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AccountCubit cubit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AuthStrings.signOutConfirmTitle),
        content: const Text(AuthStrings.signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(Strings.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AuthStrings.signOutAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await cubit.signOut();
    }
  }
}
