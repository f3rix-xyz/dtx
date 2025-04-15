// lib/providers/filter_provider.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/filter_model.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/repositories/filter_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- REMOVED: filterLoadingProvider - manage loading within the notifier ---

// --- StateNotifier Provider ---
final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterSettings>((ref) {
  final filterRepository = ref.watch(filterRepositoryProvider);
  return FilterNotifier(ref, filterRepository);
});

// --- StateNotifier ---
class FilterNotifier extends StateNotifier<FilterSettings> {
  final Ref ref;
  final FilterRepository _filterRepository;
  bool _isLoading = false; // Internal loading state
  bool get isLoading => _isLoading; // Getter for UI

  FilterNotifier(this.ref, this._filterRepository)
      : super(const FilterSettings()) {
    // Optionally load filters on initialization if needed, or rely on UI trigger
    // loadFilters();
  }

  // Load filters from the repository
  Future<void> loadFilters({bool forceRemote = false}) async {
    // Prevent multiple fetches if already loading or if data exists and not forced
    if (_isLoading || (state != const FilterSettings() && !forceRemote)) {
      return;
    }
    _setLoading(true);
    ref.read(errorProvider.notifier).clearError(); // Clear previous errors

    try {
      final filters = await _filterRepository.fetchFilters();
      if (mounted) {
        state = filters; // Update state
      }
    } catch (e) {
      if (mounted) {
        ref
            .read(errorProvider.notifier)
            .setError(AppError.generic("Could not load filter settings."));
        // Don't reset to default, keep previous state or handle error UI
      }
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  // Save filters to the repository
  Future<bool> saveFilters(FilterSettings newFilters) async {
    if (_isLoading) return false;
    _setLoading(true);
    ref.read(errorProvider.notifier).clearError();
    final previousState = state; // Keep old state in case of failure
    state = newFilters; // Optimistically update UI

    try {
      final success = await _filterRepository.updateFilters(newFilters);
      if (!success) {
        // If API returns false, revert state and show error
        if (mounted) {
          state = previousState;
          ref
              .read(errorProvider.notifier)
              .setError(AppError.server("Failed to save filters."));
        }
        return false;
      }
      return true; // Success
    } on ApiException catch (e) {
      if (mounted) {
        state = previousState; // Revert state on error
        ref.read(errorProvider.notifier).setError(AppError.server(e.message));
      }
      return false;
    } catch (e) {
      if (mounted) {
        state = previousState; // Revert state on error
        ref
            .read(errorProvider.notifier)
            .setError(AppError.generic("An unexpected error occurred."));
      }
      return false;
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  // Helper to manage internal loading state
  void _setLoading(bool loading) {
    // Could add notifyListeners() if using ChangeNotifier, but not needed for StateNotifier
    if (_isLoading != loading) {
      _isLoading = loading;
      // No need to call setState or notifyListeners for StateNotifier's internal state
    }
  }

  // Method to update a single filter value directly (e.g., from slider/switch)
  // Ensures immutability by using copyWith
  void updateSingleFilter<T>(T value, FilterField field) {
    if (_isLoading) return; // Prevent updates while saving/loading
    state = state.copyWith(
      whoYouWantToSee: field == FilterField.whoYouWantToSee
          ? () => value as FilterGenderPref? // Cast to correct type
          : null, // Return null for other fields
      radiusKm: field == FilterField.radiusKm ? () => value as int? : null,
      activeToday:
          field == FilterField.activeToday ? () => value as bool? : null,
      ageMin: field == FilterField.ageMin ? () => value as int? : null,
      ageMax: field == FilterField.ageMax ? () => value as int? : null,
    );
  }
}

// Enum to identify which filter field is being updated
enum FilterField { whoYouWantToSee, radiusKm, activeToday, ageMin, ageMax }
