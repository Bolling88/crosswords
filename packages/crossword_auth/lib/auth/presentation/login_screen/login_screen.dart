import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_ui/crossword_ui.dart';

import '../../common/strings/auth_strings.dart';
import '../../domain/services/auth_service.dart';
import 'cubit/login_cubit.dart';
import 'cubit/login_state.dart';

/// Provides the [LoginCubit]. Built standalone by [AuthGate] when signed out.
class LoginScreen extends StatelessWidget {
  final AuthService authService;

  const LoginScreen({required this.authService, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(authService: authService),
      child: const LoginScreenBuilder(),
    );
  }
}

class LoginScreenBuilder extends StatelessWidget {
  const LoginScreenBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginCubit, LoginState>(
      listenWhen: (_, state) =>
          state is LoginError || state is LoginPasswordResetSent,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state is LoginError) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is LoginPasswordResetSent) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text(AuthStrings.resetSent)));
        }
      },
      builder: (context, state) => LoginScreenContent(state: state),
    );
  }
}

class LoginScreenContent extends StatelessWidget {
  final LoginState state;

  const LoginScreenContent({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    final isRegister = state.mode == LoginMode.register;
    final title =
        isRegister ? AuthStrings.registerTitle : AuthStrings.signInTitle;
    final primaryLabel =
        isRegister ? AuthStrings.registerAction : AuthStrings.signInAction;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('login_email'),
                    controller: cubit.emailController,
                    focusNode: cubit.emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enabled: !state.isSubmitting,
                    decoration: const InputDecoration(
                      labelText: AuthStrings.emailLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('login_password'),
                    controller: cubit.passwordController,
                    focusNode: cubit.passwordFocus,
                    obscureText: true,
                    enabled: !state.isSubmitting,
                    decoration: const InputDecoration(
                      labelText: AuthStrings.passwordLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (!isRegister) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            state.isSubmitting ? null : cubit.sendPasswordReset,
                        child: const Text(AuthStrings.forgotPassword),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 12),
                  const SizedBox(height: 4),
                  FilledButton(
                    key: const Key('login_submit'),
                    onPressed: state.isSubmitting ? null : cubit.submit,
                    child: state.isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(primaryLabel),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: state.isSubmitting ? null : cubit.toggleMode,
                    child: Text(
                      isRegister
                          ? AuthStrings.toggleToSignIn
                          : AuthStrings.toggleToRegister,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _OrDivider(),
                  const SizedBox(height: 16),
                  _SocialButton(
                    label: AuthStrings.continueWithGoogle,
                    onPressed:
                        state.isSubmitting ? null : cubit.signInWithGoogle,
                  ),
                  const SizedBox(height: 12),
                  _SocialButton(
                    label: AuthStrings.continueWithApple,
                    onPressed: state.isSubmitting ? null : cubit.signInWithApple,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.gridLine)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            AuthStrings.socialDivider,
            style: TextStyle(color: AppColors.inkMuted),
          ),
        ),
        Expanded(child: Divider(color: AppColors.gridLine)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _SocialButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.gridLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}
