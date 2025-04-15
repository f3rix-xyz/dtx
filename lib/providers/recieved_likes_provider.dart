// File: providers/received_likes_provider.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/repositories/like_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// State definition remains the same
class ReceivedLikesState {
  final bool isLoading;
  final List<FullProfileLiker> fullProfiles;
  final List<BasicProfileLiker> otherLikers;
  final AppError? error;

  const ReceivedLikesState({
    this.isLoading = false, // Start NOT loading initially
    this.fullProfiles = const [],
    this.otherLikers = const [],
    this.error,
  });

  ReceivedLikesState copyWith({
    bool? isLoading,
    List<FullProfileLiker>? fullProfiles,
    List<BasicProfileLiker>? otherLikers,
    AppError? Function()? error,
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
    // Prevent concurrent fetches if already loading
    if (state.isLoading) {
      print("[ReceivedLikesNotifier] fetchLikes skipped, already loading.");
      return;
    }

    print("[ReceivedLikesNotifier] fetchLikes called. Setting isLoading=true.");
    state = state.copyWith(
        isLoading: true, error: () => null); // Set loading true *here*

    try {
      print(
          "[ReceivedLikesNotifier] Calling _likeRepository.fetchReceivedLikes()...");
      final result = await _likeRepository.fetchReceivedLikes();
      print(
          "[ReceivedLikesNotifier] Repository call finished. Result received.");

      // Ensure component is still mounted before modifying state
      if (!mounted) {
        print(
            "[ReceivedLikesNotifier] Component unmounted after fetch. Aborting state update.");
        return;
      }

      final fullProfiles = result['full'] as List<FullProfileLiker>? ?? [];
      final otherLikers = result['other'] as List<BasicProfileLiker>? ?? [];
      print(
          "[ReceivedLikesNotifier] fetchLikes success. Full: ${fullProfiles.length}, Other: ${otherLikers.length}. Setting isLoading=false.");

      state = state.copyWith(
        isLoading: false, // Set loading false on success
        fullProfiles: fullProfiles,
        otherLikers: otherLikers,
        error: () => null,
      );
    } on ApiException catch (e) {
      print(
          "[ReceivedLikesNotifier] fetchLikes API Exception: ${e.message}. Setting isLoading=false.");
      if (mounted) {
        state = state.copyWith(
            isLoading: false, // Set loading false on error
            error: () => AppError.server(e.message));
      } else {
        print(
            "[ReceivedLikesNotifier] Component unmounted after API exception.");
      }
    } catch (e, stacktrace) {
      // Catch generic errors and stacktrace
      print(
          "[ReceivedLikesNotifier] fetchLikes Unexpected Error: ${e.toString()}. Setting isLoading=false.");
      print(
          "[ReceivedLikesNotifier] Stacktrace: $stacktrace"); // Log stacktrace
      if (mounted) {
        state = state.copyWith(
            isLoading: false, // Set loading false on error
            error: () => AppError.generic("Failed to load likes."));
      } else {
        print(
            "[ReceivedLikesNotifier] Component unmounted after unexpected error.");
      }
    }
    // Removed finally block as isLoading=false is handled in try/catch
  }
}

// Provider definition
final receivedLikesProvider =
    StateNotifierProvider<ReceivedLikesNotifier, ReceivedLikesState>((ref) {
  final likeRepository = ref.watch(likeRepositoryProvider);
  return ReceivedLikesNotifier(likeRepository);
});
