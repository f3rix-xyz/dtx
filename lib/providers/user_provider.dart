import 'package:dtx/providers/error_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/error_model.dart';
import '../models/user_model.dart';
import '../utils/app_enums.dart';

final userProvider = StateNotifierProvider<UserNotifier, UserModel>((ref) {
  return UserNotifier(ref);
});

class UserNotifier extends StateNotifier<UserModel> {
  final Ref ref;

  UserNotifier(this.ref) : super(UserModel());

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

  void addPrompt({
    required PromptCategory category,
    required String question,
    required String answer,
  }) {
    print('=== ADDING NEW PROMPT ===');
    print('Category: $category');
    print('Question: $question');
    print('Answer: $answer');

    final existingPrompts = state.prompts;
    print('Current prompts count: ${existingPrompts.length}');

    // Check for duplicate questions
    final duplicate = existingPrompts.any((p) => p.question == question);
    if (duplicate) {
      print('⚠️ Prompt already exists! Question: $question');
      return;
    }

    final newPrompt = Prompt(
      category: category,
      question: question,
      answer: answer,
    );

    final updatedPrompts = [...existingPrompts, newPrompt];
    print('New prompts count: ${updatedPrompts.length}');
    print('All prompts: $updatedPrompts');

    state = state.copyWith(prompts: updatedPrompts);
    print('✅ Prompt added successfully!');
  }
}
