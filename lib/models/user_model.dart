// File: lib/models/user_model.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:intl/intl.dart'; // For date formatting if needed
import 'package:dtx/utils/app_enums.dart';

// --- Prompt Class --- (No changes needed)
class Prompt {
  final PromptCategory category;
  final PromptType question;
  final String answer;

  Prompt({
    required this.category,
    required this.question,
    required this.answer,
  });

  Map<String, dynamic> toJson() => {
        'category': category.value,
        'question': question.value,
        'answer': answer,
      };

  factory Prompt.fromJson(Map<String, dynamic> json) {
    PromptCategory category = PromptCategory.values
        .firstWhere((e) => e.value == json['category'], orElse: () {
      print(
          "[Prompt fromJson] Warning: Unknown prompt category '${json['category']}', defaulting to storyTime.");
      return PromptCategory.storyTime;
    });
    PromptType question = PromptType.values
        .firstWhere((e) => e.value == json['question'], orElse: () {
      print(
          "[Prompt fromJson] Warning: Unknown prompt question '${json['question']}' for category '${category.value}', defaulting.");
      List<PromptType> categoryPrompts = category.getPrompts();
      return categoryPrompts.isNotEmpty
          ? categoryPrompts.first
          : PromptType.twoTruthsAndALie;
    });

    return Prompt(
      category: category,
      question: question,
      answer: json['answer'] ?? '',
    );
  }

  Prompt copyWith({String? answer}) {
    return Prompt(
      category: category,
      question: question,
      answer: answer ?? this.answer,
    );
  }

  @override
  String toString() {
    return 'Prompt(question: ${question.label}, answer: $answer)';
  }
}

// --- AudioPromptModel Class --- (No changes needed)
class AudioPromptModel {
  final AudioPrompt prompt;
  final String audioUrl;

  AudioPromptModel({
    required this.prompt,
    required this.audioUrl,
  });

  Map<String, dynamic> toJson() => {
        'question': prompt.value,
        'answer_url': audioUrl,
      };

  factory AudioPromptModel.fromJson(Map<String, dynamic> json) {
    final promptValue =
        json['audio_prompt_question']?['AudioPrompt'] as String?;
    final bool isPromptValid =
        json['audio_prompt_question']?['Valid'] as bool? ?? false;

    if (!isPromptValid || promptValue == null) {
      throw const FormatException(
          'Invalid or missing audio prompt question data in JSON');
    }

    AudioPrompt prompt = AudioPrompt.values
        .firstWhere((e) => e.value == promptValue, orElse: () {
      print(
          "[AudioPromptModel fromJson] Warning: Unknown audio prompt '$promptValue', defaulting to aBoundaryOfMineIs.");
      return AudioPrompt.aBoundaryOfMineIs;
    });

    String? audioUrlValue;
    dynamic answerField = json['audio_prompt_answer'];

    if (answerField is String) {
      audioUrlValue = answerField;
    } else if (answerField is Map) {
      if (answerField['Valid'] == true && answerField['String'] is String) {
        audioUrlValue = answerField['String'] as String;
      }
    }

    if (audioUrlValue == null || audioUrlValue.isEmpty) {
      throw const FormatException(
          'Invalid or missing audio prompt answer data in JSON');
    }

    return AudioPromptModel(
      prompt: prompt,
      audioUrl: audioUrlValue,
    );
  }
}

// --- UserModel Class ---
class UserModel {
  final int? id;
  final String? name;
  final String? lastName;
  final String? phoneNumber;
  final String? email;
  final DateTime? dateOfBirth;
  final double? latitude;
  final double? longitude;
  final Gender? gender;
  final DatingIntention? datingIntention;
  final String? height;
  final String? hometown;
  final String? jobTitle;
  final String? education;
  final Religion? religiousBeliefs;
  final DrinkingSmokingHabits? drinkingHabit;
  final DrinkingSmokingHabits? smokingHabit;
  final List<String>? mediaUrls;
  final List<Prompt> prompts;
  final AudioPromptModel? audioPrompt;
  final String? verificationStatus;
  final String? verificationPic;
  final String? role;
  final bool mediaChangedDuringEdit;
  // --- NEW FIELDS ---
  final bool isOnline; // Directly store bool
  final DateTime? lastOnline; // Store as DateTime?

