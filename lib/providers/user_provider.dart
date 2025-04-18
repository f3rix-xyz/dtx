// File: providers/user_provider.dart
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart'; // Keep if used
import '../models/error_model.dart';
import '../models/user_model.dart';
import '../utils/app_enums.dart';

final userLoadingProvider = StateProvider<bool>((ref) => false);

final userProvider = StateNotifierProvider<UserNotifier, UserModel>((ref) {
  return UserNotifier(ref);
});

class UserNotifier extends StateNotifier<UserModel> {
  final Ref ref;

  UserNotifier(this.ref) : super(UserModel());

  Future<bool> fetchProfile() async {
    // Only set loading true if profile is actually empty
    bool shouldShowLoading = state.id == null;
    if (shouldShowLoading) ref.read(userLoadingProvider.notifier).state = true;
    ref.read(errorProvider.notifier).clearError();

    try {
      final userRepository = ref.read(userRepositoryProvider);
      final userModel = await userRepository.fetchUserProfile();
      state = userModel; // Direct assignment from fetch is fine
      if (shouldShowLoading)
        ref.read(userLoadingProvider.notifier).state = false;
      return true;
    } on ApiException catch (e) {
      if (shouldShowLoading)
        ref.read(userLoadingProvider.notifier).state = false;
      ref.read(errorProvider.notifier).setError(
            AppError.server(e.message), // Use server error type
          );
      return false;
    } catch (e) {
      if (shouldShowLoading)
        ref.read(userLoadingProvider.notifier).state = false;
      ref.read(errorProvider.notifier).setError(
            AppError.generic(
                "Failed to load profile: ${e.toString()}"), // Use generic
          );
      return false;
    }
  }

