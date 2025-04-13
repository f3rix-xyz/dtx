// File: repositories/user_repository.dart
import '../models/feed_models.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/token_storage.dart';
import '../utils/app_enums.dart';

class UserRepository {
  final ApiService _apiService;

  UserRepository(this._apiService);

  // Method to update location and gender (from Phase 3)
  Future<bool> updateLocationGender(
      double lat, double lon, Gender gender) async {
    // ... (Implementation from Phase 3, no changes here) ...
    final String methodName = 'updateLocationGender';
    print(
        '[UserRepository $methodName] Called with lat: $lat, lon: $lon, gender: ${gender.value}');
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        print(
            '[UserRepository $methodName] Error: Authentication token is missing.');
        throw ApiException('Authentication token is missing');
      }

      final headers = {'Authorization': 'Bearer $token'};
      final body = {
        'latitude': lat,
        'longitude': lon,
        'gender': gender.value,
      };

      print(
          '[UserRepository $methodName] Making POST request to /api/profile/location-gender');
      final response = await _apiService.post(
        '/api/profile/location-gender',
        body: body,
        headers: headers,
      );

      print('[UserRepository $methodName] API Response: $response');
      if (response['success'] == true) {
        print(
            '[UserRepository $methodName] Location/Gender update successful.');
        return true;
      } else {
        final message = response['message']?.toString() ??
            'Failed to update location and gender.';
        print(
            '[UserRepository $methodName] Location/Gender update failed: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print('[UserRepository $methodName] API Exception: ${e.message}');
      rethrow;
    } catch (e) {
      print('[UserRepository $methodName] Unexpected Error: ${e.toString()}');
      throw ApiException(
          'An unexpected error occurred while updating location/gender: ${e.toString()}');
    }
  }

  // --- METHOD TO UPDATE MAIN PROFILE DETAILS (Phase 5) ---
  /// Updates the main profile details (excluding location/gender) via POST /api/profile.
  /// Expects a Map containing only the fields relevant to this endpoint.
  Future<bool> updateProfileDetails(Map<String, dynamic> profileData) async {
    final String methodName = 'updateProfileDetails';
    print('[UserRepository $methodName] Called.');
    // Remove any lingering null values which might cause issues with JSON encoding or backend validation
    profileData.removeWhere((key, value) => value == null);
    print('[UserRepository $methodName] Payload to send: $profileData');

    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        print(
            '[UserRepository $methodName] Error: Authentication token is missing.');
        throw ApiException('Authentication token is missing');
      }

      final headers = {'Authorization': 'Bearer $token'};

      print('[UserRepository $methodName] Making POST request to /api/profile');
      final response = await _apiService.post(
        '/api/profile', // The endpoint for main profile details
        body: profileData, // Send the prepared data
        headers: headers,
      );

      print('[UserRepository $methodName] API Response: $response');
      if (response['success'] == true) {
        print(
            '[UserRepository $methodName] Profile details update successful.');
        return true;
      } else {
        final message = response['message']?.toString() ??
            'Failed to update profile details.';
        print(
            '[UserRepository $methodName] Profile details update failed: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print('[UserRepository $methodName] API Exception: ${e.message}');
      rethrow;
    } catch (e) {
      print('[UserRepository $methodName] Unexpected Error: ${e.toString()}');
      throw ApiException(
          'An unexpected error occurred while updating profile details: ${e.toString()}');
    }
  }
  // --- END METHOD ---

  // Fetch Quick Feed (from Phase 4)
  Future<List<QuickFeedProfile>> fetchQuickFeed() async {
    // ... (Implementation from Phase 4) ...
    final String methodName = 'fetchQuickFeed';
    print('[UserRepository $methodName] Called.');
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        print(
            '[UserRepository $methodName] Error: Authentication token is missing.');
        throw ApiException('Authentication token is missing');
      }

      final headers = {'Authorization': 'Bearer $token'};

      print(
          '[UserRepository $methodName] Making GET request to /api/quickfeed');
      final response =
          await _apiService.get('/api/quickfeed', headers: headers);

