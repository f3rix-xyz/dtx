// File: models/auth_model.dart
enum AuthStatus {
  home,       // User authenticated with complete profile
  onboarding, // User authenticated but profile incomplete
  login,      // User not authenticated or invalid token
  unknown     // Error or initial state
}

class AuthState {
  final String? unverifiedPhone;
  final String? verificationId;
  final bool isLoading;
  final String? error;
  final int? resendTimer;
  final String? jwtToken;
  final AuthStatus authStatus;

  const AuthState({
    this.unverifiedPhone,
    this.verificationId,
    this.isLoading = false,
    this.error,
    this.resendTimer,
    this.jwtToken,
    this.authStatus = AuthStatus.unknown,
  });

  AuthState copyWith({
    String? Function()? unverifiedPhone,
    String? Function()? verificationId,
    bool? isLoading,
    String? Function()? error,
    int? Function()? resendTimer,
    String? Function()? jwtToken,
    AuthStatus? authStatus,
  }) {
    return AuthState(
      unverifiedPhone:
          unverifiedPhone != null ? unverifiedPhone() : this.unverifiedPhone,
      verificationId:
          verificationId != null ? verificationId() : this.verificationId,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      resendTimer: resendTimer != null ? resendTimer() : this.resendTimer,
      jwtToken: jwtToken != null ? jwtToken() : this.jwtToken,
      authStatus: authStatus ?? this.authStatus,
    );
  }
  
  // Check if user is authenticated
  bool get isAuthenticated => jwtToken != null && jwtToken!.isNotEmpty;
}
