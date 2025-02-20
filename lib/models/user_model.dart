// models/user_model.dart

import 'package:dtx/utils/app_enums.dart';

class Prompt {
  final PromptCategory category;
  final String question;
  final String answer;

  Prompt({
    required this.category,
    required this.question,
    required this.answer,
  });

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'question': question,
        'answer': answer,
      };

  factory Prompt.fromJson(Map<String, dynamic> json) => Prompt(
        category:
            PromptCategory.values.firstWhere((e) => e.name == json['category']),
        question: json['question'],
        answer: json['answer'],
      );
}

class AudioPromptModel {
  final AudioPrompt prompt;
  final String audioUrl;

  AudioPromptModel({
    required this.prompt,
    required this.audioUrl,
  });

  Map<String, dynamic> toJson() => {
        'prompt': prompt.name,
        'audio_url': audioUrl,
      };

  factory AudioPromptModel.fromJson(Map<String, dynamic> json) =>
      AudioPromptModel(
        prompt: AudioPrompt.values.firstWhere((e) => e.name == json['prompt']),
        audioUrl: json['audio_url'],
      );
}

class UserModel {
  final String name;
  final String? lastName;
  final String phoneNumber;
  final DateTime dateOfBirth;
  final double latitude;
  final double longitude;
  final Gender gender;
  final DatingIntention datingIntention;
  final String height;
  final String? hometown;
  final String? jobTitle;
  final String? education;
  final Religion religiousBeliefs;
  final DrinkingSmokingHabits drinkingHabit;
  final DrinkingSmokingHabits smokingHabit;
  final List<String> mediaUrls;
  final List<Prompt> prompts;
  final AudioPromptModel? audioPrompt;

  UserModel({
    required this.name,
    this.lastName,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.latitude,
    required this.longitude,
    required this.gender,
    required this.datingIntention,
    required this.height,
    this.hometown,
    this.jobTitle,
    this.education,
    required this.religiousBeliefs,
    required this.drinkingHabit,
    required this.smokingHabit,
    required this.mediaUrls,
    required this.prompts,
    this.audioPrompt,
  }) {
    // Server-side validations will handle these checks
    /*
    // Phone validation
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phoneNumber)) {
      throw ArgumentError('Phone number must be exactly 10 digits');
    }

    // Media validations
    if (mediaUrls.length < 3) {
      throw ArgumentError('Minimum 3 media files required');
    }
    if (mediaUrls.length > 6) {
      throw ArgumentError('Maximum 6 media files allowed');
    }

    // Prompt validations
    if (prompts.isEmpty) {
      throw ArgumentError('At least 1 prompt is required');
    }
    if (prompts.length > 3) {
      throw ArgumentError('Maximum 3 prompts allowed');
    }

    // Text length validations
    if (hometown != null && hometown!.length > 100) {
      throw ArgumentError('Hometown cannot exceed 100 characters');
    }
    if (jobTitle != null && jobTitle!.length > 30) {
      throw ArgumentError('Job title cannot exceed 30 characters');
    }
    if (education != null && education!.length > 30) {
      throw ArgumentError('Education cannot exceed 30 characters');
    }
    */
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'date_of_birth': dateOfBirth.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'gender': gender.name,
        'dating_intention': datingIntention.name,
        'height': height,
        'hometown': hometown,
        'job_title': jobTitle,
        'education': education,
        'religious_beliefs': religiousBeliefs.name,
        'drinking_habit': drinkingHabit.name,
        'smoking_habit': smokingHabit.name,
        'media_urls': mediaUrls,
        'prompts': prompts.map((prompt) => prompt.toJson()).toList(),
        'audio_prompt': audioPrompt?.toJson(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        name: json['name'],
        lastName: json['last_name'],
        phoneNumber: json['phone_number'],
        dateOfBirth: DateTime.parse(json['date_of_birth']),
        latitude: json['latitude'],
        longitude: json['longitude'],
        gender: Gender.values.firstWhere((e) => e.name == json['gender']),
        datingIntention: DatingIntention.values
            .firstWhere((e) => e.name == json['dating_intention']),
        height: json['height'],
        hometown: json['hometown'],
        jobTitle: json['job_title'],
        education: json['education'],
        religiousBeliefs: Religion.values
            .firstWhere((e) => e.name == json['religious_beliefs']),
        drinkingHabit: DrinkingSmokingHabits.values
            .firstWhere((e) => e.name == json['drinking_habit']),
        smokingHabit: DrinkingSmokingHabits.values
            .firstWhere((e) => e.name == json['smoking_habit']),
        mediaUrls: List<String>.from(json['media_urls']),
        prompts: (json['prompts'] as List)
            .map((prompt) => Prompt.fromJson(prompt))
            .toList(),
        audioPrompt: json['audio_prompt'] != null
            ? AudioPromptModel.fromJson(json['audio_prompt'])
            : null,
      );

  UserModel copyWith({
    String? name,
    String? lastName,
    String? phoneNumber,
    DateTime? dateOfBirth,
    double? latitude,
    double? longitude,
    Gender? gender,
    DatingIntention? datingIntention,
    String? height,
    String? hometown,
    String? jobTitle,
    String? education,
    Religion? religiousBeliefs,
    DrinkingSmokingHabits? drinkingHabit,
    DrinkingSmokingHabits? smokingHabit,
    List<String>? mediaUrls,
    List<Prompt>? prompts,
    AudioPromptModel? audioPrompt,
  }) {
    return UserModel(
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gender: gender ?? this.gender,
      datingIntention: datingIntention ?? this.datingIntention,
      height: height ?? this.height,
      hometown: hometown ?? this.hometown,
      jobTitle: jobTitle ?? this.jobTitle,
      education: education ?? this.education,
      religiousBeliefs: religiousBeliefs ?? this.religiousBeliefs,
      drinkingHabit: drinkingHabit ?? this.drinkingHabit,
      smokingHabit: smokingHabit ?? this.smokingHabit,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      prompts: prompts ?? this.prompts,
      audioPrompt: audioPrompt ?? this.audioPrompt,
    );
  }
}
