// File: repositories/auth_repository.dart
import '../models/auth_model.dart'; // Keep for AuthStatus enum
import '../services/api_service.dart';

class AuthRepository {
  final ApiService _apiService;

  AuthRepository(this._apiService);

  // --- REMOVED METHODS ---
  // Future<bool> sendOtp(String phoneNumber) async { ... }
  // Future<String> verifyOtp(String phoneNumber, String otpCode) async { ... }
  // --- END REMOVED METHODS ---

  // --- NEW METHOD ---
  /// Verifies Google Access Token with the backend and returns the App JWT.
  Future<String> verifyGoogleToken(String googleAccessToken) async {
    final String methodName = 'verifyGoogleToken';
    print('[AuthRepository $methodName] Verifying Google token...');
    try {
      final response = await _apiService.post(
        '/api/auth/google/verify', // Endpoint from API documentation
        body: {'accessToken': googleAccessToken},
      );

      if (response['success'] == true && response['token'] != null) {
        print(
            '[AuthRepository $methodName] Google token verified, got App JWT.');
        return response['token'].toString();
      } else {
        final message = response['message']?.toString() ??
            'Verification failed, no token received.';
        print('[AuthRepository $methodName] Verification failed: $message');
        throw ApiException(
            message); // Throw with message from backend if available
      }
    } on ApiException catch (e) {
      print(
          '[AuthRepository $methodName] API Exception: ${e.message} (Status: ${e.statusCode})');
      // Re-throw API exceptions to be handled by the provider
      rethrow;
    } catch (e) {
      print('[AuthRepository $methodName] Unexpected Error: ${e.toString()}');
      // Wrap other errors in ApiException
      throw ApiException(
          'An unexpected error occurred during Google verification: ${e.toString()}');
    }
  }
  // --- END NEW METHOD ---

  // Check authentication status - Updated to handle new states
  Future<AuthStatus> checkAuthStatus(String? token) async {
    final String methodName = 'checkAuthStatus';
    print('[AuthRepository $methodName] Starting auth status check.');

    if (token == null || token.isEmpty) {
      print(
          '[AuthRepository $methodName] No token provided, returning login status.');
      return AuthStatus.login;
    }

    try {
      final headers = {'Authorization': 'Bearer $token'};
      print('[AuthRepository $methodName] Making request to /api/auth-status.');
      final response =
          await _apiService.get('/api/auth-status', headers: headers);

      print('[AuthRepository $methodName] Received response: $response');

      if (response['success'] == true && response['status'] != null) {
        final statusString = response['status'].toString().toLowerCase();
        switch (statusString) {
          case 'home':
            print('[AuthRepository $methodName] Status: home');
            return AuthStatus.home;
          case 'onboarding1': // Handle new state
            print('[AuthRepository $methodName] Status: onboarding1');
            return AuthStatus.onboarding1;
          case 'onboarding2': // Handle new state
            print('[AuthRepository $methodName] Status: onboarding2');
            return AuthStatus.onboarding2;
          default:
            // If backend returns an unexpected status, treat as login
            print(
                '[AuthRepository $methodName] Status: unknown ($statusString), defaulting to login.');
            return AuthStatus.login;
        }
      } else {
        // If success is false or status is missing, treat as login needed
        print(
            '[AuthRepository $methodName] API response indicates failure or missing status, returning login.');
        return AuthStatus.login;
      }
    } on ApiException catch (e) {
      // If API returns 401/403 or other errors indicating invalid session, treat as login needed
      print(
          '[AuthRepository $methodName] API Exception: ${e.message} (Status: ${e.statusCode}), returning login.');
      return AuthStatus.login;
    } catch (e) {
      print(
          '[AuthRepository $methodName] Unexpected Error: ${e.toString()}, returning unknown.');
      return AuthStatus.unknown; // Indicate an issue occurred during the check
    }
  }
}
