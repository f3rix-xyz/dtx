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
  final String methodName = 'checkAuthStatus';
  print('[${DateTime.now()}] $methodName - Starting auth status check');
  
  if (token == null || token.isEmpty) {
    print('[${DateTime.now()}] $methodName - No token found, redirecting to login');
    return AuthStatus.login;
  }

  try {
    // Sanitize token for logging (show first 4 and last 4 chars)
    final sanitizedToken = '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
    print('[${DateTime.now()}] $methodName - Using token: $sanitizedToken');
    
    final headers = {
      'Authorization': 'Bearer $token',
    };
    
    print('[${DateTime.now()}] $methodName - Making request to /api/auth-status');
    print('[${DateTime.now()}] $methodName - Headers: ${headers.keys.join(', ')}');
    
    final response = await _apiService.get(
      '/api/auth-status',
      headers: headers,
    );
    
    print('[${DateTime.now()}] $methodName - Received response:');
    print('  Status Code: ${response['statusCode'] ?? 'Unknown'}');
    print('  Success: ${response['success']}');
    print('  Status: ${response['status']}');
    print('  Message: ${response['message']}');

    if (response['success'] == true) {
      final status = response['status']?.toString().toLowerCase();
      
      switch (status) {
        case 'home':
          print('[${DateTime.now()}] $methodName - Valid home status received');
          return AuthStatus.home;
        case 'onboarding':
          print('[${DateTime.now()}] $methodName - Profile incomplete, redirecting to onboarding');
          return AuthStatus.onboarding;
        default:
          print('[${DateTime.now()}] $methodName - Unrecognized status: $status');
          print('[${DateTime.now()}] $methodName - Defaulting to login');
          return AuthStatus.login;
      }
    }
    
    print('[${DateTime.now()}] $methodName - API response indicates failure');
    print('[${DateTime.now()}] $methodName - Full response: $response');
    return AuthStatus.login;

  } on ApiException catch (e, stack) {
    print('[${DateTime.now()}] $methodName - API Exception occurred:');
    print('  Error Type: ${e.runtimeType}');
    print('  Message: ${e.message}');
    print('  Status Code: ${e.statusCode}');
    print('  Stack Trace: $stack');
    return AuthStatus.login;
    
  } catch (e, stack) {
    print('[${DateTime.now()}] $methodName - Unexpected error occurred:');
    print('  Error Type: ${e.runtimeType}');
    print('  Message: $e');
    print('  Stack Trace: $stack');
    return AuthStatus.unknown;
  }
}


}
