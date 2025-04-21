// File: lib/models/user_model.dart
import 'dart:convert';

import 'package:dtx/utils/app_enums.dart';

// --- Prompt Class --- (No changes needed from previous correct version)
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
          "Warning: Unknown prompt category '${json['category']}', defaulting to storyTime.");
      return PromptCategory.storyTime;
    });
    PromptType question = PromptType.values
        .firstWhere((e) => e.value == json['question'], orElse: () {
      print(
          "Warning: Unknown prompt question '${json['question']}' for category '${category.value}', defaulting.");
      // Ensure the default question belongs to the determined category or provide a universal fallback
      List<PromptType> categoryPrompts = category.getPrompts();
      return categoryPrompts.isNotEmpty
          ? categoryPrompts.first // Default to the first prompt of the category
          : PromptType
              .twoTruthsAndALie; // Universal fallback if category has no prompts (shouldn't happen)
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

// --- AudioPromptModel Class --- (No changes needed from previous correct version)
class AudioPromptModel {
  final AudioPrompt prompt;
  final String audioUrl; // Renamed from answer for clarity

  AudioPromptModel({
    required this.prompt,
    required this.audioUrl, // Renamed
  });

  // toJson for PATCH
  Map<String, dynamic> toJson() => {
        'question': prompt.value, // Key expected by PATCH
        'answer_url': audioUrl, // Key expected by PATCH
      };

  factory AudioPromptModel.fromJson(Map<String, dynamic> json) {
    // Parse Question (assuming it's always a map)
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
          "Warning: Unknown audio prompt '$promptValue', defaulting to aBoundaryOfMineIs.");
      return AudioPrompt.aBoundaryOfMineIs;
    });

    // Parse Answer (handle both String and Map)
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
      audioUrl: audioUrlValue, // Use renamed field
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
  final String? height; // Store as string e.g., "5' 11\""
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

  // toJson (General Purpose)
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
        'height': height, // Send height string as is
        'hometown': hometown,
        'job_title': jobTitle,
        'education': education,
        'religious_beliefs': religiousBeliefs?.value,
        'drinking_habit': drinkingHabit?.value,
        'smoking_habit': smokingHabit?.value,
        'media_urls': mediaUrls,
        'prompts': prompts.map((prompt) => prompt.toJson()).toList(),
        'audio_prompt': audioPrompt?.toJson(), // Uses AudioPromptModel's toJson
        'verification_status': verificationStatus,
        'verification_pic': verificationPic,
        'role': role,
      };

  // toJsonForProfileUpdate (For Onboarding Step 2 POST)
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
    if (height != null) data['height'] = height; // Send height string as is
    if (hometown != null) data['hometown'] = hometown;
    if (jobTitle != null) data['job_title'] = jobTitle;
    if (education != null) data['education'] = education;
    if (religiousBeliefs != null)
      data['religious_beliefs'] = religiousBeliefs!.value;
    if (drinkingHabit != null) data['drinking_habit'] = drinkingHabit!.value;
    if (smokingHabit != null) data['smoking_habit'] = smokingHabit!.value;
    if (prompts.isNotEmpty)
      data['prompts'] = prompts.map((p) => p.toJson()).toList();
    // Audio/Media handled separately during onboarding POSTs
    return data;
  }

  // toJsonForEdit (For Profile Edit PATCH)
  Map<String, dynamic> toJsonForEdit() {
    final Map<String, dynamic> data = {};
    // Only include editable fields with values
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

    // Handle optional fields where null means "remove"
    if (hometown == null) data['hometown'] = null;
    if (jobTitle == null) data['job_title'] = null;
    if (education == null) data['education'] = null;

    // Always include prompts (even if empty)
    data['prompts'] = prompts.map((p) => p.toJson()).toList();

    // Handle audio prompt (null to remove)
    if (audioPrompt != null) {
      data['audio_prompt'] = audioPrompt!.toJson();
    } else {
      data['audio_prompt'] = null;
    }

    // Always include media_urls (even if empty after edit)
    data['media_urls'] = mediaUrls ?? [];

    return data;
  }

  // fromJson Factory
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // --- Helper Functions ---
    String? getString(dynamic field) {
      // Handle direct strings first
      if (field is String) {
        return field.isNotEmpty ? field : null;
      }
      // Handle pgtype.Text map structure
      if (field is Map && field['Valid'] == true && field['String'] is String) {
        return field['String'];
      }
      // Handle other types (e.g., if backend sends numbers unexpectedly)
      if (field is num) {
        return field.toString();
      }
      return null; // Default to null if not a valid string or valid pgtype.Text
    }

    String? getHeight(dynamic field) {
      // Prioritize direct string (e.g., "5' 11\"")
      if (field is String && field.isNotEmpty) {
        return field;
      }
      // Handle pgtype.Text for height (might be used if nullable)
      if (field is Map && field['Valid'] == true && field['String'] is String) {
        return field['String'];
      }
      // Handle pgtype.Float8 (inches) - convert TO string format
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
      // Handle direct number (assume inches) - convert TO string format
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
      return null; // Default to null
    }

    String? getEnumString(dynamic field, String key) {
      // Prefer direct string
      if (field is String) {
        return field;
      }
      // Handle pgtype map structure
      if (field is Map && field['Valid'] == true && field[key] != null) {
        return field[key] as String?;
      }
      return null;
    }

    DateTime? getDate(dynamic field) {
      String? dateStr;
      // Prefer direct string
      if (field is String) {
        dateStr = field;
      }
      // Handle pgtype map structure
      else if (field is Map &&
          field['Valid'] == true &&
          field['Time'] != null) {
        dateStr = field['Time'] as String?;
      }

      if (dateStr != null) {
        try {
          // Handle YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ format
          if (dateStr.contains('T')) {
            return DateTime.parse(dateStr.split('T').first).toLocal();
          } else if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
            return DateTime.parse(dateStr).toLocal();
          }
        } catch (e) {
          print("[UserModel fromJson] Error parsing date: $e, value: $field");
        }
      }
      return null;
    }

    double? getDouble(dynamic field) {
      // Prefer direct number
      if (field is num) {
        return field.toDouble();
      }
      // Handle pgtype map structure
      if (field is Map && field['Valid'] == true && field['Float64'] != null) {
        return (field['Float64'] as num?)?.toDouble();
      }
      return null;
    }

    T? parseEnum<T>(List<T> enumValues, dynamic field, String key) {
      final valueStr = getEnumString(field, key);
      if (valueStr != null) {
        for (final enumValue in enumValues) {
          try {
            if ((enumValue as dynamic).value.toString() == valueStr) {
              return enumValue;
            }
          } catch (e) {
            // Fallback for enums without .value (less reliable)
            if (enumValue.toString().split('.').last == valueStr) {
              return enumValue;
            }
          }
        }
        print(
            "[UserModel fromJson] Warning: Enum value '$valueStr' not found in ${T.toString()}.");
      }
      return null;
    }

    List<String>? getMediaUrls(dynamic field) {
      // Expecting a List<String> after repository transformation
      if (field is List) {
        final urls = field
            .where((item) => item is String && item.isNotEmpty)
            .map((item) => item as String)
            .toList();
        return urls.isNotEmpty ? urls : null;
      }
      return null; // Default to null if not a list
    }

    int? getId(dynamic idField) {
      // Prioritize direct int
      if (idField is int) {
        return idField;
      }
      // Handle string representation
      if (idField is String) {
        return int.tryParse(idField);
      }
      // Handle potential pgtype structures if backend might send them
      if (idField is Map && idField['Valid'] == true) {
        if (idField['Int64'] is num) {
          return (idField['Int64'] as num).toInt();
        }
        if (idField['Int32'] is num) {
          return (idField['Int32'] as num).toInt();
        }
      }
      return null; // Default to null
    }

    List<Prompt> getPrompts(Map<String, dynamic> json) {
      List<Prompt> parsedPrompts = [];
      // Expect 'prompts' key based on GetHomeFeedRow and ProfileResponseUser
      final promptsField = json['prompts'];

      if (promptsField is List) {
        // If it's a list (likely from ProfileResponseUser)
        for (var promptData in promptsField) {
          if (promptData is Map<String, dynamic>) {
            try {
              final parsedPrompt = Prompt.fromJson(promptData);
              if (parsedPrompt.answer.trim().isNotEmpty) {
                parsedPrompts.add(parsedPrompt);
              }
            } catch (e) {
              print(
                  "[UserModel fromJson] Error parsing prompt from list: $e, data: $promptData");
            }
          }
        }
      } else if (promptsField is String) {
        // If it's a string (likely JSONB from GetHomeFeedRow)
        try {
          final List<dynamic> decodedList = jsonDecode(promptsField);
          for (var promptData in decodedList) {
            if (promptData is Map<String, dynamic>) {
              try {
                final parsedPrompt = Prompt.fromJson(promptData);
                if (parsedPrompt.answer.trim().isNotEmpty) {
                  parsedPrompts.add(parsedPrompt);
                }
              } catch (e) {
                print(
                    "[UserModel fromJson] Error parsing prompt from JSON string: $e, data: $promptData");
              }
            }
          }
        } catch (e) {
          print(
              "[UserModel fromJson] Error decoding prompts JSON string: $e, value: $promptsField");
        }
      }
      return parsedPrompts;
    }

    AudioPromptModel? getAudioPrompt(Map<String, dynamic> json, int? userId) {
      // Check for potential keys (direct or from pgtype)
      final questionData =
          json['audio_prompt_question'] ?? json['AudioPromptQuestion'];
      final answerData =
          json['audio_prompt_answer'] ?? json['AudioPromptAnswer'];

      // Check Question Validity
      bool isQuestionValid = false;
      String? questionValue;
      if (questionData is Map &&
          questionData['Valid'] == true &&
          questionData['AudioPrompt'] is String) {
        questionValue = questionData['AudioPrompt'] as String;
        isQuestionValid = questionValue.isNotEmpty;
      }

      if (!isQuestionValid) return null;

      // Check Answer Validity
      String? audioUrlValue;
      if (answerData is String && answerData.isNotEmpty) {
        audioUrlValue = answerData;
      } else if (answerData is Map &&
          answerData['Valid'] == true &&
          answerData['String'] is String) {
        audioUrlValue = answerData['String'] as String?;
        if (audioUrlValue != null && audioUrlValue.isEmpty)
          audioUrlValue = null; // Treat empty string as invalid
      }

      if (audioUrlValue == null) return null;

      // If both are valid, create the model
      try {
        AudioPrompt promptEnum = AudioPrompt.values.firstWhere(
            (e) => e.value == questionValue,
            orElse: () => AudioPrompt.aBoundaryOfMineIs // Fallback
            );
        return AudioPromptModel(prompt: promptEnum, audioUrl: audioUrlValue);
      } catch (e) {
        print(
            "[UserModel fromJson getAudioPrompt ID: $userId] Error creating AudioPromptModel: $e");
        return null;
      }
    }

    // --- Parse using helpers ---
    // Primarily use lowercase keys ('id', 'name', 'media_urls') expected after repository transformation
    // Include fallback checks for original backend keys (e.g., 'Name', 'MediaUrls') if needed for other sources
    final int? currentUserId =
        getId(json['id'] ?? json['ID']); // Check 'id' first
    final parsedUser = UserModel(
      id: currentUserId,
      name: getString(json['name'] ?? json['Name']),
      lastName: getString(json['last_name'] ?? json['LastName']),
      email: json['email'] as String? ??
          json['Email'] as String?, // Assuming direct string
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
      mediaUrls: getMediaUrls(
          json['media_urls'] ?? json['MediaUrls']), // Check 'media_urls' first
      verificationStatus: json['verification_status'] as String? ??
          json['VerificationStatus'] as String?,
      verificationPic:
          getString(json['verification_pic'] ?? json['VerificationPic']),
      role: json['role'] as String? ?? json['Role'] as String?,
      audioPrompt: getAudioPrompt(json, currentUserId),
      prompts: getPrompts(json), // Use the combined prompt parsing
    );

    return parsedUser;
  }

  // copyWith method
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
      prompts: prompts ?? List.from(this.prompts), // Ensure deep copy if needed
      audioPrompt: audioPrompt != null ? audioPrompt() : this.audioPrompt,
      verificationStatus: verificationStatus != null
          ? verificationStatus()
          : this.verificationStatus,
      verificationPic:
          verificationPic != null ? verificationPic() : this.verificationPic,
      role: role != null ? role() : this.role,
      mediaChangedDuringEdit:
          mediaChangedDuringEdit ?? this.mediaChangedDuringEdit,
    );
  }

  // isProfileValid for onboarding step 2 POST
  bool isProfileValid() {
    final dobValid = dateOfBirth != null &&
        DateTime.now().difference(dateOfBirth!).inDays >= (18 * 365.25);
    return name != null &&
        name!.trim().isNotEmpty &&
        name!.trim().length >= 3 &&
        dobValid &&
        datingIntention != null;
  }

  // isLocationValid (used in onboarding step 1)
  bool isLocationValid() {
    return latitude != null &&
        longitude != null &&
        latitude != 0.0 &&
        longitude != 0.0;
  }
}
