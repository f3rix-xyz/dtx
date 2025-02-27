// File: providers/auth_provider.dart
import 'package:dtx/models/auth_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/error_model.dart';
import '../repositories/auth_repository.dart';
import '../services/api_service.dart';
import '../utils/token_storage.dart';
import 'error_provider.dart';
import 'service_provider.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(ref, authRepository);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  final AuthRepository _authRepository;
  int _lastRequestId = 0;
  static final _phoneRegex = RegExp(r'^[6-9][0-9]{9}$');

  AuthNotifier(this.ref, this._authRepository) : super(const AuthState()) {
    // Try to load token on initialization
    _loadToken();
  }
  
  // Load token from storage if it exists
  Future<void> _loadToken() async {
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      state = state.copyWith(jwtToken: () => token);
    }
  }
  
  // Check authentication status
Future<AuthStatus> checkAuthStatus({bool updateState = true}) async {
  try {
    if (updateState) {
      state = state.copyWith(isLoading: true);
    }

    // Get token (either from state or storage)
    String? token = state.jwtToken;
    if (token == null || token.isEmpty) {
      token = await TokenStorage.getToken();
    }

    // Check auth status via repository
    final authStatus = await _authRepository.checkAuthStatus(token);

    if (updateState) {
      state = state.copyWith(
        isLoading: false,
        authStatus: authStatus,
      );
    }
    
    return authStatus;
  } catch (e) {
    if (updateState) {
      state = state.copyWith(
        isLoading: false,
        authStatus: AuthStatus.login,
      );
    }
    return AuthStatus.login;
  }
}

  Future<bool> verifyPhone(String phone) async {
    final requestId = ++_lastRequestId;

    state = state.copyWith(
      isLoading: true,
      unverifiedPhone: () => null,
    );

    // Clear any existing errors first
    ref.read(errorProvider.notifier).clearError();

    if (phone.isEmpty) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Phone number can't be empty"),
          );
      state = state.copyWith(isLoading: false);
      return false;
    }

    if (!_phoneRegex.hasMatch(phone)) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Please enter a valid Indian phone number"),
          );
      state = state.copyWith(isLoading: false);
      return false;
    }

    // Clear error on successful verification
    ref.read(errorProvider.notifier).clearError();

    state = state.copyWith(
      unverifiedPhone: () => phone,
      isLoading: false,
    );
    return true;
  }
  
  // Send OTP to the user's phone
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      state = state.copyWith(isLoading: true);
      
      final success = await _authRepository.sendOtp(phoneNumber);
      
      state = state.copyWith(
        isLoading: false, 
        unverifiedPhone: () => success ? phoneNumber : null,
      );
      
      if (!success) {
        ref.read(errorProvider.notifier).setError(
          AppError.auth("Failed to send OTP. Please try again."),
        );
      }
      
      return success;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false);
      ref.read(errorProvider.notifier).setError(
        AppError.auth(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      ref.read(errorProvider.notifier).setError(
        AppError.auth("An unexpected error occurred. Please try again."),
      );
      return false;
    }
  }
  
  // Verify OTP entered by user
  Future<bool> verifyOtp(String phoneNumber, String otpCode) async {
    try {
      state = state.copyWith(isLoading: true);
      
      final token = await _authRepository.verifyOtp(phoneNumber, otpCode);
      
      // Save token to secure storage
      await TokenStorage.saveToken(token);
      
      state = state.copyWith(
        isLoading: false,
        jwtToken: () => token,
      );
      
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false);
      ref.read(errorProvider.notifier).setError(
        AppError.auth(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      ref.read(errorProvider.notifier).setError(
        AppError.auth("An unexpected error occurred. Please try again."),
      );
      return false;
    }
  }
  
  // Logout user
  Future<void> logout() async {
    await TokenStorage.removeToken();
    state = const AuthState();
  }
}
