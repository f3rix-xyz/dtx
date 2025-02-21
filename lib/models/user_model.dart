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

  Prompt copyWith({String? answer}) {
    return Prompt(
      category: category,
      question: question,
      answer: answer ?? this.answer,
    );
  }
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
  final String? name;
  final String? lastName;
  final String? phoneNumber;
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

  UserModel({
    this.name,
    this.lastName,
    this.phoneNumber,
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
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'date_of_birth': dateOfBirth?.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'gender': gender?.name,
        'dating_intention': datingIntention?.name,
        'height': height,
        'hometown': hometown,
        'job_title': jobTitle,
        'education': education,
        'religious_beliefs': religiousBeliefs?.name,
        'drinking_habit': drinkingHabit?.name,
        'smoking_habit': smokingHabit?.name,
        'media_urls': mediaUrls,
        'prompts': prompts.map((prompt) => prompt.toJson()).toList(),
        'audio_prompt': audioPrompt?.toJson(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        name: json['name'],
        lastName: json['last_name'],
        phoneNumber: json['phone_number'],
        dateOfBirth: json['date_of_birth'] != null
            ? DateTime.parse(json['date_of_birth'])
            : null,
        latitude: json['latitude'],
        longitude: json['longitude'],
        gender: json['gender'] != null
            ? Gender.values.firstWhere((e) => e.name == json['gender'])
            : null,
        datingIntention: json['dating_intention'] != null
            ? DatingIntention.values
                .firstWhere((e) => e.name == json['dating_intention'])
            : null,
        height: json['height'],
        hometown: json['hometown'],
        jobTitle: json['job_title'],
        education: json['education'],
        religiousBeliefs: json['religious_beliefs'] != null
            ? Religion.values
                .firstWhere((e) => e.name == json['religious_beliefs'])
            : null,
        drinkingHabit: json['drinking_habit'] != null
            ? DrinkingSmokingHabits.values
                .firstWhere((e) => e.name == json['drinking_habit'])
            : null,
        smokingHabit: json['smoking_habit'] != null
            ? DrinkingSmokingHabits.values
                .firstWhere((e) => e.name == json['smoking_habit'])
            : null,
        mediaUrls: json['media_urls'] != null
            ? List<String>.from(json['media_urls'])
            : null,
        prompts: json['prompts'] != null
            ? (json['prompts'] as List)
                .map((prompt) => Prompt.fromJson(prompt))
                .toList()
            : [],
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
      prompts: prompts ?? List.from(this.prompts),
      audioPrompt: audioPrompt ?? this.audioPrompt,
    );
  }
}