  UserModel({
    this.id,
    this.name,
    this.lastName,
    this.phoneNumber,
    this.email,
    this.dateOfBirth,
    this.latitude,
    this.longitude,
    this.gender,
    this.datingIntention,
    this.height,
    this.hometown,
    this.jobTitle,
    this.education,
    this.religiousBeliefs,
    this.drinkingHabit,
    this.smokingHabit,
    this.mediaUrls,
    this.prompts = const [],
    this.audioPrompt,
    this.verificationStatus,
    this.verificationPic,
    this.role,
    this.mediaChangedDuringEdit = false,
    // --- INITIALIZE NEW FIELDS ---
    this.isOnline = false, // Default to false
    this.lastOnline,
  });

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'email': email,
        'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
        'latitude': latitude,
        'longitude': longitude,
        'gender': gender?.value,
        'dating_intention': datingIntention?.value,
        'height': height,
        'hometown': hometown,
        'job_title': jobTitle,
        'education': education,
        'religious_beliefs': religiousBeliefs?.value,
        'drinking_habit': drinkingHabit?.value,
        'smoking_habit': smokingHabit?.value,
        'media_urls': mediaUrls,
        'prompts': prompts.map((prompt) => prompt.toJson()).toList(),
        'audio_prompt': audioPrompt?.toJson(),
        'verification_status': verificationStatus,
        'verification_pic': verificationPic,
        'role': role,
        // --- ADD TO JSON (Optional, depends if you ever send this full model back) ---
        'is_online': isOnline,
        'last_online': lastOnline?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toJsonForProfileUpdate() {
    String? formattedDate(DateTime? dt) {
      if (dt == null) return null;
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }

    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    data['last_name'] = lastName ?? "";
    if (dateOfBirth != null) data['date_of_birth'] = formattedDate(dateOfBirth);
    if (datingIntention != null)
      data['dating_intention'] = datingIntention!.value;
    if (height != null) data['height'] = height;
    if (hometown != null) data['hometown'] = hometown;
    if (jobTitle != null) data['job_title'] = jobTitle;
    if (education != null) data['education'] = education;
    if (religiousBeliefs != null)
      data['religious_beliefs'] = religiousBeliefs!.value;
    if (drinkingHabit != null) data['drinking_habit'] = drinkingHabit!.value;
    if (smokingHabit != null) data['smoking_habit'] = smokingHabit!.value;
    if (prompts.isNotEmpty)
      data['prompts'] = prompts.map((p) => p.toJson()).toList();
    return data;
  }

  Map<String, dynamic> toJsonForEdit() {
    final Map<String, dynamic> data = {};
    if (datingIntention != null)
      data['dating_intention'] = datingIntention!.value;
    if (height != null && height!.isNotEmpty) data['height'] = height;
    if (hometown != null && hometown!.isNotEmpty) data['hometown'] = hometown;
    if (jobTitle != null && jobTitle!.isNotEmpty) data['job_title'] = jobTitle;
    if (education != null && education!.isNotEmpty)
      data['education'] = education;
    if (religiousBeliefs != null)
      data['religious_beliefs'] = religiousBeliefs!.value;
    if (drinkingHabit != null) data['drinking_habit'] = drinkingHabit!.value;
    if (smokingHabit != null) data['smoking_habit'] = smokingHabit!.value;
    if (hometown == null) data['hometown'] = null;
    if (jobTitle == null) data['job_title'] = null;
    if (education == null) data['education'] = null;
    data['prompts'] = prompts.map((p) => p.toJson()).toList();
    if (audioPrompt != null) {
      data['audio_prompt'] = audioPrompt!.toJson();
    } else {
      data['audio_prompt'] = null;
    }
    data['media_urls'] = mediaUrls ?? [];
    return data;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print(
          "[UserModel fromJson] START Parsing User ID: ${json['id'] ?? json['ID']}");
    }

