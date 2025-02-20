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
    String? Function()? unverifiedPhone,
    String? Function()? verificationId,
    bool? isLoading,
    String? Function()? error,
    int? Function()? resendTimer,
  }) {
    return AuthState(
      unverifiedPhone:
          unverifiedPhone != null ? unverifiedPhone() : this.unverifiedPhone,
      verificationId:
          verificationId != null ? verificationId() : this.verificationId,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      resendTimer: resendTimer != null ? resendTimer() : this.resendTimer,
    );
  }
}
