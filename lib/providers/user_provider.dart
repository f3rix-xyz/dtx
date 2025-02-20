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

  UserNotifier(this.ref)
      : super(UserModel(
          name: '',
          phoneNumber: '',
          dateOfBirth: DateTime.now(),
          latitude: 0.0,
          longitude: 0.0,
          gender: Gender.man,
          datingIntention: DatingIntention.figuringOut,
          height: '',
          religiousBeliefs: Religion.spiritual,
          drinkingHabit: DrinkingSmokingHabits.no,
          smokingHabit: DrinkingSmokingHabits.no,
          mediaUrls: [],
          prompts: [],
          lastName: null,
          hometown: null,
          jobTitle: null,
          education: null,
          audioPrompt: null,
        ));

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
      // Validate date combination
      final validatedDate = DateTime(date.year, date.month, date.day);
      state = state.copyWith(dateOfBirth: validatedDate);
    } catch (e) {
      ref.read(errorProvider.notifier).setError(
            AppError.validation("Invalid date combination"),
          );
    }
  }

  void updateLocation(LatLng location) {
    state = state.copyWith(
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  LatLng getCurrentLocation() {
    return LatLng(state.latitude, state.longitude);
  }

  bool isLocationValid() {
    return state.latitude != 0.0 && state.longitude != 0.0;
  }

  bool isNameValid() => state.name.trim().length >= 3;
}
