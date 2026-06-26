import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/auth_failure.dart';
import '../../../domain/services/auth_service.dart';
import 'account_state.dart';

class AccountCubit extends Cubit<AccountState> {
  final AuthService _authService;

  AccountCubit({required AuthService authService})
      : _authService = authService,
        super(AccountState(user: authService.currentUser.value));

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      emit(AccountSignedOut(state: state));
    } on AuthFailure {
      emit(AccountSignOutError(state: state));
    }
  }
}
