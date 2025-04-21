// File: models/like_models.dart
import 'package:dtx/models/user_model.dart'; // Import UserProfileData definition source
import 'package:dtx/utils/app_enums.dart'; // For GenderEnum if needed
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Only needed if UserProfileData uses Riverpod types directly, unlikely.

// --- Enums (from Phase 8) ---
enum ContentLikeType {
  media('media'),
  promptStory('prompt_story'),
  promptMytype('prompt_mytype'),
  promptGettingpersonal('prompt_gettingpersonal'),
  promptDatevibes('prompt_datevibes'),
  audioPrompt('audio_prompt'),
  profile('profile'); // <<<--- ADDED THIS LINE

  final String value;
  const ContentLikeType(this.value);

  // --- UPDATED fromValue for robustness ---
  static ContentLikeType? fromValue(String? value) {
    if (value == null) return null;
    try {
      // Find the enum value matching the string
      return ContentLikeType.values.firstWhere((e) => e.value == value);
    } catch (e) {
      // Handle cases where the string doesn't match any enum value
      print("Warning: Unknown ContentLikeType value '$value'");
      return null; // Return null if not found
    }
  }
  // --- END UPDATED fromValue ---
}

enum LikeInteractionType {
  standard('standard'),
  rose('rose');

  final String value;
  const LikeInteractionType(this.value);
  static LikeInteractionType? fromValue(String? value) {
    if (value == null) return null;
    try {
      // Added try-catch for robustness
      return LikeInteractionType.values.firstWhere((e) => e.value == value);
    } catch (e) {
      print("Warning: Unknown LikeInteractionType value '$value'");
      return null; // Return null if not found
    }
    // Original: return LikeInteractionType.values.firstWhere((e) => e.value == value, orElse: () => LikeInteractionType.standard);
  }
}

// --- Custom Exceptions (from Phase 8) ---
class LikeLimitExceededException implements Exception {
  final String message;
  LikeLimitExceededException([this.message = 'Daily like limit reached.']);
  @override
  String toString() => message;
}

class InsufficientRosesException implements Exception {
  final String message;
  InsufficientRosesException([this.message = 'You don\'t have enough Roses.']);
  @override
  String toString() => message;
}

// --- Liker Data Structures ---

// Structure for Full Profile Liker (Matches API Response `full_profiles` item)
class FullProfileLiker {
  final int likerUserId;
  final String? likeComment; // Nullable string
  final bool isRose;
  final DateTime? likedAt; // Parsed timestamp
  final UserProfileData profile; // Embedded full profile data

  FullProfileLiker({
    required this.likerUserId,
    this.likeComment,
    required this.isRose,
    this.likedAt,
    required this.profile,
  });

  factory FullProfileLiker.fromJson(Map<String, dynamic> json) {
    DateTime? parseTimestamp(dynamic ts) {
      if (ts is String) {
        try {
          return DateTime.parse(ts).toLocal();
        } catch (_) {} // Parse and convert to local time
      }
      return null;
    }

    // Safely get comment string
    String? getComment(dynamic commentField) {
      if (commentField is Map && commentField['Valid'] == true) {
        return commentField['String'] as String?;
      } else if (commentField is String) {
        // Handle direct string just in case
        return commentField;
      }
      return null;
    }

    // --- UPDATED isRose parsing ---
    bool parseIsRose(dynamic isRoseField, dynamic interactionTypeField) {
      if (isRoseField is bool) {
        return isRoseField; // Prefer direct boolean if present
      }
      // Fallback to checking interaction_type string
      return interactionTypeField == LikeInteractionType.rose.value;
    }
    // --- END UPDATED ---

    return FullProfileLiker(
      likerUserId: json['liker_user_id'] as int? ?? 0,
      likeComment: getComment(json['like_comment']),
      // Use helper to parse isRose
      isRose: parseIsRose(json['is_rose'], json['interaction_type']),
      likedAt: parseTimestamp(json['liked_at']),
      // Assuming 'profile' contains the full UserProfileData structure
      profile: UserProfileData.fromJson(
          json['profile'] as Map<String, dynamic>? ?? {}),
    );
  }
}

// Structure for Basic Profile Liker (Matches API Response `other_likers` item)
class BasicProfileLiker {
  final int likerUserId;
  final String name; // Should ideally always have a name
  final String? firstProfilePicUrl; // Nullable string
  final String? likeComment; // Nullable string
  final bool isRose;
  final DateTime? likedAt; // Parsed timestamp

  BasicProfileLiker({
    required this.likerUserId,
    required this.name,
    this.firstProfilePicUrl,
    this.likeComment,
    required this.isRose,
    this.likedAt,
  });

