// File: repositories/auth_status_repository.dart
import '../services/api_service.dart';
import '../utils/token_storage.dart';

enum AuthStatus {
  home,       // User authenticated with complete profile
  onboarding, // User authenticated but profile incomplete
  login,      // User not authenticated or invalid token
  unknown     // Error or initial state
}

class AuthStatusRepository {
  final ApiService _apiService;
  
  AuthStatusRepository(this._apiService);
  
  Future<AuthStatus> checkAuthStatus() async {
    try {
      // Get the saved token
      final token = await TokenStorage.getToken();
      
      if (token == null || token.isEmpty) {
        return AuthStatus.login;
      }
      
      // Create auth headers
      final headers = {
        'Authorization': 'Bearer $token',
      };
      
      // Make the API request
      final response = await _apiService.get(
        '/api/auth-status',
        headers: headers,
      );
      
      if (response['success'] == true) {
        final status = response['status']?.toString().toLowerCase();
        
        if (status == 'home') {
          return AuthStatus.home;
        } else if (status == 'onboarding') {
          return AuthStatus.onboarding;
        }
      }
      
      // Default to login if status is not recognized or success is false
      return AuthStatus.login;
    } on ApiException catch (e) {
      print('Auth status check failed: $e');
      // For authentication errors, redirect to login
      return AuthStatus.login;
    } catch (e) {
      print('Unexpected error during auth status check: $e');
      return AuthStatus.unknown;
    }
  }
}
