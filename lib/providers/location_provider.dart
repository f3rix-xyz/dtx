import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/error_model.dart';
import '../models/location_model.dart';
import 'error_provider.dart';
import 'user_provider.dart';

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(ref);
});

class LocationNotifier extends StateNotifier<LocationState> {
  final Ref ref;

  LocationNotifier(this.ref) : super(LocationState());

  void setMapReady(bool ready) {
    state = state.copyWith(isMapReady: ready);
  }

  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      ref
          .read(errorProvider.notifier)
          .setError(AppError.network("Failed to open location settings"));
    }
  }

  Future<void> fetchCurrentLocation() async {
    // Clear any existing errors
    ref.read(errorProvider.notifier).clearError();

    // Reset state for fresh fetch
    state = state.copyWith(
      isFetching: true,
      isLoading: true,
      cachedLatitude: null,
      cachedLongitude: null,
    );

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ref.read(errorProvider.notifier).setError(
            AppError.locationService("Location services are disabled"));
        state = state.copyWith(isLoading: false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ref
              .read(errorProvider.notifier)
              .setError(AppError.validation("Location permissions are denied"));
          state = state.copyWith(isLoading: false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ref.read(errorProvider.notifier).setError(
            AppError.validation("Location permissions are permanently denied"));
        state = state.copyWith(isLoading: false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final newLatitude = position.latitude;
      final newLongitude = position.longitude;

      // Update user provider with the location
      ref.read(userProvider.notifier).updateLocation(newLatitude, newLongitude);

      state = state.copyWith(
        latitude: newLatitude,
        longitude: newLongitude,
        cachedLatitude: newLatitude,
        cachedLongitude: newLongitude,
        isLoading: false,
      );
    } catch (e) {
      ref.read(errorProvider.notifier).setError(
          AppError.network("Failed to fetch location: ${e.toString()}"));
      state = state.copyWith(isLoading: false);
    } finally {
      state = state.copyWith(isFetching: false);
    }
  }

  void updateLocation(double latitude, double longitude) {
    state = state.copyWith(latitude: latitude, longitude: longitude);
    ref.read(userProvider.notifier).updateLocation(latitude, longitude);
  }

  void useCachedLocation() {
    if (state.cachedLatitude != null && state.cachedLongitude != null) {
      updateLocation(state.cachedLatitude!, state.cachedLongitude!);
    }
  }
}
