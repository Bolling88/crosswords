import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/auth_service.dart';
import '../login_screen/login_screen.dart';
import 'cubit/auth_gate_cubit.dart';
import 'cubit/auth_gate_state.dart';

/// Hard auth gate: renders [child] when signed in, otherwise the login screen.
class AuthGate extends StatelessWidget {
  final AuthService authService;
  final Widget child;

  const AuthGate({
    required this.authService,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthGateCubit(authService: authService),
      child: BlocBuilder<AuthGateCubit, AuthGateState>(
        builder: (context, state) {
          switch (state.status) {
            case AuthGateStatus.loading:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            case AuthGateStatus.unauthenticated:
              return LoginScreen(authService: authService);
            case AuthGateStatus.authenticated:
              return child;
          }
        },
      ),
    );
  }
}
