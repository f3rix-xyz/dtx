// File: providers/service_provider.dart
import 'package:dtx/repositories/filter_repository.dart';
import 'package:dtx/repositories/user_repository.dart';
import 'package:dtx/repositories/media_repository.dart';
import 'package:dtx/repositories/like_repository.dart'; // *** ADDED Import ***
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

// Media Repository provider
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return MediaRepository(apiService, ref);
});

// User Repository provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return UserRepository(apiService);
});

// *** ADDED: Like Repository Provider ***
final likeRepositoryProvider = Provider<LikeRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return LikeRepository(apiService);
});

final filterRepositoryProvider = Provider<FilterRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return FilterRepository(apiService);
});
// *** END ADDED ***
