// File: lib/views/filter_settings_dialog.dart
import 'package:dtx/models/filter_model.dart';
import 'package:dtx/providers/feed_provider.dart'; // Import FeedProvider
import 'package:dtx/providers/filter_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class FilterSettingsDialog extends ConsumerStatefulWidget {
  const FilterSettingsDialog({super.key});

  @override
  ConsumerState<FilterSettingsDialog> createState() =>
      _FilterSettingsDialogState();
}

class _FilterSettingsDialogState extends ConsumerState<FilterSettingsDialog> {
  late FilterSettings _currentFilters;
  late RangeValues _currentAgeRange;
  late double _currentRadius;
  bool _isLoading = false; // Local loading state for saving

  @override
  void initState() {
    super.initState();
    // Initialize local state with current provider state when dialog opens
    final initialFilters = ref.read(filterProvider);
    _currentFilters = initialFilters;
    _currentAgeRange = RangeValues(
      initialFilters.ageMin?.toDouble() ??
          FilterSettings.defaultAgeMin.toDouble(),
      initialFilters.ageMax?.toDouble() ??
          FilterSettings.defaultAgeMax.toDouble(),
    );
    _currentRadius = initialFilters.radiusKm?.toDouble() ??
        FilterSettings.defaultRadius.toDouble();
  }

  Future<void> _applyFilters() async {
    if (_isLoading) return; // Prevent double taps

    setState(() => _isLoading = true);

    final newSettings = _currentFilters.copyWith(
      ageMin: () => _currentAgeRange.start.round(),
      ageMax: () => _currentAgeRange.end.round(),
      radiusKm: () => _currentRadius.round(),
      // whoYouWantToSee and activeToday are already updated in _currentFilters via setState
    );

    final success =
        await ref.read(filterProvider.notifier).saveFilters(newSettings);

    // Check if mounted before interacting with context or state
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      print(
          "[FilterSettingsDialog] Filters saved successfully. Refreshing feed.");
      // Trigger feed refresh AFTER saving filters
      ref.read(feedProvider.notifier).fetchFeed(forceRefresh: true);
      Navigator.of(context).pop(true); // Pop dialog and indicate success
    } else {
      // Error handling is likely done via the errorProvider in FilterNotifier
      // Optionally show a snackbar here too if desired.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Failed to save filters", style: GoogleFonts.poppins())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // No need to watch provider's loading state directly, use local _isLoading for save button

    return AlertDialog(
      title: Text("Filters",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Who You Want To See ---
            Text("Show Me:",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: FilterGenderPref.values.map((genderPref) {
                return ChoiceChip(
                  label: Text(genderPref.value[0].toUpperCase() +
                      genderPref.value.substring(1)),
                  selected: _currentFilters.whoYouWantToSee == genderPref,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        // Use copyWith for immutability when updating local state
                        _currentFilters = _currentFilters.copyWith(
                            whoYouWantToSee: () => genderPref);
                      });
                    }
                  },
                  selectedColor: const Color(0xFFEDE9FE),
                  checkmarkColor: const Color(0xFF8B5CF6),
                  labelStyle: GoogleFonts.poppins(
                    color: _currentFilters.whoYouWantToSee == genderPref
                        ? const Color(0xFF8B5CF6)
                        : Colors.black87,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                          color: _currentFilters.whoYouWantToSee == genderPref
                              ? const Color(0xFF8B5CF6)
                              : Colors.grey.shade300)),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // --- Age Range ---
            Text("Age Range:",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            RangeSlider(
              values: _currentAgeRange,
              min: 18,
              max: 70,
              divisions: 52,
              labels: RangeLabels(
                _currentAgeRange.start.round().toString(),
                _currentAgeRange.end.round().toString(),
              ),
              activeColor: const Color(0xFF8B5CF6),
              inactiveColor: const Color(0xFF8B5CF6).withOpacity(0.3),
              onChanged: (RangeValues values) {
                setState(() {
                  if (values.start <= values.end) {
                    _currentAgeRange = values;
                  }
                });
              },
            ),
            Text(
              "${_currentAgeRange.start.round()} - ${_currentAgeRange.end.round()} years",
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // --- Distance Radius ---
            Text("Distance (km):",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            Slider(
              value: _currentRadius,
              min: 1,
              max: 500,
              divisions: 499,
              label: _currentRadius.round().toString(),
              activeColor: const Color(0xFF8B5CF6),
              inactiveColor: const Color(0xFF8B5CF6).withOpacity(0.3),
              onChanged: (double value) {
                setState(() {
                  _currentRadius = value;
                });
              },
            ),
            Text(
              "${_currentRadius.round()} km",
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // --- Active Today ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Active Today Only:",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                Switch(
                  value: _currentFilters.activeToday ??
                      FilterSettings.defaultActiveToday,
                  activeColor: const Color(0xFF8B5CF6),
                  onChanged: (bool value) {
                    setState(() {
                      _currentFilters =
                          _currentFilters.copyWith(activeToday: () => value);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          onPressed: () =>
              Navigator.of(context).pop(false), // Indicate no change
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20))),
          onPressed: _isLoading ? null : _applyFilters, // Disable while saving
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text('Apply', style: GoogleFonts.poppins()),
        ),
      ],
      actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    );
  }
}