  factory BasicProfileLiker.fromJson(Map<String, dynamic> json) {
    DateTime? parseTimestamp(dynamic ts) {
      if (ts is String) {
        try {
          return DateTime.parse(ts).toLocal();
        } catch (_) {}
      }
      return null;
    }

    String? getComment(dynamic commentField) {
      if (commentField is Map && commentField['Valid'] == true) {
        return commentField['String'] as String?;
      } else if (commentField is String) {
        return commentField;
      }
      return null;
    }

    String? getPicUrl(dynamic urls) {
      if (urls is List && urls.isNotEmpty && urls[0] is String) {
        return urls[0];
      }
      return null;
    }

    String buildName(dynamic nameField, dynamic lastNameField) {
      String firstName = (nameField is Map && nameField['Valid'] == true)
          ? nameField['String'] ?? ''
          : '';
      String lastName = (lastNameField is Map && lastNameField['Valid'] == true)
          ? lastNameField['String'] ?? ''
          : '';
      return '$firstName $lastName'.trim(); // Combine and trim whitespace
    }

    // --- UPDATED isRose parsing (same as FullProfileLiker) ---
    bool parseIsRose(dynamic isRoseField, dynamic interactionTypeField) {
      if (isRoseField is bool) {
        return isRoseField; // Prefer direct boolean if present
      }
      // Fallback to checking interaction_type string
      return interactionTypeField == LikeInteractionType.rose.value;
    }
    // --- END UPDATED ---

    return BasicProfileLiker(
      likerUserId: json['liker_user_id'] as int? ?? 0,
      name: buildName(json['name'], json['last_name']), // Build name safely
      firstProfilePicUrl: getPicUrl(json['media_urls']), // Get first URL safely
      likeComment: getComment(json['like_comment']),
      // Use helper to parse isRose
      isRose: parseIsRose(json['is_rose'], json['interaction_type']),
      likedAt: parseTimestamp(json['liked_at']),
    );
  }
}

class LikeInteractionDetails {
  final String? likeComment; // Nullable string
  final bool isRose;

  LikeInteractionDetails({
    this.likeComment,
    required this.isRose,
  });

  factory LikeInteractionDetails.fromJson(Map<String, dynamic> json) {
    String? getComment(dynamic commentField) {
      if (commentField is Map && commentField['Valid'] == true) {
        return commentField['String'] as String?;
      } else if (commentField is String) {
        return commentField;
      }
      return null;
    }

    // --- UPDATED isRose parsing (same logic) ---
    bool parseIsRose(dynamic isRoseField, dynamic interactionTypeField) {
      if (isRoseField is bool) {
        return isRoseField; // Prefer direct boolean if present
      }
      // Fallback to checking interaction_type string
      return interactionTypeField == LikeInteractionType.rose.value;
    }
    // --- END UPDATED ---

    return LikeInteractionDetails(
      likeComment: getComment(
          json['comment']), // Assuming key is 'comment' from GetLikeDetailsRow
      // Use helper to parse isRose
      isRose: parseIsRose(json['is_rose'], json['interaction_type']),
    );
  }
}

// --- Placeholder for UserProfileData (ensure consistency) ---
// Re-using UserModel seems appropriate based on current needs
class UserProfileData extends UserModel {
  UserProfileData({
    // Inherit all fields from UserModel
    super.id, // <<< ADDED super.id
    super.name,
    super.lastName,
    super.email,
    super.phoneNumber,
    super.dateOfBirth,
    super.latitude,
    super.longitude,
    super.gender,
    super.datingIntention,
    super.height,
    super.hometown,
    super.jobTitle,
    super.education,
    super.religiousBeliefs,
    super.drinkingHabit,
    super.smokingHabit,
    super.mediaUrls,
    super.prompts = const [],
    super.audioPrompt,
    super.verificationStatus,
    super.verificationPic,
    super.role,
    super.mediaChangedDuringEdit, // <<< ADDED super.mediaChangedDuringEdit
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    // Parse UserModel fields using its factory
    final userModel = UserModel.fromJson(json);

    return UserProfileData(
      id: userModel.id, // Pass id
      name: userModel.name,
      lastName: userModel.lastName,
      email: userModel.email,
      phoneNumber: userModel.phoneNumber,
      dateOfBirth: userModel.dateOfBirth,
      latitude: userModel.latitude,
      longitude: userModel.longitude,
      gender: userModel.gender,
      datingIntention: userModel.datingIntention,
      height: userModel.height,
      hometown: userModel.hometown,
      jobTitle: userModel.jobTitle,
      education: userModel.education,
      religiousBeliefs: userModel.religiousBeliefs,
      drinkingHabit: userModel.drinkingHabit,
      smokingHabit: userModel.smokingHabit,
      mediaUrls: userModel.mediaUrls,
      prompts: userModel.prompts,
      audioPrompt: userModel.audioPrompt,
      verificationStatus: userModel.verificationStatus,
      verificationPic: userModel.verificationPic,
      role: userModel.role,
      mediaChangedDuringEdit: userModel.mediaChangedDuringEdit, // Pass flag
    );
  }
}
