// File: lib/models/user_model.dart
import 'package:dtx/utils/app_enums.dart';
// No need for 'dart:convert' import here unless used elsewhere in this specific file

// --- Prompt Class ---
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

// --- AudioPromptModel Class ---
class AudioPromptModel {
  final AudioPrompt prompt;
  final String audioUrl;

  AudioPromptModel({
    required this.prompt,
    required this.audioUrl,
  });

  Map<String, dynamic> toJson() => {
        'prompt': prompt.value,
        'audio_url': audioUrl,
      };

  factory AudioPromptModel.fromJson(Map<String, dynamic> json) {
    final promptValue =
        json['audio_prompt_question']?['AudioPrompt'] as String?;
    final audioUrlValue = json['audio_prompt_answer']?['String'] as String?;
    final bool isPromptValid =
        json['audio_prompt_question']?['Valid'] as bool? ?? false;
    final bool isUrlValid =
        json['audio_prompt_answer']?['Valid'] as bool? ?? false;

    if (!isPromptValid ||
        !isUrlValid ||
        promptValue == null ||
        audioUrlValue == null) {
      throw const FormatException(
          'Invalid or missing audio prompt data in JSON');
    }

    AudioPrompt prompt = AudioPrompt.values
        .firstWhere((e) => e.value == promptValue, orElse: () {
      print("Warning: Unknown audio prompt '$promptValue', defaulting.");
      return AudioPrompt.aBoundaryOfMineIs;
    });

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
  final String? height; // Keep as String for formatted value
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
        'height': height, // Send formatted string back if needed
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
      };

  Map<String, dynamic> toJsonForProfileUpdate() {
    String? formattedDate(DateTime? dt) {
      if (dt == null) return null;
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }

    // Height might need conversion back to number/specific format if backend expects it
    String? formattedHeight(String? h) {
      // Example: Convert "5' 10\"" back to inches or cm if needed
      // Or just send the string if backend accepts it
      return h?.replaceAll("' ", "'"); // Basic cleanup
    }

    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    data['last_name'] = lastName ?? "";
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
    // Audio prompt is updated separately

    return data;
  }

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
        return field;
      } else if (field is int || field is double) {
        double totalInches = (field as num) * 0.393701;
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
      if (field is Map && field['Valid'] == true && field[key] != null) {
        return field[key] as String?;
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
      final valueStr = getEnumString(field, key);
      if (valueStr != null) {
        for (final enumValue in enumValues) {
          try {
            if ((enumValue as dynamic).value.toString() == valueStr) {
              return enumValue;
            }
          } catch (e) {
            print("Error accessing '.value' for enum ${T.toString()}: $e");
          }
        }
        print(
            "Warning: Enum value '$valueStr' not found in ${T.toString()}. Returning null.");
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
        return field.isNotEmpty ? field : null;
      }
      return null;
    }

    AudioPromptModel? getAudioPrompt(Map<String, dynamic> json) {
      if (json['audio_prompt_question'] is Map &&
          json['audio_prompt_answer'] is Map) {
        try {
          return AudioPromptModel.fromJson(json);
        } catch (e) {
          /* print("Error parsing AudioPrompt: $e"); */ return null;
        }
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

    // --- *** UPDATED getPrompts Helper *** ---
    List<Prompt> getPrompts(Map<String, dynamic> json) {
      List<Prompt> parsedPrompts = [];
      // **Primary Check:** Look for the unified 'prompts' array first
      if (json['prompts'] is List) {
        final List<dynamic> promptList = json['prompts'];
        print(
            "[UserModel fromJson] Parsing prompts from unified 'prompts' field: ${promptList.length} items");
        for (var promptData in promptList) {
          if (promptData is Map<String, dynamic>) {
            try {
              final parsedPrompt = Prompt.fromJson(promptData);
              if (parsedPrompt.answer.trim().isNotEmpty) {
                parsedPrompts.add(parsedPrompt);
              } else {
                print(
                    "[UserModel fromJson] Parsed prompt from unified list has empty answer: $promptData");
              }
            } catch (e) {
              print(
                  "[UserModel fromJson] Error parsing prompt from unified list: $e, data: $promptData");
            }
          } else {
            print(
                "[UserModel fromJson] Item in unified 'prompts' is not a Map: $promptData");
          }
        }
        print(
            "[UserModel fromJson] Finished parsing from unified 'prompts'. Count: ${parsedPrompts.length}");
      } else {
        print(
            "[UserModel fromJson] Unified 'prompts' field not found or not a List.");
        // Fallback logic removed assuming backend consistency
      }
      return parsedPrompts;
    }
    // --- *** END UPDATED getPrompts Helper *** ---

    // --- Parse using helpers ---
    final parsedUser = UserModel(
      id: getId(json['id'] ?? json['ID']), // Check both cases for robustness
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
      height:
          getHeight(json['height'] ?? json['Height']), // Use specific helper
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
      audioPrompt: getAudioPrompt(json),
      prompts: getPrompts(json), // Use updated helper
    );

    // --- DEBUGGING Print (keep temporarily) ---
    print("--- Parsed UserModel (After Prompt Fix v2) ---");
    print("ID: ${parsedUser.id}");
    print("Name: ${parsedUser.name}");
    print("Media URLs: ${parsedUser.mediaUrls}");
    print("Prompts Count: ${parsedUser.prompts.length}"); // Crucial check
    if (parsedUser.prompts.isNotEmpty) {
      print("First Prompt Q: ${parsedUser.prompts[0].question.label}");
    }
    print("Audio Prompt: ${parsedUser.audioPrompt != null}");
    print("------------------------------------------");
    // --- END DEBUGGING ---

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
    );
  }

  bool isProfileValid() {
    final dobValid = dateOfBirth != null &&
        DateTime.now().difference(dateOfBirth!).inDays >= (18 * 365.25);
    return name != null &&
        name!.trim().isNotEmpty &&
        name!.trim().length >= 3 &&
        dobValid &&
        gender != null &&
        datingIntention != null &&
        isLocationValid();
  }

  bool isLocationValid() {
    return latitude != null &&
        longitude != null &&
        latitude != 0.0 &&
        longitude != 0.0;
  }
}
