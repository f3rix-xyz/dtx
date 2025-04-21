// File: providers/service_provider.dart
import 'package:dtx/repositories/filter_repository.dart';
import 'package:dtx/repositories/user_repository.dart';
import 'package:dtx/repositories/media_repository.dart';
import 'package:dtx/repositories/like_repository.dart';
// *** ADDED Imports ***
import 'package:dtx/repositories/match_repository.dart';
import 'package:dtx/repositories/chat_repository.dart';
import 'package:dtx/services/chat_service.dart'; // Import ChatService
// *** END ADDED Imports ***
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/http_service.dart';
import '../repositories/auth_repository.dart';
import '../utils/env_config.dart';

// API Service provider
final apiServiceProvider = Provider<ApiService>((ref) {
  // *** Determine WebSocket URL from HTTP Base URL ***
  final httpBaseUrl = EnvConfig.apiBaseUrl;
  // Simple replacement, adjust if your URLs differ more significantly
  final wsBaseUrl = httpBaseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://') +
      '/chat'; // Add the specific chat path
  print("[ServiceProvider] HTTP Base URL: $httpBaseUrl");
  print("[ServiceProvider] WS Base URL: $wsBaseUrl");
  // *** End Base URL Determination ***

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

// Like Repository Provider
final likeRepositoryProvider = Provider<LikeRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return LikeRepository(apiService);
});

// Filter Repository Provider
final filterRepositoryProvider = Provider<FilterRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return FilterRepository(apiService);
});

// *** ADDED: Match Repository Provider ***
final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return MatchRepository(apiService);
});
// *** END ADDED ***

// *** ADDED: Chat Repository Provider ***
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ChatRepository(apiService);
});
// *** END ADDED ***

// *** ADDED: Chat Service Provider (Singleton) ***
final chatServiceProvider = Provider<ChatService>((ref) {
  final httpBaseUrl = EnvConfig.apiBaseUrl;
  // Simple replacement, adjust if your URLs differ more significantly
  final wsBaseUrl = httpBaseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://') +
      '/chat'; // Add the specific chat path

  return ChatService(ref, wsBaseUrl);
});
// *** END ADDED ***
