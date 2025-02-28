import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/error_model.dart';
import '../models/user_model.dart';
import '../utils/app_enums.dart';

// Add this provider to track the loading state
final userLoadingProvider = StateProvider<bool>((ref) => false);

final userProvider = StateNotifierProvider<UserNotifier, UserModel>((ref) {
  return UserNotifier(ref);
});

class UserNotifier extends StateNotifier<UserModel> {
  final Ref ref;

  UserNotifier(this.ref) : super(UserModel());

  // New method to fetch user profile
  Future<bool> fetchProfile() async {
    try {
      ref.read(userLoadingProvider.notifier).state = true;
      ref.read(errorProvider.notifier).clearError();
      
      final userRepository = ref.read(userRepositoryProvider);
      final userModel = await userRepository.fetchUserProfile();
      
      state = userModel;
      
      ref.read(userLoadingProvider.notifier).state = false;
      return true;
    } on ApiException catch (e) {
      ref.read(userLoadingProvider.notifier).state = false;
      ref.read(errorProvider.notifier).setError(
        AppError.auth(e.message),
      );
      return false;
    } catch (e) {
      ref.read(userLoadingProvider.notifier).state = false;
      ref.read(errorProvider.notifier).setError(
        AppError.auth("Failed to load profile: ${e.toString()}"),
      );
      return false;
    }
  }

  void updateName(String firstName, String? lastName) {
    ref.read(errorProvider.notifier).clearError();

    if (firstName.isEmpty) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("First name is required"),
          );
      return;
    }

    if (firstName.trim().length < 3) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("First name must be at least 3 characters"),
          );
      return;
    }

    state = state.copyWith(
      name: firstName.trim(),
      lastName: lastName?.trim(),
    );
  }

  void updateDateOfBirth(DateTime date) {
    ref.read(errorProvider.notifier).clearError();

    final today = DateTime.now();
    final age = today.difference(date).inDays ~/ 365;

    if (date.year < 1900 || date.year > today.year) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Invalid year"),
          );
      return;
    }

    if (age < 18) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("You must be at least 18 years old"),
          );
      return;
    }

    try {
      final validatedDate = DateTime(date.year, date.month, date.day);
      state = state.copyWith(dateOfBirth: validatedDate);
    } catch (e) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Invalid date combination"),
          );
    }
  }

  void updateLocation(double latitude, double longitude) {
    state = state.copyWith(
      latitude: latitude,
      longitude: longitude,
    );
  }

  LatLng getCurrentLocation() {
    return LatLng(
      state.latitude ?? 0.0,
      state.longitude ?? 0.0,
    );
  }

  bool isLocationValid() {
    return state.latitude != null &&
        state.longitude != null &&
        state.latitude != 0.0 &&
        state.longitude != 0.0;
  }

  bool isNameValid() => (state.name?.trim().length ?? 0) >= 3;

  void updateDatingIntention(DatingIntention? intention) {
    state = state.copyWith(
      datingIntention: intention,
    );
  }

  bool isDatingIntentionSelected() {
    return state.datingIntention != null;
  }

  void updateGender(Gender? gender) {
    state = state.copyWith(
      gender: gender,
    );
  }

  bool isGenderSelected() {
    return state.gender != null;
  }

  void updateHeight(String height) {
    state = state.copyWith(
      height: height,
    );
  }

  bool isHeightSelected() {
    return state.height != null;
  }

  void updateHometown(String? hometown) {
    state = state.copyWith(
      hometown: hometown,
    );
  }

  bool isHometownSelected() {
    return state.hometown != null;
  }

  void updateJobTitle(String? jobTitle) {
    state = state.copyWith(
      jobTitle: jobTitle?.trim(),
    );
  }

  void updateEducation(String? education) {
    state = state.copyWith(
      education: education?.trim(),
    );
  }

  void updateReligiousBeliefs(Religion? religion) {
    state = state.copyWith(
      religiousBeliefs: religion,
    );
  }

  void updateDrinkingHabit(DrinkingSmokingHabits? habit) {
    state = state.copyWith(
      drinkingHabit: habit,
    );
  }

  void updateSmokingHabit(DrinkingSmokingHabits? habit) {
    state = state.copyWith(
      smokingHabit: habit,
    );
  }

  void addPrompt(Prompt prompt) {
    final updatedPrompts = List<Prompt>.from(state.prompts)..add(prompt);
    state = state.copyWith(prompts: updatedPrompts);
  }

  void updatePromptAtIndex(int index, Prompt newPrompt) {
    final updatedPrompts = List<Prompt>.from(state.prompts);
    if (index < updatedPrompts.length) {
      updatedPrompts[index] = newPrompt;
      state = state.copyWith(prompts: updatedPrompts);
    }
  }

  Future<bool> saveProfile() async {
    try {
      // Clear any existing errors
      ref.read(errorProvider.notifier).clearError();
      
      // Basic validation
      if (!isProfileValid()) {
        ref.read(errorProvider.notifier).setError(
          AppError.validation("Please complete all required fields"),
        );
        return false;
      }
      
      // Get the repository from provider
      final userRepository = ref.read(userRepositoryProvider);
      
      // Send the profile data to the API
      final success = await userRepository.updateProfile(state);
      
      if (!success) {
        ref.read(errorProvider.notifier).setError(
          AppError.auth("Failed to save profile. Please try again."),
        );
      }
      
      return success;
    } on ApiException catch (e) {
      ref.read(errorProvider.notifier).setError(
        AppError.auth(e.message),
      );
      return false;
    } catch (e) {
      ref.read(errorProvider.notifier).setError(
        AppError.auth("An unexpected error occurred. Please try again."),
      );
      return false;
    }
  }
  
  // Helper method to validate profile completeness
  bool isProfileValid() {
    return state.name != null && 
           state.name!.isNotEmpty &&
           state.dateOfBirth != null &&
           state.gender != null &&
           state.datingIntention != null &&
           isLocationValid();
  }

  void updateAudioPrompt(AudioPromptModel audioPrompt) {
    state = state.copyWith(
      audioPrompt: audioPrompt,
    );
  }
}
