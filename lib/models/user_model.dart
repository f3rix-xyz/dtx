// File: lib/models/user_model.dart
import 'package:dtx/utils/app_enums.dart';
// No need for 'dart:convert' import here unless used elsewhere in this specific file

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
          "Warning: Unknown prompt category '${json['category']}', defaulting to storyTime.");
      return PromptCategory.storyTime;
    });
    PromptType question = PromptType.values
        .firstWhere((e) => e.value == json['question'], orElse: () {
      print(
          "Warning: Unknown prompt question '${json['question']}' for category '${category.value}', defaulting.");
      return category.getPrompts().isNotEmpty
          ? category.getPrompts().first
          : PromptType.twoTruthsAndALie; // A fallback default
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
  final String audioUrl; // Renamed from answer for clarity

  AudioPromptModel({
    required this.prompt,
    required this.audioUrl, // Renamed
  });

  // --- UPDATED toJson for PATCH ---
  Map<String, dynamic> toJson() => {
        'question': prompt.value, // Key expected by PATCH
        'answer_url': audioUrl, // Key expected by PATCH
      };
  // --- END UPDATED toJson ---

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
  // --- NEW: Internal flag for media changes ---
  final bool mediaChangedDuringEdit; // Track if media screen was edited

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
    this.mediaChangedDuringEdit = false, // Default to false
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

  // toJson remains the same (might be useful for other things)
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
        // Use AudioPromptModel's toJson which is now formatted for PATCH
        'audio_prompt': audioPrompt?.toJson(),
        'verification_status': verificationStatus,
        'verification_pic': verificationPic,
        'role': role,
      };

  // toJsonForProfileUpdate remains the same (for onboarding step 2 POST)
  Map<String, dynamic> toJsonForProfileUpdate() {
    String? formattedDate(DateTime? dt) {
      if (dt == null) return null;
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }

    String? formattedHeight(String? h) {
      // Height format conversion is likely handled by the backend on POST
      // but we can keep the frontend format consistent if needed.
      return h?.replaceAll("' ", "'"); // Example: ensure single space
    }

    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    data['last_name'] = lastName ?? ""; // Send empty string if null for POST
    if (dateOfBirth != null) data['date_of_birth'] = formattedDate(dateOfBirth);
    if (datingIntention != null)
      data['dating_intention'] = datingIntention!.value;
    if (height != null) data['height'] = formattedHeight(height);
    if (hometown != null) data['hometown'] = hometown;
    if (jobTitle != null) data['job_title'] = jobTitle;
    if (education != null) data['education'] = education;
    if (religiousBeliefs != null)
      data['religious_beliefs'] = religiousBeliefs!.value;
    if (drinkingHabit != null) data['drinking_habit'] = drinkingHabit!.value;
    if (smokingHabit != null) data['smoking_habit'] = smokingHabit!.value;
    if (prompts.isNotEmpty)
      data['prompts'] = prompts.map((p) => p.toJson()).toList();
    // Note: Audio prompt and media are handled by separate endpoints during initial onboarding POSTs
    return data;
  }

  // --- NEW: toJsonForEdit for PATCH request ---
  Map<String, dynamic> toJsonForEdit() {
    String? formattedHeight(String? h) {
      // Apply formatting consistent with API expectation if needed
      return h?.replaceAll("' ", "'"); // Example
    }

    final Map<String, dynamic> data = {};
    // --- ONLY include fields that are editable and have values ---
    // Non-editable: name, last_name, dob, gender, location
    if (datingIntention != null)
      data['dating_intention'] = datingIntention!.value;
    if (height != null && height!.isNotEmpty)
      data['height'] = formattedHeight(height);
    if (hometown != null && hometown!.isNotEmpty) data['hometown'] = hometown;
    if (jobTitle != null && jobTitle!.isNotEmpty) data['job_title'] = jobTitle;
    if (education != null && education!.isNotEmpty)
      data['education'] = education;
    if (religiousBeliefs != null)
      data['religious_beliefs'] = religiousBeliefs!.value;
    if (drinkingHabit != null) data['drinking_habit'] = drinkingHabit!.value;
    if (smokingHabit != null) data['smoking_habit'] = smokingHabit!.value;

    // Handle optional fields where null means "remove"
    if (hometown == null)
      data['hometown'] = null; // Explicitly set to null if cleared
    if (jobTitle == null) data['job_title'] = null;
    if (education == null) data['education'] = null;

    // Always include prompts, even if empty, to allow removal
    data['prompts'] = prompts.map((p) => p.toJson()).toList();

    // Include audio_prompt only if it exists
    if (audioPrompt != null) {
      data['audio_prompt'] = audioPrompt!.toJson(); // Uses the corrected toJson
    } else {
      // To remove audio prompt, explicitly send null
      data['audio_prompt'] = null;
    }

    // Always include media_urls (even if empty after edit)
    data['media_urls'] = mediaUrls ?? [];

    return data;
  }
  // --- END NEW ---

  // fromJson remains the same
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // --- Helper Functions ---
    String? getString(dynamic field) {
      if (field is Map && field['Valid'] == true && field['String'] != null) {
        return field['String'] as String?;
      } else if (field is String) {
        return field;
      } else if (field is int || field is double) {
        return field.toString();
      }
      return null;
    }

    String? getHeight(dynamic field) {
      if (field is Map && field['Valid'] == true && field['String'] != null) {
        return field['String'] as String?;
      } else if (field is String) {
        // Backend might send "5' 11\"" or "5'11\""
        return field.replaceAll("' ",
            "'"); // Standardize to single space or no space? Check API doc.
      } else if (field is int || field is double) {
        // Convert cm/inches if backend sends numeric height sometimes
        double totalInches = (field as num) * 0.393701;
        int feet = (totalInches / 12).floor();
        int inches = (totalInches % 12).round();
        if (inches == 12) {
          feet++;
          inches = 0;
        }
        return "$feet' $inches\""; // Ensure this format matches API exactly
      }
      return null;
    }

    String? getEnumString(dynamic field, String key) {
      if (field is Map && field['Valid'] == true && field[key] != null) {
        return field[key] as String?;
      } else if (field is String) {
        // Handle direct string enums
        return field;
      }
      return null;
    }

    DateTime? getDate(dynamic field) {
      String? dateStr;
      if (field is Map && field['Valid'] == true && field['Time'] != null) {
        dateStr = field['Time'] as String?;
      } else if (field is String) {
        dateStr = field;
      }
      if (dateStr != null) {
        try {
          if (dateStr.contains('T')) {
            return DateTime.parse(dateStr.split('T').first);
          } else if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
            return DateTime.parse(dateStr);
          }
        } catch (e) {
          print("Error parsing date: $e, value: $field");
        }
      }
      return null;
    }

    double? getDouble(dynamic field) {
      if (field is Map && field['Valid'] == true && field['Float64'] != null) {
        return (field['Float64'] as num?)?.toDouble();
      } else if (field is num) {
        return field.toDouble();
      }
      return null;
    }

    T? parseEnum<T>(List<T> enumValues, dynamic field, String key) {
      // Use getEnumString which handles both map and direct string
      final valueStr = getEnumString(field, key);
      if (valueStr != null) {
        for (final enumValue in enumValues) {
          try {
            // Assuming enums have a '.value' getter holding the string representation
            if ((enumValue as dynamic).value.toString() == valueStr) {
              return enumValue;
            }
          } catch (e) {
            // This catch block is tricky if enums don't uniformly have '.value'
            // Consider a more robust mapping if enums are inconsistent.
            // print("Error accessing '.value' for enum ${T.toString()} (value: $valueStr): $e");
            // Fallback: Check toString() representation (less reliable)
            if (enumValue.toString().split('.').last == valueStr) {
              // print("Fallback enum match using toString() for $valueStr");
              return enumValue;
            }
          }
        }
        print("Warning: Enum value '$valueStr' not found in ${T.toString()}.");
        return null;
      }
      return null;
    }

    List<String>? getMediaUrls(dynamic field) {
      if (field is List<dynamic>) {
        final urls = field
            .where((item) => item is String && item.isNotEmpty)
            .map((item) => item as String)
            .toList();
        return urls.isNotEmpty ? urls : null;
      } else if (field is List<String>) {
        // Handle case where it's already List<String>
        return field.where((s) => s.isNotEmpty).toList().isNotEmpty
            ? field
            : null;
      }
      return null;
    }

    int? getId(dynamic idField) {
      if (idField is int) {
        return idField;
      }
      if (idField is String) {
        return int.tryParse(idField);
      }
      if (idField is Map &&
          idField['Valid'] == true &&
          idField['Int64'] != null) {
        if (idField['Int64'] is num) {
          return (idField['Int64'] as num).toInt();
        }
      }
      return null;
    }

    List<Prompt> getPrompts(Map<String, dynamic> json) {
      List<Prompt> parsedPrompts = [];
      if (json['prompts'] is List) {
        final List<dynamic> promptList = json['prompts'];
        for (var promptData in promptList) {
          if (promptData is Map<String, dynamic>) {
            try {
              final parsedPrompt = Prompt.fromJson(promptData);
              // Ensure answer is not just whitespace before adding
              if (parsedPrompt.answer.trim().isNotEmpty) {
                parsedPrompts.add(parsedPrompt);
              } else {
                print(
                    "[UserModel fromJson] Skipping prompt with empty answer: ${promptData['question']}");
              }
            } catch (e) {
              print(
                  "[UserModel fromJson] Error parsing prompt: $e, data: $promptData");
            }
          }
        }
      }
      // API allows max 3, but frontend should handle this limit upstream.
      // Here we just parse what's given.
      return parsedPrompts;
    }

    // --- REVISED getAudioPrompt Helper ---
    AudioPromptModel? getAudioPrompt(Map<String, dynamic> json, int? userId) {
      final questionData =
          json['AudioPromptQuestion'] ?? json['audio_prompt_question'];
      final answerData =
          json['AudioPromptAnswer'] ?? json['audio_prompt_answer'];

      // 1. Check Question Validity
      bool isQuestionValid = questionData is Map &&
          questionData['Valid'] == true &&
          questionData['AudioPrompt'] is String &&
          (questionData['AudioPrompt'] as String).isNotEmpty;

      if (!isQuestionValid) return null; // No valid question, no audio prompt

      // 2. Check Answer Validity (String or Valid Map with non-empty String)
      String? audioUrlValue;
      if (answerData is String && answerData.isNotEmpty) {
        audioUrlValue = answerData;
      } else if (answerData is Map &&
          answerData['Valid'] == true &&
          answerData['String'] is String &&
          (answerData['String'] as String).isNotEmpty) {
        audioUrlValue = answerData['String'] as String;
      }

      if (audioUrlValue == null)
        return null; // No valid answer, no audio prompt

      // 3. If BOTH are valid, attempt to create the model using the Factory
      try {
        // The factory now handles the map structure directly
        return AudioPromptModel.fromJson({
          'audio_prompt_question': questionData,
          'audio_prompt_answer': answerData,
        });
      } catch (e) {
        print(
            "[UserModel fromJson getAudioPrompt ID: $userId] Error creating AudioPromptModel: $e");
        print(" -> Question Data: $questionData");
        print(" -> Answer Data: $answerData");
        return null;
      }
    }
    // --- END REVISED getAudioPrompt Helper ---

    // --- Parse using helpers ---
    final int? currentUserId =
        getId(json['id'] ?? json['ID']); // Get ID for logging
    final parsedUser = UserModel(
      id: currentUserId, // Use the extracted ID
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
      audioPrompt: getAudioPrompt(json, currentUserId), // Pass ID to helper
      prompts: getPrompts(json),
    );

    // Remove debug print unless needed
    // print("--- Parsed UserModel (Audio Prompt Check) ---");
    // print("ID: ${parsedUser.id}");
    // print("Name: ${parsedUser.name}");
    // print("Audio Prompt Parsed: ${parsedUser.audioPrompt != null}");
    // if (parsedUser.audioPrompt != null) {
    //   print("  -> Question: ${parsedUser.audioPrompt!.prompt.label}");
    //   print("  -> URL: ${parsedUser.audioPrompt!.audioUrl}");
    // }
    // print("------------------------------------------");

    return parsedUser;
  }

  // copyWith needs update for mediaChangedDuringEdit
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
    bool? mediaChangedDuringEdit, // <<< ADDED parameter
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
      // Pass the value or use existing
      mediaChangedDuringEdit:
          mediaChangedDuringEdit ?? this.mediaChangedDuringEdit,
    );
  }

  // isProfileValid for onboarding step 2 POST
  bool isProfileValid() {
    final dobValid = dateOfBirth != null &&
        DateTime.now().difference(dateOfBirth!).inDays >= (18 * 365.25);
    // Location/Gender validation is handled in onboarding step 1
    return name != null &&
        name!.trim().isNotEmpty &&
        name!.trim().length >= 3 &&
        dobValid &&
        datingIntention != null; // Added dating intention check for step 2
    // Removed location/gender check here as it's handled earlier
  }

  // isLocationValid remains the same (used in onboarding step 1)
  bool isLocationValid() {
    return latitude != null &&
        longitude != null &&
        latitude != 0.0 &&
        longitude != 0.0;
  }
}
