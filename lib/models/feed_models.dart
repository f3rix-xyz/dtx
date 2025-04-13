// File: models/feed_models.dart
import 'package:dtx/utils/app_enums.dart'; // For GenderEnum if needed

// --- Base Profile Info (Common fields) ---
// We can reuse UserModel partially, but separate models might be cleaner
// for feed-specific data like distance. Let's define simple ones for now.

class FeedProfile {
  final int id;
  final String? name; // Use String? for null safety
  final String? lastName;
  final DateTime? dateOfBirth;
  final List<String>? mediaUrls;
  final Gender? gender; // Use Gender enum
  // Add other fields displayed on cards if necessary
  final double? distanceKm;

  FeedProfile({
    required this.id,
    this.name,
    this.lastName,
    this.dateOfBirth,
    this.mediaUrls,
    this.gender,
    this.distanceKm,
  });

  // Helper to get the first name safely
  String get firstName => name ?? '';

  // Helper to calculate age
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age < 18 ? null : age; // Return null if under 18 or dob invalid
  }

  // Helper to get the first media URL safely
  String? get firstMediaUrl {
    if (mediaUrls != null &&
        mediaUrls!.isNotEmpty &&
        mediaUrls![0].isNotEmpty) {
      return mediaUrls![0];
    }
    return null;
  }

  // Factory constructor to parse common fields from API response map
  // Note: Backend uses pgtype which marshals to {"Type": value, "Valid": bool}
  factory FeedProfile.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic dateField) {
      if (dateField is Map &&
          dateField['Valid'] == true &&
          dateField['Time'] != null) {
        try {
          return DateTime.parse(dateField['Time'] as String);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    List<String>? parseMediaUrls(dynamic urls) {
      if (urls is List) {
        return List<String>.from(
            urls.where((item) => item is String && item.isNotEmpty));
      }
      return null;
    }

    Gender? parseGender(dynamic genderField) {
      if (genderField is Map &&
          genderField['Valid'] == true &&
          genderField['GenderEnum'] != null) {
        final genderStr = genderField['GenderEnum'] as String;
        if (genderStr == 'man') return Gender.man;
        if (genderStr == 'woman') return Gender.woman;
      }
      return null;
    }

    return FeedProfile(
      id: json['id'] as int? ?? 0, // Provide default or handle error
      name: (json['name'] is Map && json['name']['Valid'])
          ? json['name']['String'] as String?
          : null,
      lastName: (json['last_name'] is Map && json['last_name']['Valid'])
          ? json['last_name']['String'] as String?
          : null,
      dateOfBirth: parseDate(json['date_of_birth']),
      mediaUrls: parseMediaUrls(json['media_urls']),
      gender: parseGender(json['gender']),
      distanceKm:
          (json['distance_km'] as num?)?.toDouble(), // Safely cast distance
    );
  }
}

// --- Quick Feed Specific Model ---
// Can inherit or compose if more fields are needed later
class QuickFeedProfile extends FeedProfile {
  // Add any fields specific to QuickFeedRow if they exist
  // Currently, it seems GetQuickFeedRow in Go just returns User + distance_km

  QuickFeedProfile({
    required super.id,
    super.name,
    super.lastName,
    super.dateOfBirth,
    super.mediaUrls,
    super.gender,
    super.distanceKm,
  });

  // Factory to create from the specific API response structure
  // Assuming GetQuickFeedRow directly maps to FeedProfile fields
  factory QuickFeedProfile.fromJson(Map<String, dynamic> json) {
    // Directly use the base FeedProfile parser
    return QuickFeedProfile(
      id: json['id'] as int? ?? 0,
      name: (json['name'] is Map && json['name']['Valid'])
          ? json['name']['String'] as String?
          : null,
      lastName: (json['last_name'] is Map && json['last_name']['Valid'])
          ? json['last_name']['String'] as String?
          : null,
      dateOfBirth: FeedProfile.fromJson(json)
          .dateOfBirth, // Reuse base parsing logic for date
      mediaUrls:
          FeedProfile.fromJson(json).mediaUrls, // Reuse base parsing logic
      gender: FeedProfile.fromJson(json).gender, // Reuse base parsing logic
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}

// --- Home Feed Specific Model ---
class HomeFeedProfile extends FeedProfile {
  // Add other fields returned by GetHomeFeedRow if needed (e.g., prompts, full details)
  // For now, it seems GetHomeFeedRow also just returns User + distance_km
  // If you need prompts etc., add them here and update the factory.

  HomeFeedProfile({
    required super.id,
    super.name,
    super.lastName,
    super.dateOfBirth,
    super.mediaUrls,
    super.gender,
    super.distanceKm,
    // Add other fields here
  });

  // Factory to create from the specific API response structure
  // Assuming GetHomeFeedRow directly maps to FeedProfile fields
  factory HomeFeedProfile.fromJson(Map<String, dynamic> json) {
    // Directly use the base FeedProfile parser
    return HomeFeedProfile(
      id: json['id'] as int? ?? 0,
      name: (json['name'] is Map && json['name']['Valid'])
          ? json['name']['String'] as String?
          : null,
      lastName: (json['last_name'] is Map && json['last_name']['Valid'])
          ? json['last_name']['String'] as String?
          : null,
      dateOfBirth: FeedProfile.fromJson(json)
          .dateOfBirth, // Reuse base parsing logic for date
      mediaUrls:
          FeedProfile.fromJson(json).mediaUrls, // Reuse base parsing logic
      gender: FeedProfile.fromJson(json).gender, // Reuse base parsing logic
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}
