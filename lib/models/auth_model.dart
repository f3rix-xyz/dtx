// File: models/auth_model.dart

// --- UPDATED ENUM ---
enum AuthStatus {
  login, // Needs to log in (no valid token or check failed)
  onboarding1, // Logged in, needs location/gender
  onboarding2, // Logged in, location/gender set, needs main profile details
  home, // Fully authenticated and onboarded
  unknown, // Initial state or error during status check
}
// --- END UPDATED ENUM ---

class AuthState {
  // --- REMOVED FIELDS ---
  // final String? unverifiedPhone;
  // final String? verificationId;
  // final int? resendTimer;
  // --- END REMOVED FIELDS ---

  final bool isLoading;
  final String? error; // Keep error for general auth errors
  final String? jwtToken;
  final AuthStatus authStatus;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.jwtToken,
    this.authStatus = AuthStatus.unknown, // Default to unknown
  });

  AuthState copyWith({
    bool? isLoading,
    String? Function()? error,
    String? Function()? jwtToken, // Function to allow setting null
    AuthStatus? authStatus,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      jwtToken: jwtToken != null ? jwtToken() : this.jwtToken,
      authStatus: authStatus ?? this.authStatus,
    );
  }

  // Check if user is considered authenticated (has a token)
  bool get isAuthenticated => jwtToken != null && jwtToken!.isNotEmpty;
}