    // --- Helper Functions --- (keep existing helpers)
    String? getString(dynamic field) {
      if (field is String) return field.isNotEmpty ? field : null;
      if (field is Map && field['Valid'] == true && field['String'] is String)
        return field['String'];
      if (field is num) return field.toString();
      return null;
    }

    String? getHeight(dynamic field) {
      if (field is String && field.isNotEmpty) return field;
      if (field is Map && field['Valid'] == true && field['String'] is String)
        return field['String'];
      if (field is Map && field['Valid'] == true && field['Float64'] is num) {
        double totalInches = (field['Float64'] as num).toDouble();
        if (totalInches <= 0) return null;
        int feet = (totalInches / 12).floor();
        int inches = (totalInches % 12).round();
        if (inches == 12) {
          feet++;
          inches = 0;
        }
        return "$feet' $inches\"";
      }
      if (field is num) {
        double totalInches = field.toDouble();
        if (totalInches <= 0) return null;
        int feet = (totalInches / 12).floor();
        int inches = (totalInches % 12).round();
        if (inches == 12) {
          feet++;
          inches = 0;
        }
        return "$feet' $inches\"";
      }
      return null;
    }

    String? getEnumString(dynamic field, String key) {
      if (field is String) return field;
      if (field is Map && field['Valid'] == true && field[key] != null)
        return field[key] as String?;
      return null;
    }

