// File: providers/auth_provider.dart
import 'package:dtx/models/auth_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Import Google Sign-In
import '../models/error_model.dart';
import '../repositories/auth_repository.dart';
import '../services/api_service.dart';
import '../utils/token_storage.dart';
import 'error_provider.dart';
import 'service_provider.dart';

// Provider for GoogleSignIn instance
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    // Add scopes if needed beyond basic profile/email, e.g., for YouTube later
    // scopes: ['email', 'profile', 'https://www.googleapis.com/auth/youtube.readonly'],
    scopes: ['email', 'profile'], // Basic scopes for login
  );
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  // No longer need _lastRequestId or _phoneRegex
  return AuthNotifier(ref, authRepository);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  final AuthRepository _authRepository;
  // Removed: int _lastRequestId = 0;
  // Removed: static final _phoneRegex = RegExp(r'^[6-9][0-9]{9}$');

  AuthNotifier(this.ref, this._authRepository) : super(const AuthState()) {
    _loadTokenAndCheckStatus(); // Check status upon initialization
  }

  // Combined load and check
  Future<void> _loadTokenAndCheckStatus() async {
    print('[AuthNotifier] Loading token and checking initial status...');
    state = state.copyWith(isLoading: true);
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      state = state.copyWith(jwtToken: () => token);
      await checkAuthStatus(updateState: true); // Check status if token exists
    } else {
      print('[AuthNotifier] No token found, setting state to login.');
      // If no token, status is definitely login
      state = state.copyWith(
          isLoading: false, authStatus: AuthStatus.login, jwtToken: () => null);
    }
  }

  /// Checks the current authentication status with the backend.
  /// Updates the provider's state if `updateState` is true.
  Future<AuthStatus> checkAuthStatus({bool updateState = true}) async {
    print('[AuthNotifier checkAuthStatus] Called. updateState: $updateState');
    if (updateState) {
      state = state.copyWith(isLoading: true, error: () => null);
    }

    final token =
        state.jwtToken ?? await TokenStorage.getToken(); // Check state first

    try {
      final backendStatus = await _authRepository.checkAuthStatus(token);
      print(
          '[AuthNotifier checkAuthStatus] Backend status received: $backendStatus');

      if (updateState) {
        state = state.copyWith(
          isLoading: false,
          authStatus: backendStatus,
          // Clear token in state if backend says login is required
          jwtToken: backendStatus == AuthStatus.login
              ? () => null
              : null, // Conditional null set
        );
        if (backendStatus == AuthStatus.login) {
          await TokenStorage.removeToken(); // Also remove from storage
        }
      }
      print(
          '[AuthNotifier checkAuthStatus] Finished. Returning: $backendStatus');
      return backendStatus;
    } catch (e) {
      print('[AuthNotifier checkAuthStatus] Error: $e');
      if (updateState) {
        state = state.copyWith(
          isLoading: false,
          authStatus: AuthStatus.login, // Default to login on error
          error: () => 'Failed to check status: ${e.toString()}',
          jwtToken: () => null, // Clear token on error
        );
        await TokenStorage.removeToken(); // Also remove from storage
      }
      return AuthStatus.login; // Return login on error
    }
  }

  // --- REMOVED METHODS ---
  // Future<bool> verifyPhone(String phone) async { ... }
  // Future<bool> sendOtp(String phoneNumber) async { ... }
  // Future<bool> verifyOtp(String phoneNumber, String otpCode) async { ... }
  // --- END REMOVED METHODS ---

  // --- NEW METHOD: Sign In With Google ---
  Future<AuthStatus> signInWithGoogle() async {
    print('[AuthNotifier signInWithGoogle] Attempting Google Sign-In...');
    state = state.copyWith(isLoading: true, error: () => null);
    ref.read(errorProvider.notifier).clearError(); // Clear previous errors

    try {
      final googleSignIn = ref.read(googleSignInProvider);
      final googleUser = await googleSignIn.signIn(); // Prompts user

      if (googleUser == null) {
        print('[AuthNotifier signInWithGoogle] User cancelled Google Sign-In.');
        state = state.copyWith(isLoading: false, authStatus: AuthStatus.login);
        return AuthStatus.login; // User cancelled
      }

      print(
          '[AuthNotifier signInWithGoogle] Google Sign-In successful for: ${googleUser.email}');
      final googleAuth = await googleUser.authentication;
      final googleAccessToken = googleAuth.accessToken;

      if (googleAccessToken == null) {
        print(
            '[AuthNotifier signInWithGoogle] Failed to get Google Access Token.');
        throw ApiException('Could not retrieve access token from Google.');
      }

      print(
          '[AuthNotifier signInWithGoogle] Verifying Google Access Token with backend...');
      final appJwt = await _authRepository.verifyGoogleToken(googleAccessToken);
      print(
          '[AuthNotifier signInWithGoogle] Backend verification successful. App JWT received.');

      await TokenStorage.saveToken(appJwt);

      // IMPORTANT: After successful login and getting the JWT,
      // immediately check the status with the backend to know the next step.
      state = state.copyWith(jwtToken: () => appJwt); // Temporarily set token
      final finalStatus = await checkAuthStatus(
          updateState: true); // Update state with final status

      print(
          '[AuthNotifier signInWithGoogle] Sign-in process complete. Final Status: $finalStatus');
      return finalStatus; // Return the status determined by checkAuthStatus
    } on ApiException catch (e) {
      print('[AuthNotifier signInWithGoogle] API Exception: ${e.message}');
      state = state.copyWith(
          isLoading: false,
          authStatus: AuthStatus.login,
          error: () => e.message);
      ref.read(errorProvider.notifier).setError(AppError.auth(e.message));
      await logout(); // Clear any potentially saved invalid token
      return AuthStatus.login;
    } catch (e) {
      print(
          '[AuthNotifier signInWithGoogle] Unexpected Error: ${e.toString()}');
      state = state.copyWith(
          isLoading: false,
          authStatus: AuthStatus.login,
          error: () => 'An unexpected error occurred during sign-in.');
      ref.read(errorProvider.notifier).setError(
          AppError.auth("An unexpected error occurred. Please try again."));
      await logout(); // Clear any potentially saved invalid token
      return AuthStatus.login;
    }
  }
  // --- END NEW METHOD ---

  // Logout user
  Future<void> logout() async {
    print('[AuthNotifier] Logging out...');
    try {
      final googleSignIn = ref.read(googleSignInProvider);
      await googleSignIn.signOut(); // Sign out from Google
      await googleSignIn.disconnect(); // Optional: Revoke permissions
    } catch (e) {
      print('[AuthNotifier] Error during Google Sign Out/Disconnect: $e');
      // Decide if you want to proceed with app logout even if Google logout fails
    } finally {
      await TokenStorage.removeToken(); // Remove app token *always*
      state =
          const AuthState(authStatus: AuthStatus.login); // Reset state *always*
      print('[AuthNotifier] Local logout complete.');
    }
  }
}
