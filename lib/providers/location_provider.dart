import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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

  Future<void> fetchCurrentLocation() async {
    if (state.cachedLatitude != null && state.cachedLongitude != null) {
      state = state.copyWith(
        latitude: state.cachedLatitude!,
        longitude: state.cachedLongitude!,
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(isFetching: true, isLoading: true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ref
            .read(errorProvider.notifier)
            .setError(AppError.validation("Location services are disabled"));
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
      ref
          .read(userProvider.notifier)
          .updateLocation(LatLng(newLatitude, newLongitude));

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
    ref.read(userProvider.notifier).updateLocation(LatLng(latitude, longitude));
  }

  void useCachedLocation() {
    if (state.cachedLatitude != null && state.cachedLongitude != null) {
      updateLocation(state.cachedLatitude!, state.cachedLongitude!);
    }
  }
}