      print('[UserRepository $methodName] API Response: $response');
      if (response['success'] == true &&
          response['profiles'] != null &&
          response['profiles'] is List) {
        print('[UserRepository $methodName] Quick feed fetch successful.');
        final profilesList = response['profiles'] as List;
        return profilesList
            .map((profileJson) =>
                QuickFeedProfile.fromJson(profileJson as Map<String, dynamic>))
            .toList();
      } else {
        final message =
            response['message']?.toString() ?? 'Failed to fetch quick feed.';
        print('[UserRepository $methodName] Quick feed fetch failed: $message');
        if (response['success'] == true && response['profiles'] == null) {
          return [];
        }
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print('[UserRepository $methodName] API Exception: ${e.message}');
      rethrow;
    } catch (e) {
      print('[UserRepository $methodName] Unexpected Error: ${e.toString()}');
      throw ApiException(
          'An unexpected error occurred while fetching the quick feed: ${e.toString()}');
    }
  }

  // Fetch Home Feed (from Phase 4)
  Future<List<UserModel>> fetchHomeFeed() async {
    // <-- Change return type
    final String methodName = 'fetchHomeFeed';
    print('[UserRepository $methodName] Called.');
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        print(
            '[UserRepository $methodName] Error: Authentication token is missing.');
        throw ApiException('Authentication token is missing');
      }

      final headers = {'Authorization': 'Bearer $token'};

      print('[UserRepository $methodName] Making GET request to /api/homefeed');
      final response = await _apiService.get('/api/homefeed', headers: headers);

      print('[UserRepository $methodName] API Response: $response');
      if (response['success'] == true &&
          response['profiles'] != null &&
          response['profiles'] is List) {
        print('[UserRepository $methodName] Home feed fetch successful.');
        final profilesList = response['profiles'] as List;
        // --- UPDATED PARSING LOGIC ---
        return profilesList.map((profileJson) =>
            // Use UserModel.fromJson to parse the full profile data
            UserModel.fromJson(profileJson as Map<String, dynamic>)).toList();
        // --- END UPDATED PARSING LOGIC ---
      } else {
        final message =
            response['message']?.toString() ?? 'Failed to fetch home feed.';
        print('[UserRepository $methodName] Home feed fetch failed: $message');
        // Handle case where 'profiles' might be null but success is true (empty feed)
        if (response['success'] == true &&
            (response['profiles'] == null ||
                (response['profiles'] is List &&
                    (response['profiles'] as List).isEmpty))) {
          print('[UserRepository $methodName] Feed is empty.');
          return []; // Return empty list
        }
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print('[UserRepository $methodName] API Exception: ${e.message}');
      rethrow;
    } catch (e) {
      print('[UserRepository $methodName] Unexpected Error: ${e.toString()}');
      throw ApiException(
          'An unexpected error occurred while fetching the home feed: ${e.toString()}');
    }
  }

  // Fetch User Profile (existing)
  Future<UserModel> fetchUserProfile() async {
    // ... (Implementation from Phase 3) ...
    final String methodName = 'fetchUserProfile';
    print('[UserRepository $methodName] Called.');
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        print(
            '[UserRepository $methodName] Error: Authentication token is missing.');
        throw ApiException('Authentication token is missing');
      }

      final headers = {'Authorization': 'Bearer $token'};

      print('[UserRepository $methodName] Making GET request to /get-profile');
      final response = await _apiService.get('/get-profile', headers: headers);

      print('[UserRepository $methodName] API Response: $response');
      if (response['success'] == true && response['user'] != null) {
        print('[UserRepository $methodName] Profile fetch successful.');
        if (response['user'] is Map<String, dynamic>) {
          return UserModel.fromJson(response['user'] as Map<String, dynamic>);
        } else {
          print(
              '[UserRepository $methodName] Error: Invalid user data format in response.');
          throw ApiException('Invalid user data format received from server.');
        }
      } else {
        final message =
            response['message']?.toString() ?? 'Failed to fetch user profile.';
        print('[UserRepository $methodName] Profile fetch failed: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print('[UserRepository $methodName] API Exception: ${e.message}');
      rethrow;
    } catch (e) {
      print('[UserRepository $methodName] Unexpected Error: ${e.toString()}');
      throw ApiException(
          'An unexpected error occurred while fetching the profile: ${e.toString()}');
    }
  }

  // Old updateProfile method - Keep for compatibility or remove
  Future<bool> updateProfile(UserModel userModel) async {
    print(
        "[UserRepository updateProfile] Forwarding to updateProfileDetails...");
    // Use the new helper method to generate the correct payload
    Map<String, dynamic> profileData = userModel.toJsonForProfileUpdate();
    return await updateProfileDetails(profileData);
  }
}
