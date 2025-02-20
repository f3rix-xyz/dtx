import 'package:dtx/models/auth_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/error_model.dart';
import 'error_provider.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  int _lastRequestId = 0;
  static final _phoneRegex = RegExp(r'^[6-9][0-9]{9}$');

  AuthNotifier(this.ref) : super(const AuthState());

  Future<bool> verifyPhone(String phone) async {
    final requestId = ++_lastRequestId;

    state = state.copyWith(
      isLoading: true,
      unverifiedPhone: () => null,
    );

    // Clear any existing errors first
    ref.read(errorProvider.notifier).clearError();

    if (phone.isEmpty) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Phone number can't be empty"),
          );
      state = state.copyWith(isLoading: false);
      return false;
    }

    if (!_phoneRegex.hasMatch(phone)) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Please enter a valid Indian phone number"),
          );
      state = state.copyWith(isLoading: false);
      return false;
    }

    // Clear error on successful verification
    ref.read(errorProvider.notifier).clearError();

    state = state.copyWith(
      unverifiedPhone: () => phone,
      isLoading: false,
    );
    return true;
  }
}