    DateTime? getDate(dynamic field) {
      String? dateStr;
      if (field is String) {
        dateStr = field;
      } else if (field is Map &&
          field['Valid'] == true &&
          field['Time'] != null) {
        dateStr = field['Time'] as String?;
      }
      if (dateStr != null) {
        try {
          if (dateStr.contains('T'))
            return DateTime.parse(dateStr.split('T').first).toLocal();
          else if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr))
            return DateTime.parse(dateStr).toLocal();
        } catch (e) {
          print(
              "[UserModel fromJson] Error parsing date: $e, value: '$dateStr'");
        }
      }
      return null;
    }

    double? getDouble(dynamic field) {
      if (field is num) return field.toDouble();
      if (field is Map && field['Valid'] == true && field['Float64'] != null)
        return (field['Float64'] as num?)?.toDouble();
      return null;
    }

    T? parseEnum<T>(List<T> enumValues, dynamic field, String key) {
      final valueStr = getEnumString(field, key);
      if (valueStr != null) {
        for (final enumValue in enumValues) {
          try {
            if ((enumValue as dynamic).value.toString() == valueStr)
              return enumValue;
          } catch (e) {
            if (enumValue.toString().split('.').last == valueStr)
              return enumValue;
          }
        }
        print(
            "[UserModel fromJson] Warning: Enum value '$valueStr' not found in ${T.toString()}. Field: $field");
      }
      return null;
    }

    List<String>? getMediaUrls(dynamic field) {
      if (field is List) {
        final urls = field
            .where((item) => item is String && item.isNotEmpty)
            .map((item) => item as String)
            .toList();
        return urls.isNotEmpty ? urls : null;
      }
      return null;
    }

    int? getId(dynamic idField) {
      if (idField is int) return idField;
      if (idField is String) return int.tryParse(idField);
      if (idField is Map && idField['Valid'] == true) {
        if (idField['Int64'] is num) return (idField['Int64'] as num).toInt();
        if (idField['Int32'] is num) return (idField['Int32'] as num).toInt();
      }
      return null;
    }

    List<Prompt> getPrompts(Map<String, dynamic> json) {
      List<Prompt> parsedPrompts = [];
      final promptsField = json['prompts'];
      if (promptsField is List) {
        for (var promptData in promptsField) {
          if (promptData is Map<String, dynamic>) {
            try {
              final parsedPrompt = Prompt.fromJson(promptData);
              if (parsedPrompt.answer.trim().isNotEmpty)
                parsedPrompts.add(parsedPrompt);
            } catch (e) {
              print(
                  "[UserModel fromJson] Error parsing prompt from list: $e, data: $promptData");
            }
          }
        }
      } else if (promptsField is String) {
        try {
          final List<dynamic> decodedList = jsonDecode(promptsField);
          for (var promptData in decodedList) {
            if (promptData is Map<String, dynamic>) {
              try {
                final parsedPrompt = Prompt.fromJson(promptData);
                if (parsedPrompt.answer.trim().isNotEmpty)
                  parsedPrompts.add(parsedPrompt);
              } catch (e) {
                print(
                    "[UserModel fromJson] Error parsing prompt from JSON string: $e, data: $promptData");
              }
            }
          }
        } catch (e) {
          print(
              "[UserModel fromJson] Error decoding prompts JSON string: $e, value: '$promptsField'");
        }
      }
      return parsedPrompts;
    }

    AudioPromptModel? getAudioPrompt(Map<String, dynamic> json, int? userId) {
      final questionData =
          json['audio_prompt_question'] ?? json['AudioPromptQuestion'];
      final answerData =
          json['audio_prompt_answer'] ?? json['AudioPromptAnswer'];
      bool isQuestionValid = false;
      String? questionValue;
      if (questionData is Map &&
          questionData['Valid'] == true &&
          questionData['AudioPrompt'] is String) {
        questionValue = questionData['AudioPrompt'] as String;
        isQuestionValid = questionValue.isNotEmpty;
      }
      if (!isQuestionValid) return null;
      String? audioUrlValue;
      if (answerData is String && answerData.isNotEmpty) {
        audioUrlValue = answerData;
      } else if (answerData is Map &&
          answerData['Valid'] == true &&
          answerData['String'] is String) {
        audioUrlValue = answerData['String'] as String?;
        if (audioUrlValue != null && audioUrlValue.isEmpty)
          audioUrlValue = null;
      }
      if (audioUrlValue == null) return null;
      try {
        AudioPrompt promptEnum = AudioPrompt.values.firstWhere(
            (e) => e.value == questionValue,
            orElse: () => AudioPrompt.aBoundaryOfMineIs);
        return AudioPromptModel(prompt: promptEnum, audioUrl: audioUrlValue);
      } catch (e) {
        print(
            "[UserModel fromJson getAudioPrompt ID: $userId] Error creating AudioPromptModel: $e");
        return null;
      }
    }

    // --- NEW: Helper for is_online ---
    bool getIsOnline(Map<String, dynamic> json) {
      // Check for Go backend keys first
      final goKey = json['is_online']; // From GetUserByID, SetUserOnline etc.
      final matchKey = json['matched_user_is_online']; // From GetMatches...

      if (goKey is bool) {
        if (kDebugMode)
          print("[UserModel fromJson] getIsOnline: Found bool 'is_online'");
        return goKey;
      }
      if (matchKey is bool) {
        if (kDebugMode)
          print(
              "[UserModel fromJson] getIsOnline: Found bool 'matched_user_is_online'");
        return matchKey;
      }
      // Fallback checks for other potential types
      if (goKey is int) return goKey == 1;
      if (matchKey is int) return matchKey == 1;
      if (goKey is String) return goKey.toLowerCase() == 'true';
      if (matchKey is String) return matchKey.toLowerCase() == 'true';

      if (kDebugMode)
        print(
            "[UserModel fromJson] getIsOnline: Could not parse is_online or matched_user_is_online. Defaulting to false.");
      return false; // Default to false if not found or invalid type
    }
    // --- END NEW HELPER ---

    // --- NEW: Helper for last_online ---
    DateTime? getLastOnline(Map<String, dynamic> json) {
      // Check for Go backend keys first
      final goKeyData = json['last_online'];
      final matchKeyData = json['matched_user_last_online'];

      // Prioritize Go key
      dynamic dataToParse = goKeyData ?? matchKeyData;

      if (dataToParse == null) {
        if (kDebugMode)
          print(
              "[UserModel fromJson] getLastOnline: Both last_online fields are null.");
        return null;
      }

      // Handle pgtype.Timestamptz map structure
      if (dataToParse is Map &&
          dataToParse['Valid'] == true &&
          dataToParse['Time'] != null) {
        final timeStr = dataToParse['Time'] as String?;
        if (timeStr != null) {
          try {
            final parsedTime = DateTime.parse(timeStr).toLocal();
            if (kDebugMode)
              print(
                  "[UserModel fromJson] getLastOnline: Parsed from Map: $parsedTime");
            return parsedTime;
          } catch (e) {
            print(
                "[UserModel fromJson] getLastOnline: Error parsing timestamp from Map: $e, value: '$timeStr'");
          }
        }
      }
      // Handle direct string (ISO 8601)
      else if (dataToParse is String) {
        try {
          final parsedTime = DateTime.parse(dataToParse).toLocal();
          if (kDebugMode)
            print(
                "[UserModel fromJson] getLastOnline: Parsed from String: $parsedTime");
          return parsedTime;
        } catch (e) {
          print(
              "[UserModel fromJson] getLastOnline: Error parsing timestamp from String: $e, value: '$dataToParse'");
        }
      } else {
        if (kDebugMode)
          print(
              "[UserModel fromJson] getLastOnline: Unhandled data type for last_online: ${dataToParse.runtimeType}");
      }

      return null; // Return null if parsing failed or type was unexpected
    }
    // --- END NEW HELPER ---

    // --- Parse using helpers ---
    final int? currentUserId = getId(json['id'] ?? json['ID']);
    if (kDebugMode)
      print("[UserModel fromJson ID: $currentUserId] Parsing core fields...");
    final parsedUser = UserModel(
      id: currentUserId,
      name: getString(json['name'] ?? json['Name']),
      lastName: getString(json['last_name'] ?? json['LastName']),
      email: json['email'] as String? ?? json['Email'] as String?,
      phoneNumber: getString(json['phone_number'] ?? json['PhoneNumber']),
      dateOfBirth: getDate(json['date_of_birth'] ?? json['DateOfBirth']),
      latitude: getDouble(json['latitude'] ?? json['Latitude']),
      longitude: getDouble(json['longitude'] ?? json['Longitude']),
      gender: parseEnum(
          Gender.values, json['gender'] ?? json['Gender'], 'GenderEnum'),
      datingIntention: parseEnum(
          DatingIntention.values,
          json['dating_intention'] ?? json['DatingIntention'],
          'DatingIntention'),
      height: getHeight(json['height'] ?? json['Height']),
      hometown: getString(json['hometown'] ?? json['Hometown']),
      jobTitle: getString(json['job_title'] ?? json['JobTitle']),
      education: getString(json['education'] ?? json['Education']),
      religiousBeliefs: parseEnum(Religion.values,
          json['religious_beliefs'] ?? json['ReligiousBeliefs'], 'Religion'),
      drinkingHabit: parseEnum(
          DrinkingSmokingHabits.values,
          json['drinking_habit'] ?? json['DrinkingHabit'],
          'DrinkingSmokingHabits'),
      smokingHabit: parseEnum(
          DrinkingSmokingHabits.values,
          json['smoking_habit'] ?? json['SmokingHabit'],
          'DrinkingSmokingHabits'),
      mediaUrls: getMediaUrls(json['media_urls'] ?? json['MediaUrls']),
      verificationStatus: json['verification_status'] as String? ??
          json['VerificationStatus'] as String?,
      verificationPic:
          getString(json['verification_pic'] ?? json['VerificationPic']),
      role: json['role'] as String? ?? json['Role'] as String?,
      audioPrompt: getAudioPrompt(json, currentUserId),
      prompts: getPrompts(json),
      // --- PARSE NEW FIELDS ---
      isOnline: getIsOnline(json),
      lastOnline: getLastOnline(json),
    );
    if (kDebugMode) {
      print(
          "[UserModel fromJson ID: $currentUserId] END Parsing. Result: isOnline=${parsedUser.isOnline}, lastOnline=${parsedUser.lastOnline}");
    }

    return parsedUser;
  }

  UserModel copyWith({
    int? Function()? id,
    String? Function()? name,
    String? Function()? lastName,
    String? Function()? phoneNumber,
    String? Function()? email,
    DateTime? Function()? dateOfBirth,
    double? Function()? latitude,
    double? Function()? longitude,
    Gender? Function()? gender,
    DatingIntention? Function()? datingIntention,
    String? Function()? height,
    String? Function()? hometown,
    String? Function()? jobTitle,
    String? Function()? education,
    Religion? Function()? religiousBeliefs,
    DrinkingSmokingHabits? Function()? drinkingHabit,
    DrinkingSmokingHabits? Function()? smokingHabit,
    List<String>? Function()? mediaUrls,
    List<Prompt>? prompts,
    AudioPromptModel? Function()? audioPrompt,
    String? Function()? verificationStatus,
    String? Function()? verificationPic,
    String? Function()? role,
    bool? mediaChangedDuringEdit,
    // --- ADD TO COPYWITH ---
    bool? isOnline,
    DateTime? Function()? lastOnline,
  }) {
    return UserModel(
      id: id != null ? id() : this.id,
      name: name != null ? name() : this.name,
      lastName: lastName != null ? lastName() : this.lastName,
      phoneNumber: phoneNumber != null ? phoneNumber() : this.phoneNumber,
      email: email != null ? email() : this.email,
      dateOfBirth: dateOfBirth != null ? dateOfBirth() : this.dateOfBirth,
      latitude: latitude != null ? latitude() : this.latitude,
      longitude: longitude != null ? longitude() : this.longitude,
      gender: gender != null ? gender() : this.gender,
      datingIntention:
          datingIntention != null ? datingIntention() : this.datingIntention,
      height: height != null ? height() : this.height,
      hometown: hometown != null ? hometown() : this.hometown,
      jobTitle: jobTitle != null ? jobTitle() : this.jobTitle,
      education: education != null ? education() : this.education,
      religiousBeliefs:
          religiousBeliefs != null ? religiousBeliefs() : this.religiousBeliefs,
      drinkingHabit:
          drinkingHabit != null ? drinkingHabit() : this.drinkingHabit,
      smokingHabit: smokingHabit != null ? smokingHabit() : this.smokingHabit,
      mediaUrls: mediaUrls != null ? mediaUrls() : this.mediaUrls,
      prompts: prompts ?? List.from(this.prompts),
      audioPrompt: audioPrompt != null ? audioPrompt() : this.audioPrompt,
      verificationStatus: verificationStatus != null
          ? verificationStatus()
          : this.verificationStatus,
      verificationPic:
          verificationPic != null ? verificationPic() : this.verificationPic,
      role: role != null ? role() : this.role,
      mediaChangedDuringEdit:
          mediaChangedDuringEdit ?? this.mediaChangedDuringEdit,
      // --- ASSIGN IN COPYWITH ---
      isOnline: isOnline ?? this.isOnline,
      lastOnline: lastOnline != null ? lastOnline() : this.lastOnline,
    );
  }

  bool isProfileValid() {
    final dobValid = dateOfBirth != null &&
        DateTime.now().difference(dateOfBirth!).inDays >= (18 * 365.25);
    return name != null &&
        name!.trim().isNotEmpty &&
        name!.trim().length >= 3 &&
        dobValid &&
        datingIntention != null;
  }

  bool isLocationValid() {
    return latitude != null &&
        longitude != null &&
        latitude != 0.0 &&
        longitude != 0.0;
  }
}
