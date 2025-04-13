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
    // ... (existing fetchProfile logic - no changes needed here for copyWith) ...
    try {
      ref.read(userLoadingProvider.notifier).state = true;
      ref.read(errorProvider.notifier).clearError();

      final userRepository = ref.read(userRepositoryProvider);
      final userModel = await userRepository.fetchUserProfile();

      state = userModel; // Direct assignment from fetch is fine

      ref.read(userLoadingProvider.notifier).state = false;
      return true;
    } on ApiException catch (e) {
      ref.read(userLoadingProvider.notifier).state = false;
      ref.read(errorProvider.notifier).setError(
            AppError.server(e.message), // Use server error type
          );
      return false;
    } catch (e) {
      ref.read(userLoadingProvider.notifier).state = false;
      ref.read(errorProvider.notifier).setError(
            AppError.generic(
                "Failed to load profile: ${e.toString()}"), // Use generic
          );
      return false;
    }
  }

  // --- FIX: Update copyWith calls to use functions for nullable fields ---
  void updateName(String firstName, String? lastName) {
    ref.read(errorProvider.notifier).clearError();
    if (firstName.isEmpty || firstName.trim().length < 3) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("First name must be at least 3 characters"),
          );
      return; // Don't update state if invalid
    }

    state = state.copyWith(
      name: () => firstName.trim(),
      lastName: () =>
          lastName?.trim(), // Pass function returning nullable value
    );
  }

  void updateDateOfBirth(DateTime date) {
    ref.read(errorProvider.notifier).clearError();
    final today = DateTime.now();
    final age = today.difference(date).inDays ~/ 365.25;

    if (date.year < 1900 || date.isAfter(today)) {
      // Also check if date is in future
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
      state = state.copyWith(dateOfBirth: () => validatedDate); // Pass function
    } catch (e) {
      ref
          .read(errorProvider.notifier)
          .setError(AppError.validation("Invalid date combination"));
    }
  }

  void updateLocation(double latitude, double longitude) {
    state = state.copyWith(
      latitude: () => latitude, // Pass function
      longitude: () => longitude, // Pass function
    );
  }

  LatLng getCurrentLocation() {
    // Use default values if state is null
    return LatLng(state.latitude ?? 19.2183, state.longitude ?? 73.0864);
  }

  bool isLocationValid() {
    return state.latitude != null &&
        state.longitude != null &&
        state.latitude != 0.0 &&
        state.longitude != 0.0;
  }

  bool isNameValid() => (state.name?.trim().length ?? 0) >= 3;

  void updateDatingIntention(DatingIntention? intention) {
    state = state.copyWith(datingIntention: () => intention); // Pass function
  }

  bool isDatingIntentionSelected() {
    return state.datingIntention != null;
  }

  void updateGender(Gender? gender) {
    state = state.copyWith(gender: () => gender); // Pass function
  }

  bool isGenderSelected() {
    return state.gender != null;
  }

  void updateHeight(String height) {
    // Add basic validation if needed, e.g., regex check
    state = state.copyWith(height: () => height); // Pass function
  }

  bool isHeightSelected() {
    // Check if not null AND not empty
    return state.height != null && state.height!.isNotEmpty;
  }

  void updateHometown(String? hometown) {
    state = state.copyWith(hometown: () => hometown?.trim()); // Pass function
  }

  bool isHometownSelected() {
    return state.hometown != null && state.hometown!.isNotEmpty;
  }

  void updateJobTitle(String? jobTitle) {
    state = state.copyWith(jobTitle: () => jobTitle?.trim()); // Pass function
  }

  void updateEducation(String? education) {
    state = state.copyWith(education: () => education?.trim()); // Pass function
  }

  void updateReligiousBeliefs(Religion? religion) {
    state = state.copyWith(religiousBeliefs: () => religion); // Pass function
  }

  void updateDrinkingHabit(DrinkingSmokingHabits? habit) {
    state = state.copyWith(drinkingHabit: () => habit); // Pass function
  }

  void updateSmokingHabit(DrinkingSmokingHabits? habit) {
    state = state.copyWith(smokingHabit: () => habit); // Pass function
  }

  void addPrompt(Prompt prompt) {
    // Ensure prompt answer is not empty before adding
    if (prompt.answer.trim().isEmpty) return;
    // Prevent adding more than 3 prompts
    if (state.prompts.length >= 3) return;

    final updatedPrompts = List<Prompt>.from(state.prompts)..add(prompt);
    state = state.copyWith(
        prompts: updatedPrompts); // Direct list update is okay for copyWith
  }

  void updatePromptAtIndex(int index, Prompt newPrompt) {
    // Ensure prompt answer is not empty
    if (newPrompt.answer.trim().isEmpty) return;

    final updatedPrompts = List<Prompt>.from(state.prompts);
    if (index >= 0 && index < updatedPrompts.length) {
      updatedPrompts[index] = newPrompt;
      state = state.copyWith(prompts: updatedPrompts);
    }
  }

  // Keep old saveProfile for now, it calls the new repo method via UserModel
  Future<bool> saveProfile() async {
    print("[UserNotifier saveProfile] Called (using deprecated approach).");
    ref.read(userLoadingProvider.notifier).state = true;
    ref.read(errorProvider.notifier).clearError();

    if (!state.isProfileValid()) {
      // Use helper from UserModel
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Please complete all required profile fields."),
          );
      ref.read(userLoadingProvider.notifier).state = false;
      return false;
    }

    try {
      final userRepository = ref.read(userRepositoryProvider);
      // This now internally calls updateProfileDetails with the correct payload
      final success = await userRepository.updateProfile(state);

      ref.read(userLoadingProvider.notifier).state = false;
      if (!success) {
        // Error should be set by the repository/api service layer
        // ref.read(errorProvider.notifier).setError(AppError.server("Failed to save profile."));
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
    return state.isProfileValid(); // Delegate to UserModel's method
  }

  void updateAudioPrompt(AudioPromptModel? audioPrompt) {
    // Make parameter nullable
    state = state.copyWith(audioPrompt: () => audioPrompt); // Pass function
  }
}
