// File: repositories/auth_repository.dart
import '../models/auth_model.dart';
import '../services/api_service.dart';

class AuthRepository {
  final ApiService _apiService;
  
  AuthRepository(this._apiService);
  
  // Send OTP to the provided phone number
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      final response = await _apiService.post(
        '/api/send-otp',
        body: {'phoneNumber': phoneNumber},
      );
      
      return response['success'] == true;
    } on ApiException catch (e) {
      // Re-throw as repository exception or handle differently
      throw e;
    }
  }
  
  // Verify OTP and get JWT token
  Future<String> verifyOtp(String phoneNumber, String otpCode) async {
    try {
      final response = await _apiService.post(
        '/api/verify-otp',
        body: {
          'phoneNumber': phoneNumber,
          'otpCode': otpCode,
        },
      );
      
      if (response['success'] == true && response['token'] != null) {
        return response['token'].toString();
      } else {
        throw ApiException('Failed to verify OTP: No token received');
      }
    } on ApiException catch (e) {
      // Re-throw as repository exception or handle differently
      throw e;
    }
  }
  
  // Check authentication status
  Future<AuthStatus> checkAuthStatus(String? token) async {
    if (token == null || token.isEmpty) {
      return AuthStatus.login;
    }
    
    try {
      final headers = {
        'Authorization': 'Bearer $token',
      };
      
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
    } on ApiException {
      // For authentication errors, redirect to login
      return AuthStatus.login;
    } catch (e) {
      print('Unexpected error during auth status check: $e');
      return AuthStatus.unknown;
    }
  }
}
