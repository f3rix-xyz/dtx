import 'package:dtx/utils/app_enums.dart';

// --- REMOVED QuickFeedProfile ---

// --- FeedProfile (Kept for potential reuse, but not directly used by HomeScreen anymore) ---
// Consider removing if truly unused later.
class FeedProfile {
  final int id;
  final String? name;
  final String? lastName;
  final DateTime? dateOfBirth;
  final List<String>? mediaUrls;
  final Gender? gender;
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

  String get firstName => name ?? '';

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age < 18 ? null : age;
  }

  String? get firstMediaUrl {
    if (mediaUrls != null &&
        mediaUrls!.isNotEmpty &&
        mediaUrls![0].isNotEmpty) {
      return mediaUrls![0];
    }
    return null;
  }

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
      } else if (dateField is String) {
        // Handle direct string date
        try {
          return DateTime.parse(dateField);
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
      String? genderStr;
      if (genderField is Map &&
          genderField['Valid'] == true &&
          genderField['GenderEnum'] != null) {
        genderStr = genderField['GenderEnum'] as String?;
      } else if (genderField is String) {
        genderStr = genderField;
      }

      if (genderStr != null) {
        if (genderStr == 'man') return Gender.man;
        if (genderStr == 'woman') return Gender.woman;
      }
      return null;
    }

    return FeedProfile(
      id: json['id'] as int? ?? 0,
      name: (json['name'] is Map && json['name']['Valid'])
          ? json['name']['String'] as String?
          : json['name'] as String?, // Handle direct string
      lastName: (json['last_name'] is Map && json['last_name']['Valid'])
          ? json['last_name']['String'] as String?
          : json['last_name'] as String?, // Handle direct string
      dateOfBirth: parseDate(json['date_of_birth']),
      mediaUrls: parseMediaUrls(json['media_urls']),
      gender: parseGender(json['gender']),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}
