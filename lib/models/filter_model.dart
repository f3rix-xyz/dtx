// lib/models/filter_model.dart
import 'package:dtx/utils/app_enums.dart'; // For Gender enum (ensure correct import if needed)

// --- NEW: Enum for Gender Preference in Filters ---
// Aligns with backend Go enum values ('man', 'woman')
enum FilterGenderPref {
  man('man'),
  woman('woman');

  final String value;
  const FilterGenderPref(this.value);

  // Helper to convert string from API/JSON back to enum
  static FilterGenderPref? fromValue(String? value) {
    if (value == null) return null;
    try {
      return FilterGenderPref.values.firstWhere(
        (e) => e.value.toLowerCase() == value.toLowerCase(),
      );
    } catch (e) {
      return null; // Return null if value doesn't match any enum
    }
  }
}
// --- END NEW ---

class FilterSettings {
  final int? userId; // Keep user ID if needed to associate filters
  final FilterGenderPref? whoYouWantToSee; // Updated type
  final int? radiusKm;
  final bool? activeToday;
  final int? ageMin;
  final int? ageMax;
  final DateTime? createdAt; // Optional: For informational purposes
  final DateTime? updatedAt; // Optional: For informational purposes

  // Define default values (you might want to adjust these)
  static const FilterGenderPref defaultGenderPref = FilterGenderPref.woman;
  static const int defaultRadius = 50; // e.g., 50 km
  static const bool defaultActiveToday = false;
  static const int defaultAgeMin = 18;
  static const int defaultAgeMax = 55;

  const FilterSettings({
    this.userId,
    this.whoYouWantToSee = defaultGenderPref, // Default to show women
    this.radiusKm = defaultRadius,
    this.activeToday = defaultActiveToday,
    this.ageMin = defaultAgeMin,
    this.ageMax = defaultAgeMax,
    this.createdAt,
    this.updatedAt,
  });

  // Check if the current settings are the default ones
  bool get isDefault {
    return whoYouWantToSee == defaultGenderPref &&
        radiusKm == defaultRadius &&
        activeToday == defaultActiveToday &&
        ageMin == defaultAgeMin &&
        ageMax == defaultAgeMax;
  }

  // copyWith method for immutability
  FilterSettings copyWith({
    int? userId,
    FilterGenderPref? Function()? whoYouWantToSee, // Use nullable functions
    int? Function()? radiusKm,
    bool? Function()? activeToday,
    int? Function()? ageMin,
    int? Function()? ageMax,
    DateTime? createdAt, // Optional: For informational purposes
    DateTime? updatedAt, // Optional: For informational purposes
  }) {
    return FilterSettings(
      userId: userId ?? this.userId,
      whoYouWantToSee:
          whoYouWantToSee != null ? whoYouWantToSee() : this.whoYouWantToSee,
      radiusKm: radiusKm != null ? radiusKm() : this.radiusKm,
      activeToday: activeToday != null ? activeToday() : this.activeToday,
      ageMin: ageMin != null ? ageMin() : this.ageMin,
      ageMax: ageMax != null ? ageMax() : this.ageMax,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convert to JSON for API requests (align keys with backend)
  Map<String, dynamic> toJsonForApi() {
    final Map<String, dynamic> data = {};
    // Only include fields that are non-null or should be sent
    if (whoYouWantToSee != null)
      data['whoYouWantToSee'] = whoYouWantToSee!.value;
    if (radiusKm != null) data['radius'] = radiusKm;
    if (activeToday != null) data['activeToday'] = activeToday;
    if (ageMin != null) data['ageMin'] = ageMin;
    if (ageMax != null) data['ageMax'] = ageMax;
    return data;
  }

  // Factory to parse from JSON API response
  factory FilterSettings.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse nullable integers from potential pgtype structure
    int? parseInt(dynamic field) {
      if (field is Map &&
          field['Valid'] == true &&
          field['Int32'] != null &&
          field['Int32'] is num) {
        return (field['Int32'] as num).toInt();
      }
      // Handle direct int case if backend sends it sometimes
      if (field is int) return field;
      return null;
    }

    // Helper to safely parse gender preference from potential pgtype structure
    FilterGenderPref? parseGenderPref(dynamic field) {
      if (field is Map &&
          field['Valid'] == true &&
          field['GenderEnum'] != null) {
        return FilterGenderPref.fromValue(field['GenderEnum'] as String?);
      }
      // Handle direct string case
      if (field is String) {
        return FilterGenderPref.fromValue(field);
      }
      return null;
    }

    DateTime? parseDateTime(String? dateString) {
      if (dateString == null) return null;
      try {
        return DateTime.parse(dateString);
      } catch (_) {
        return null; // Return null if parsing fails
      }
    }

    // Adapt the keys ('WhoYouWantToSee', 'RadiusKm', etc.) to match your exact API response structure
    // Use the helpers for nullable fields
    final FilterGenderPref? parsedGender =
        parseGenderPref(json['WhoYouWantToSee']); // Check API response key case
    final int? parsedRadius =
        parseInt(json['RadiusKm']); // Check API response key case
    final int? parsedAgeMin =
        parseInt(json['AgeMin']); // Check API response key case
    final int? parsedAgeMax =
        parseInt(json['AgeMax']); // Check API response key case
    // Assuming 'ActiveToday' is sent as a direct boolean or pgtype.Bool
    final bool? parsedActive = (json['ActiveToday'] is Map &&
            json['ActiveToday']['Valid'] == true)
        ? json['ActiveToday']['Bool'] as bool?
        : (json['ActiveToday'] is bool ? json['ActiveToday'] as bool? : null);

    return FilterSettings(
      userId: json['UserID'], // Assume UserID is directly available
      whoYouWantToSee: parsedGender ??
          FilterSettings.defaultGenderPref, // Fallback to default
      radiusKm: parsedRadius ?? FilterSettings.defaultRadius,
      activeToday: parsedActive ?? FilterSettings.defaultActiveToday,
      ageMin: parsedAgeMin ?? FilterSettings.defaultAgeMin,
      ageMax: parsedAgeMax ?? FilterSettings.defaultAgeMax,
      createdAt: parseDateTime(json['CreatedAt'] as String?),
      updatedAt: parseDateTime(json['UpdatedAt'] as String?),
    );
  }
}