  // --- NO CHANGE: name, dob, location, gender updates are NOT used for editing ---
  void updateName(String firstName, String? lastName) {
    // This logic is only for onboarding validation
    ref.read(errorProvider.notifier).clearError();
    if (firstName.isEmpty || firstName.trim().length < 3) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("First name must be at least 3 characters"),
          );
      // Don't update state if invalid during onboarding
      // For edit, we rely on the ProfileScreen to handle this before save
      return;
    }
    state = state.copyWith(
      name: () => firstName.trim(),
      lastName: () => lastName?.trim(),
    );
  }

  void updateDateOfBirth(DateTime date) {
    // This logic is only for onboarding validation
    ref.read(errorProvider.notifier).clearError();
    final today = DateTime.now();
    final age = today.difference(date).inDays ~/ 365.25;

    if (date.year < 1900 || date.isAfter(today)) {
      ref
          .read(errorProvider.notifier)
          .setError(AppError.validation("Invalid year"));
      return;
    }
    if (age < 18) {
      ref
          .read(errorProvider.notifier)
          .setError(AppError.validation("You must be at least 18 years old"));
      return;
    }
    try {
      final validatedDate = DateTime(date.year, date.month, date.day);
      state = state.copyWith(dateOfBirth: () => validatedDate);
    } catch (e) {
      ref
          .read(errorProvider.notifier)
          .setError(AppError.validation("Invalid date combination"));
    }
  }

  void updateLocation(double latitude, double longitude) {
    state = state.copyWith(
      latitude: () => latitude,
      longitude: () => longitude,
    );
  }

  void updateGender(Gender? gender) {
    state = state.copyWith(gender: () => gender);
  }
  // --- END NO CHANGE ---

  LatLng getCurrentLocation() {
    return LatLng(state.latitude ?? 19.2183, state.longitude ?? 73.0864);
  }

  bool isLocationValid() {
    return state.latitude != null &&
        state.longitude != null &&
        state.latitude != 0.0 &&
        state.longitude != 0.0;
  }

  bool isNameValid() => (state.name?.trim().length ?? 0) >= 3;

  // --- Editable Fields ---
  void updateDatingIntention(DatingIntention? intention) {
    state = state.copyWith(datingIntention: () => intention);
  }

  bool isDatingIntentionSelected() {
    return state.datingIntention != null;
  }

  void updateHeight(String height) {
    state = state.copyWith(height: () => height);
  }

  bool isHeightSelected() {
    return state.height != null && state.height!.isNotEmpty;
  }

  void updateHometown(String? hometown) {
    // Allow setting to null for clearing
    state = state.copyWith(hometown: () => hometown?.trim());
  }

  bool isHometownSelected() {
    return state.hometown != null && state.hometown!.isNotEmpty;
  }

  void updateJobTitle(String? jobTitle) {
    // Allow setting to null for clearing
    state = state.copyWith(jobTitle: () => jobTitle?.trim());
  }

  void updateEducation(String? education) {
    // Allow setting to null for clearing
    state = state.copyWith(education: () => education?.trim());
  }

  void updateReligiousBeliefs(Religion? religion) {
    state = state.copyWith(religiousBeliefs: () => religion);
  }

  void updateDrinkingHabit(DrinkingSmokingHabits? habit) {
    state = state.copyWith(drinkingHabit: () => habit);
  }

  void updateSmokingHabit(DrinkingSmokingHabits? habit) {
    state = state.copyWith(smokingHabit: () => habit);
  }

  void addPrompt(Prompt prompt) {
    if (prompt.answer.trim().isEmpty) return;
    if (state.prompts.length >= 3) return;
    final updatedPrompts = List<Prompt>.from(state.prompts)..add(prompt);
    state = state.copyWith(prompts: updatedPrompts);
  }

  void updatePromptAtIndex(int index, Prompt newPrompt) {
    if (newPrompt.answer.trim().isEmpty) return;
    final updatedPrompts = List<Prompt>.from(state.prompts);
    if (index >= 0 && index < updatedPrompts.length) {
      updatedPrompts[index] = newPrompt;
      state = state.copyWith(prompts: updatedPrompts);
    }
  }

  void removePromptAtIndex(int index) {
    final updatedPrompts = List<Prompt>.from(state.prompts);
    if (index >= 0 && index < updatedPrompts.length) {
      updatedPrompts.removeAt(index);
      state = state.copyWith(prompts: updatedPrompts);
    }
  }

  void updateAudioPrompt(AudioPromptModel? audioPrompt) {
    state = state.copyWith(audioPrompt: () => audioPrompt);
  }

  // --- Media Updates (for edit mode) ---
  void updateMediaUrls(List<String> urls) {
    // Directly update the URLs list (typically after upload during save)
    state = state.copyWith(mediaUrls: () => urls);
    // Reset the change flag after URLs are explicitly updated post-save
    state = state.copyWith(mediaChangedDuringEdit: false);
  }

  void setMediaChangedFlag(bool changed) {
    // This flag is set by ProfileScreen when returning from MediaPickerScreen in edit mode
    state = state.copyWith(mediaChangedDuringEdit: changed);
    print("[UserNotifier] Media changed flag set to: $changed");
  }
  // --- End Media Updates ---

  // saveProfile remains for ONBOARDING STEP 2 (POST request)
  Future<bool> saveProfile() async {
    print("[UserNotifier saveProfile] Called (for onboarding step 2 - POST).");
    ref.read(userLoadingProvider.notifier).state = true;
    ref.read(errorProvider.notifier).clearError();

    if (!state.isProfileValid()) {
      // Uses onboarding validation
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Please complete all required profile fields."),
          );
      ref.read(userLoadingProvider.notifier).state = false;
      return false;
    }

    try {
      final userRepository = ref.read(userRepositoryProvider);
      // This now internally calls updateProfileDetails (POST) with the correct payload
      final success = await userRepository.updateProfile(state);

      ref.read(userLoadingProvider.notifier).state = false;
      if (!success && ref.read(errorProvider) == null) {
        // Check if error already set
        ref
            .read(errorProvider.notifier)
            .setError(AppError.server("Failed to save profile."));
      }
      return success;
    } on ApiException catch (e) {
      ref.read(userLoadingProvider.notifier).state = false;
      ref.read(errorProvider.notifier).setError(AppError.server(e.message));
      return false;
    } catch (e) {
      ref.read(userLoadingProvider.notifier).state = false;
      ref
          .read(errorProvider.notifier)
          .setError(AppError.generic("An unexpected error occurred."));
      return false;
    }
  }

  bool isProfileValid() {
    // For onboarding step 2 POST
    return state.isProfileValid(); // Delegate to UserModel's method
  }
}
