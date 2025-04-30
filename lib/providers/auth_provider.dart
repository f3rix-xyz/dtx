// File: providers/auth_provider.dart
import 'package:dtx/models/auth_model.dart';
import 'package:dtx/providers/feed_provider.dart';
import 'package:dtx/providers/filter_provider.dart';
import 'package:dtx/providers/matches_provider.dart';
import 'package:dtx/providers/recieved_likes_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/error_model.dart';
import '../repositories/auth_repository.dart';
import '../services/api_service.dart';
import '../utils/token_storage.dart';
import 'error_provider.dart';
import 'service_provider.dart'; // Ensure this is imported
import 'package:dtx/services/chat_service.dart'; // <<<--- ADD Import for ChatService

// Provider for GoogleSignIn instance (remains the same)
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: ['email', 'profile'],
  );
});

// AuthProvider definition
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  // *** Pass ref to the notifier ***
  return AuthNotifier(ref, authRepository); // <<<--- MODIFIED: Pass ref
});

class AuthNotifier extends StateNotifier<AuthState> {
  // *** Store the Ref object ***
  final Ref ref; // <<<--- ADDED: Store ref
  final AuthRepository _authRepository;

  // *** Modify constructor to accept Ref ***
  AuthNotifier(this.ref, this._authRepository) : super(const AuthState()) {
    // <<<--- MODIFIED: Accept ref
    _loadTokenAndCheckStatus();
  }

  // _loadTokenAndCheckStatus, checkAuthStatus, signInWithGoogle remain the same
  // ... (keep existing _loadTokenAndCheckStatus, checkAuthStatus, signInWithGoogle methods) ...
  Future<void> _loadTokenAndCheckStatus() async {
    print('[AuthNotifier] Loading token and checking initial status...');
    state = state.copyWith(isLoading: true);
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      print(
          '[AuthNotifier] Token found, setting in state and checking status.');
      state = state.copyWith(jwtToken: () => token);
      await checkAuthStatus(updateState: true); // Check status if token exists
    } else {
      print('[AuthNotifier] No token found, setting state to login.');
      // If no token, status is definitely login
      state = state.copyWith(
          isLoading: false, authStatus: AuthStatus.login, jwtToken: () => null);
    }
  }

  Future<AuthStatus> checkAuthStatus({bool updateState = true}) async {
    print('[AuthNotifier checkAuthStatus] Called. updateState: $updateState');
    if (updateState) {
      state = state.copyWith(isLoading: true, error: () => null);
    }

    // Use token from state if available, otherwise try storage
    final token = state.jwtToken ?? await TokenStorage.getToken();

    // If still no token, return login status immediately
    if (token == null || token.isEmpty) {
      print(
          '[AuthNotifier checkAuthStatus] No token available, returning login status.');
      if (updateState) {
        state = state.copyWith(
            isLoading: false,
            authStatus: AuthStatus.login,
            jwtToken: () => null);
      }
      return AuthStatus.login;
    }

    try {
      final backendStatus = await _authRepository.checkAuthStatus(token);
      print(
          '[AuthNotifier checkAuthStatus] Backend status received: $backendStatus');

      if (updateState) {
        state = state.copyWith(
          isLoading: false,
          authStatus: backendStatus,
          // Keep the token in state if status is not login
          // No need to clear token here unless backendStatus is login
          jwtToken: backendStatus == AuthStatus.login ? () => null : null,
        );
        if (backendStatus == AuthStatus.login) {
          print(
              '[AuthNotifier checkAuthStatus] Status is login, removing token from storage.');
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
        print(
            '[AuthNotifier checkAuthStatus] Error occurred, removing token from storage.');
        await TokenStorage.removeToken(); // Also remove from storage
      }
      return AuthStatus.login; // Return login on error
    }
  }

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
      print('[AuthNotifier signInWithGoogle] App JWT saved to storage.');

      // IMPORTANT: After successful login and getting the JWT,
      // immediately check the status with the backend to know the next step.
      state = state.copyWith(jwtToken: () => appJwt); // Set token in state
      print(
          '[AuthNotifier signInWithGoogle] JWT set in state. Checking auth status...');
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

  // Logout user
  Future<void> logout() async {
    print('[AuthNotifier] Logging out...');
    // final currentToken = state.jwtToken ?? await TokenStorage.getToken(); // Keep if needed for backend logout

    try {
      final googleSignIn = ref.read(googleSignInProvider);
      await googleSignIn.signOut(); // Sign out from Google
      await googleSignIn.disconnect().catchError((e) {
        print('[AuthNotifier] Non-critical error during Google disconnect: $e');
      });
    } catch (e) {
      print('[AuthNotifier] Error during Google Sign Out: $e');
    } finally {
      // Use finally to ensure cleanup happens

      // *** --- START: Call ChatService Disconnect --- ***
      try {
        print('[AuthNotifier] Attempting to disconnect ChatService...');
        // Access ChatService via the stored ref
        ref.read(chatServiceProvider).disconnect();
        print('[AuthNotifier] ChatService disconnect called.');
      } catch (e) {
        // Log error but don't prevent logout if ChatService interaction fails
        print(
            '[AuthNotifier] Error disconnecting ChatService (might not have been connected): $e');
      }
      // *** --- END: Call ChatService Disconnect --- ***

      await TokenStorage.removeToken();
      print('[AuthNotifier] Token removed from storage.');

      // Reset auth state *after* cleanup actions
      state = const AuthState(authStatus: AuthStatus.login);
      print('[AuthNotifier] Auth state reset to login.');

      // Invalidate other user-specific providers
      print('[AuthNotifier] Invalidating user-specific providers...');
      ref.invalidate(userProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(receivedLikesProvider);
      ref.invalidate(filterProvider);
      ref.invalidate(matchesProvider);
      // Add any other providers that store user-specific data here
      print('[AuthNotifier] Providers invalidated.');

      // Optional backend logout call (keep if you have it)
      // if (currentToken != null) { ... }

      print('[AuthNotifier] Local logout complete.');
    }
  }
}
