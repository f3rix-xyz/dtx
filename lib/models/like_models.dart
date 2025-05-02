// File: models/like_models.dart
import 'package:dtx/models/user_model.dart';
import 'package:dtx/utils/app_enums.dart';
// Removed unused riverpod import
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:intl/intl.dart'; // For date formatting if needed

// --- Enums (No Changes) ---
enum ContentLikeType {
  media('media'),
  promptStory('prompt_story'),
  promptMytype('prompt_mytype'),
  promptGettingpersonal('prompt_gettingpersonal'),
  promptDatevibes('prompt_datevibes'),
  audioPrompt('audio_prompt'),
  profile('profile');

  final String value;
  const ContentLikeType(this.value);

  static ContentLikeType? fromValue(String? value) {
    if (value == null) return null;
    try {
      return ContentLikeType.values.firstWhere((e) => e.value == value);
    } catch (e) {
      print("Warning: Unknown ContentLikeType value '$value'");
      return null;
    }
  }
}

enum LikeInteractionType {
  standard('standard'),
  rose('rose');

  final String value;
  const LikeInteractionType(this.value);
  static LikeInteractionType? fromValue(String? value) {
    if (value == null) return null;
    try {
      return LikeInteractionType.values.firstWhere((e) => e.value == value);
    } catch (e) {
      print("Warning: Unknown LikeInteractionType value '$value'");
      return null;
    }
  }
}

// --- Custom Exceptions (No Changes) ---
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
  final String? likeComment;
  final bool isRose;
  final DateTime? likedAt;
  final UserProfileData profile;
  final int likeId; // <<<--- ADDED likeId

  FullProfileLiker({
    required this.likerUserId,
    this.likeComment,
    required this.isRose,
    this.likedAt,
    required this.profile,
    required this.likeId, // <<<--- ADDED to constructor
  });

  factory FullProfileLiker.fromJson(Map<String, dynamic> json) {
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

    bool parseIsRose(dynamic isRoseField, dynamic interactionTypeField) {
      if (isRoseField is bool) {
        return isRoseField;
      }
      return interactionTypeField == LikeInteractionType.rose.value;
    }

    // --- ADDED: Parse likeId ---
    int parseLikeId(dynamic idField) {
      if (idField is int) {
        return idField;
      } else if (idField is String) {
        return int.tryParse(idField) ?? 0;
      }
      if (kDebugMode) {
        print(
            "[FullProfileLiker fromJson] Warning: Could not parse like_id (field: ${idField?.runtimeType}). Defaulting to 0.");
      }
      return 0; // Default or throw error if ID is critical
    }
    // --- END ADDED ---

    return FullProfileLiker(
      likerUserId: json['liker_user_id'] as int? ?? 0,
      likeComment: getComment(json['like_comment']),
      isRose: parseIsRose(json['is_rose'], json['interaction_type']),
      likedAt: parseTimestamp(json['liked_at']),
      profile: UserProfileData.fromJson(
          json['profile'] as Map<String, dynamic>? ?? {}),
      likeId: parseLikeId(json['like_id']), // <<<--- PARSE likeId
    );
  }
}

// Structure for Basic Profile Liker (Matches API Response `other_likers` item)
class BasicProfileLiker {
  final int likerUserId;
  final String name;
  final String? firstProfilePicUrl;
  final String? likeComment;
  final bool isRose;
  final DateTime? likedAt;
  final int likeId; // <<<--- ADDED likeId

  BasicProfileLiker({
    required this.likerUserId,
    required this.name,
    this.firstProfilePicUrl,
    this.likeComment,
    required this.isRose,
    this.likedAt,
    required this.likeId, // <<<--- ADDED to constructor
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
      return '$firstName $lastName'.trim();
    }

    bool parseIsRose(dynamic isRoseField, dynamic interactionTypeField) {
      if (isRoseField is bool) {
        return isRoseField;
      }
      return interactionTypeField == LikeInteractionType.rose.value;
    }

    // --- ADDED: Parse likeId (same helper as above) ---
    int parseLikeId(dynamic idField) {
      if (idField is int) {
        return idField;
      } else if (idField is String) {
        return int.tryParse(idField) ?? 0;
      }
      if (kDebugMode) {
        print(
            "[BasicProfileLiker fromJson] Warning: Could not parse like_id (field: ${idField?.runtimeType}). Defaulting to 0.");
      }
      return 0; // Default or throw error if ID is critical
    }
    // --- END ADDED ---

    return BasicProfileLiker(
      likerUserId: json['liker_user_id'] as int? ?? 0,
      name: buildName(json['name'], json['last_name']),
      firstProfilePicUrl: getPicUrl(json['media_urls']),
      likeComment: getComment(json['like_comment']),
      isRose: parseIsRose(json['is_rose'], json['interaction_type']),
      likedAt: parseTimestamp(json['liked_at']),
      likeId: parseLikeId(json['like_id']), // <<<--- PARSE likeId
    );
  }
}

// Structure for /api/liker-profile response (No changes needed)
class LikeInteractionDetails {
  final String? likeComment;
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

    bool parseIsRose(dynamic isRoseField, dynamic interactionTypeField) {
      if (isRoseField is bool) {
        return isRoseField;
      }
      return interactionTypeField == LikeInteractionType.rose.value;
    }

    return LikeInteractionDetails(
      likeComment: getComment(json['comment']),
      isRose: parseIsRose(json['is_rose'], json['interaction_type']),
    );
  }
}

// UserProfileData class remains unchanged (already defined in user_model.dart or here)
class UserProfileData extends UserModel {
  UserProfileData({
    super.id,
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
    super.mediaChangedDuringEdit,
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    final userModel = UserModel.fromJson(json);
    return UserProfileData(
      id: userModel.id,
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
      mediaChangedDuringEdit: userModel.mediaChangedDuringEdit,
    );
  }
}
