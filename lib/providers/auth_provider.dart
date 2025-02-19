import 'package:dtx/models/auth_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  String get fullPhoneNumber => '+91${state.unverifiedPhone}';

  Future<bool> verifyPhone(String phone) async {
    // Clear previous errors
    state = state.copyWith(error: null, isLoading: true);

    // Core validation
    if (phone.isEmpty) {
      state = state.copyWith(
        error: "Phone number can't be empty",
        isLoading: false,
      );
      return false;
    }

    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
      state = state.copyWith(
        error: "Please enter a valid Indian phone number",
        isLoading: false,
      );
      return false;
    }

    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Update state with validated phone
    state = state.copyWith(
      unverifiedPhone: phone,
      isLoading: false,
      error: null,
    );

    return true;
  }

  void clearState() {
    state = const AuthState();
  }
}
