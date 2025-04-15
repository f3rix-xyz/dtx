import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/user_model.dart'; // Use full UserModel
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/repositories/user_repository.dart';
import 'package:dtx/services/api_service.dart';
// Removed FeedType import
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Removed QuickFeedState ---

// --- Home Feed State ---
class HomeFeedState {
  final bool isLoading;
  final List<UserModel> profiles; // Use full UserModel for Home Feed
  final AppError? error;
  final bool hasFetchedOnce; // Track if initial fetch happened
  final bool hasMore; // Track if API indicates more profiles available

  const HomeFeedState({
    this.isLoading = false, // Start not loading until fetch is called
    this.profiles = const [],
    this.error,
    this.hasFetchedOnce = false,
    this.hasMore = true, // Assume more initially
  });

  HomeFeedState copyWith({
    bool? isLoading,
    List<UserModel>? profiles,
    AppError? Function()? error,
    bool? hasFetchedOnce,
    bool? hasMore,
  }) {
    return HomeFeedState(
      isLoading: isLoading ?? this.isLoading,
      profiles: profiles ?? this.profiles,
      error: error != null ? error() : this.error,
      hasFetchedOnce: hasFetchedOnce ?? this.hasFetchedOnce,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// --- Simplified Feed Notifier (Only Home Feed) ---
class FeedNotifier extends StateNotifier<HomeFeedState> {
  final UserRepository _userRepository;
  final Ref _ref;

  FeedNotifier(this._userRepository, this._ref) : super(const HomeFeedState());

  Future<void> fetchFeed({bool forceRefresh = false}) async {
    print("[FeedNotifier] fetchFeed called. forceRefresh: $forceRefresh");

    if (state.isLoading) {
      print("[FeedNotifier] Skipping fetch (already loading).");
      return;
    }
    // If already fetched and not forcing refresh, and we have profiles or know there are no more, skip
    if (state.hasFetchedOnce &&
        !forceRefresh &&
        (state.profiles.isNotEmpty || !state.hasMore)) {
      print(
          "[FeedNotifier] Skipping fetch (already fetched & no force required). Has Profiles: ${state.profiles.isNotEmpty}, Has More: ${state.hasMore}");
      return;
    }

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      // Directly fetch home feed profiles
      final result = await _userRepository
          .fetchHomeFeed(); // Assuming repo returns Map now
      final profiles = result['profiles'] as List<UserModel>;
      final hasMore =
          result['has_more'] as bool? ?? false; // Default to false if missing

      print(
          "[FeedNotifier] Fetched ${profiles.length} home profiles. Has More: $hasMore");
      if (!mounted) return;

      state = HomeFeedState(
        isLoading: false,
        profiles: profiles,
        error: null,
        hasFetchedOnce: true, // Mark as fetched
        hasMore: hasMore, // Update hasMore status
      );
    } on ApiException catch (e) {
      print("[FeedNotifier] API Exception: ${e.message}");
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: () => AppError.server(e.message),
        hasFetchedOnce:
            true, // Mark as fetched even on error to prevent reload loops
        hasMore: false, // Assume no more on error
      );
    } catch (e) {
      print("[FeedNotifier] Unexpected Error: ${e.toString()}");
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: () => AppError.generic("Failed to load feed."),
        hasFetchedOnce: true,
        hasMore: false,
      );
    }
  }

  // Method to remove a profile after interaction
  void removeProfile(int userId) {
    print("[FeedNotifier] Removing profile ID: $userId");
    if (!mounted) return;
    final updatedProfiles =
        state.profiles.where((profile) => profile.id != userId).toList();

    state = state.copyWith(profiles: updatedProfiles);

    // Optional: Fetch more if the list gets too small and we know there are more
    if (updatedProfiles.length < 3 && state.hasMore && !state.isLoading) {
      print(
          "[FeedNotifier] Profile list low (<3) and hasMore=true, fetching more...");
      fetchFeed(); // Fetch more without forcing refresh
    } else if (updatedProfiles.isEmpty && !state.hasMore) {
      print("[FeedNotifier] Profile list empty and hasMore=false.");
      // State already reflects empty list
    }
  }
}

// --- Provider Definition ---
final feedProvider = StateNotifierProvider<FeedNotifier, HomeFeedState>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return FeedNotifier(userRepository, ref);
});
