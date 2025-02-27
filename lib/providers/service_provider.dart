
// File: providers/service_provider.dart
import 'package:dtx/models/media_upload_model.dart';
import 'package:dtx/repositories/media_repository.dart';
import 'package:dtx/repositories/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/http_service.dart';
import '../repositories/auth_repository.dart';
import '../utils/env_config.dart';

// API Service provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return HttpService(baseUrl: EnvConfig.apiBaseUrl);
});

// Auth Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AuthRepository(apiService);
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return MediaRepository(apiService, ref);  // Pass the ref here
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return UserRepository(apiService);
});
