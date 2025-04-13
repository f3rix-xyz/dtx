// File: providers/received_likes_provider.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/repositories/like_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// State definition
class ReceivedLikesState {
  final bool isLoading;
  final List<FullProfileLiker> fullProfiles;
  final List<BasicProfileLiker> otherLikers;
  final AppError? error;

  const ReceivedLikesState({
    this.isLoading = true, // Start in loading state
    this.fullProfiles = const [],
    this.otherLikers = const [],
    this.error,
  });

  ReceivedLikesState copyWith({
    bool? isLoading,
    List<FullProfileLiker>? fullProfiles,
    List<BasicProfileLiker>? otherLikers,
    AppError? Function()? error, // Function to allow setting null
  }) {
    return ReceivedLikesState(
      isLoading: isLoading ?? this.isLoading,
      fullProfiles: fullProfiles ?? this.fullProfiles,
      otherLikers: otherLikers ?? this.otherLikers,
      error: error != null ? error() : this.error,
    );
  }
}

// StateNotifier definition
class ReceivedLikesNotifier extends StateNotifier<ReceivedLikesState> {
  final LikeRepository _likeRepository;

  ReceivedLikesNotifier(this._likeRepository)
      : super(const ReceivedLikesState());

  Future<void> fetchLikes() async {
    print("[ReceivedLikesNotifier] fetchLikes called.");
    // Don't reset lists here, only on success/initial load
    state = state.copyWith(isLoading: true, error: () => null);
    try {
      final result = await _likeRepository.fetchReceivedLikes();
      final fullProfiles = result['full'] as List<FullProfileLiker>? ?? [];
      final otherLikers = result['other'] as List<BasicProfileLiker>? ?? [];
      print(
          "[ReceivedLikesNotifier] fetchLikes success. Full: ${fullProfiles.length}, Other: ${otherLikers.length}");
      state = state.copyWith(
        isLoading: false,
        fullProfiles: fullProfiles,
        otherLikers: otherLikers,
        error: () => null,
      );
    } on ApiException catch (e) {
      print("[ReceivedLikesNotifier] fetchLikes API Exception: ${e.message}");
      state = state.copyWith(
          isLoading: false, error: () => AppError.server(e.message));
    } catch (e) {
      print(
          "[ReceivedLikesNotifier] fetchLikes Unexpected Error: ${e.toString()}");
      state = state.copyWith(
          isLoading: false,
          error: () => AppError.generic("Failed to load likes."));
    }
  }
}

// Provider definition
final receivedLikesProvider =
    StateNotifierProvider<ReceivedLikesNotifier, ReceivedLikesState>((ref) {
  final likeRepository = ref.watch(likeRepositoryProvider);
  return ReceivedLikesNotifier(likeRepository);
});
