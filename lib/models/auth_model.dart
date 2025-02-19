// lib/core/models/auth_state.dart

class AuthState {
  final String? unverifiedPhone;
  final String? verificationId;
  final bool isLoading;
  final String? error;
  final int? resendTimer;

  const AuthState({
    this.unverifiedPhone,
    this.verificationId,
    this.isLoading = false,
    this.error,
    this.resendTimer,
  });

  AuthState copyWith({
    String? unverifiedPhone,
    String? verificationId,
    bool? isLoading,
    String? error,
    int? resendTimer,
  }) {
    return AuthState(
      unverifiedPhone: unverifiedPhone ?? this.unverifiedPhone,
      verificationId: verificationId ?? this.verificationId,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Intentionally not using ?? operator
      resendTimer: resendTimer ?? this.resendTimer,
    );
  }
}
