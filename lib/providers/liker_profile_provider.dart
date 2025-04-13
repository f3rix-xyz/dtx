// File: providers/liker_profile_provider.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/repositories/like_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// State Definition
class LikerProfileState {
  final bool isLoading;
  final UserProfileData? profile;
  final LikeInteractionDetails? likeDetails;
  final AppError? error;

  const LikerProfileState({
    this.isLoading = true, // Start loading
    this.profile,
    this.likeDetails,
    this.error,
  });

  LikerProfileState copyWith({
    bool? isLoading,
    UserProfileData? Function()? profile, // Nullable functions
    LikeInteractionDetails? Function()? likeDetails,
    AppError? Function()? error,
  }) {
    return LikerProfileState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile != null ? profile() : this.profile,
      likeDetails: likeDetails != null ? likeDetails() : this.likeDetails,
      error: error != null ? error() : this.error,
    );
  }
}

// StateNotifier Definition
class LikerProfileNotifier extends StateNotifier<LikerProfileState> {
  final LikeRepository _likeRepository;
  final int _likerUserId;

  LikerProfileNotifier(this._likeRepository, this._likerUserId)
      : super(const LikerProfileState()) {
    fetchProfile(); // Fetch profile on initialization
  }

  Future<void> fetchProfile() async {
    print(
        "[LikerProfileNotifier] Fetching profile for liker ID: $_likerUserId");
    // Don't clear profile/details on refetch, only on error maybe?
    state = state.copyWith(isLoading: true, error: () => null);
    try {
      final result = await _likeRepository.fetchLikerProfile(_likerUserId);
      final profileData = result['profile'] as UserProfileData?;
      final likeDetailsData = result['likeDetails'] as LikeInteractionDetails?;

      if (profileData != null && likeDetailsData != null) {
        print("[LikerProfileNotifier] Fetch successful.");
        state = state.copyWith(
          isLoading: false,
          profile: () => profileData,
          likeDetails: () => likeDetailsData,
          error: () => null,
        );
      } else {
        // This case should ideally be caught by the repository throwing an exception
        print(
            "[LikerProfileNotifier] Fetch failed: Repository returned null data.");
        state = state.copyWith(
            isLoading: false,
            error: () => AppError.server("Failed to load profile data."));
      }
    } on ApiException catch (e) {
      print("[LikerProfileNotifier] API Exception: ${e.message}");
      // Handle 404 Not Found specifically maybe
      if (e.statusCode == 404) {
        state = state.copyWith(
            isLoading: false,
            error: () => AppError.server(
                "Profile not found or you were not liked by this user."));
      } else {
        state = state.copyWith(
            isLoading: false, error: () => AppError.server(e.message));
      }
    } catch (e) {
      print("[LikerProfileNotifier] Unexpected Error: ${e.toString()}");
      state = state.copyWith(
          isLoading: false,
          error: () => AppError.generic("Failed to load profile."));
    }
  }
}

// Provider Definition (.family)
final likerProfileProvider =
    StateNotifierProvider.family<LikerProfileNotifier, LikerProfileState, int>(
        (ref, likerUserId) {
  final likeRepository = ref.watch(likeRepositoryProvider);
  return LikerProfileNotifier(likeRepository, likerUserId);
});
