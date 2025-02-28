
// File: repositories/user_repository.dart
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/token_storage.dart';

class UserRepository {
  final ApiService _apiService;
  
  UserRepository(this._apiService);
  
// File: repositories/user_repository.dart (update)
// File: repositories/user_repository.dart (update)
Future<bool> updateProfile(UserModel userModel) async {
  try {
    // Get the saved token
    final token = await TokenStorage.getToken();
    
    if (token == null || token.isEmpty) {
      throw ApiException('Authentication token is missing');
    }
    
    // Create auth headers
    final headers = {
      'Authorization': 'Bearer $token',
    };
    
    // Format date of birth correctly (YYYY-MM-DD format without time)
    String? formattedDateOfBirth;
    if (userModel.dateOfBirth != null) {
      final dob = userModel.dateOfBirth!;
      formattedDateOfBirth = "${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}";
    }
    
    // Format height correctly (remove space after apostrophe)
    String? formattedHeight;
    if (userModel.height != null) {
      // Replace "X' Y\"" with "X'Y\"" (remove space after apostrophe)
      formattedHeight = userModel.height!.replaceAll("' ", "'");
    }
    
    // Convert UserModel to API request format
    final Map<String, dynamic> requestBody = {
      'name': userModel.name,
      'last_name': userModel.lastName ?? '',
      'date_of_birth': formattedDateOfBirth,
      'latitude': userModel.latitude,
      'longitude': userModel.longitude,
      'gender': userModel.gender?.name,
      'dating_intention': userModel.datingIntention?.name,
      'height': formattedHeight,
      'hometown': userModel.hometown,
      'job_title': userModel.jobTitle,
      'education': userModel.education,
      'religious_beliefs': userModel.religiousBeliefs?.name,
      'drinking_habit': userModel.drinkingHabit?.name,
      'smoking_habit': userModel.smokingHabit?.name,
      'prompts': userModel.prompts.map((prompt) => {
        'category': prompt.category.value,
        'question': prompt.question.value,
        'answer': prompt.answer,
      }).toList(),
    };
    
    // Make the API request
    final response = await _apiService.post(
      '/api/profile',
      body: requestBody,
      headers: headers,
    );
    
    return response['success'] == true;
  } on ApiException {
    rethrow;
  } catch (e) {
    throw ApiException('Failed to update profile: ${e.toString()}');
  }
}

Future<UserModel> fetchUserProfile() async {
    try {
      // Get the saved token
      final token = await TokenStorage.getToken();
      
      if (token == null || token.isEmpty) {
        throw ApiException('Authentication token is missing');
      }
      
      // Create auth headers
      final headers = {
        'Authorization': 'Bearer $token',
      };
      
      // Make the API request
      final response = await _apiService.get(
        '/get-profile',
        headers: headers,
      );
      
      if (response['success'] == true && response['user'] != null) {
        return UserModel.fromJson(response['user']);
      } else {
        throw ApiException('Failed to fetch user profile');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error fetching user profile: ${e.toString()}');
    }
  }

}
