// File: lib/providers/filter_provider.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/filter_model.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/feed_provider.dart'; // Import feed provider
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/repositories/filter_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- StateNotifier Provider (No change) ---
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

  // Load filters from the repository (No change)
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

  // Save filters (used by full dialog)
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
      // Refresh feed after saving from the *full* dialog as well
      print("[FilterNotifier] Filters saved via full dialog. Refreshing feed.");
      ref.read(feedProvider.notifier).fetchFeed(forceRefresh: true);
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

  // Helper to manage internal loading state (No change)
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
    }
  }

  // Method to update a single filter value in the *state* (No change)
  // Ensures immutability by using copyWith
  void updateSingleFilter<T>(T value, FilterField field) {
    if (_isLoading) return; // Prevent updates while saving/loading
    print("[FilterNotifier] Updating single filter state $field to $value");
    state = state.copyWith(
      whoYouWantToSee: field == FilterField.whoYouWantToSee
          ? () => value as FilterGenderPref?
          : null,
      radiusKm: field == FilterField.radiusKm ? () => value as int? : null,
      activeToday:
          field == FilterField.activeToday ? () => value as bool? : null,
      ageMin: field == FilterField.ageMin ? () => value as int? : null,
      ageMax: field == FilterField.ageMax ? () => value as int? : null,
    );
  }

  // --- *** NEW METHOD: Save Current State *** ---
  // Saves the current state held by the notifier to the backend
  Future<bool> saveCurrentFilterState() async {
    if (_isLoading) return false;
    _setLoading(true);
    ref.read(errorProvider.notifier).clearError();
    print("[FilterNotifier] Saving current filter state via API: ${state.toJsonForApi()}");

    try {
      final success = await _filterRepository.updateFilters(state); // Pass current state
      if (!success) {
        if (mounted) {
          // Error is likely set by repo, but add fallback
          if (ref.read(errorProvider) == null) {
            ref.read(errorProvider.notifier).setError(AppError.server("Failed to save filter change."));
          }
        }
        print("[FilterNotifier] Failed to save current filter state via API.");
        return false;
      }
      // Filters saved, now refresh feed
      print("[FilterNotifier] Current filter state saved successfully via API. Refreshing feed.");
      ref.read(feedProvider.notifier).fetchFeed(forceRefresh: true);
      return true; // Success
    } on ApiException catch (e) {
      if (mounted) {
        ref.read(errorProvider.notifier).setError(AppError.server(e.message));
      }
       print("[FilterNotifier] API Exception saving current filter state: ${e.message}");
      return false;
    } catch (e) {
       if (mounted) {
         ref.read(errorProvider.notifier).setError(AppError.generic("An unexpected error occurred saving filter."));
      }
      print("[FilterNotifier] Unexpected error saving current filter state: $e");
      return false;
    } finally {
      if (mounted) _setLoading(false);
    }
  }
  // --- *** END NEW METHOD *** ---
}

// Enum to identify which filter field is being updated (No change)
enum FilterField { whoYouWantToSee, radiusKm, activeToday, ageMin, ageMax }
