// File: lib/repositories/user_repository.dart
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/token_storage.dart';
import '../utils/app_enums.dart';

class UserRepository {
  final ApiService _apiService;

  UserRepository(this._apiService);

  // updateLocationGender remains the same
  Future<bool> updateLocationGender(
      double lat, double lon, Gender gender) async {
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

  // updateProfileDetails remains the same (used for onboarding step 2)
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

  // --- ADDED editProfile METHOD ---
  Future<bool> editProfile(Map<String, dynamic> profileData) async {
    final String methodName = 'editProfile';
    print('[UserRepository $methodName] Called.');
    // Remove any lingering null values (important for PATCH)
    profileData.removeWhere((key, value) => value == null);
    print(
        '[UserRepository $methodName] Payload to send via PATCH: $profileData');

    // Ensure there's actually something to update
    if (profileData.isEmpty) {
      print(
          '[UserRepository $methodName] No changes detected. Skipping API call.');
      // Consider returning a specific value or message? For now, true as nothing failed.
      return true; // Or throw ApiException("No changes to save.") if preferred
    }

    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        print(
            '[UserRepository $methodName] Error: Authentication token is missing.');
        throw ApiException('Authentication token is missing');
      }
      final headers = {'Authorization': 'Bearer $token'};

      print(
          '[UserRepository $methodName] Making PATCH request to /api/profile/edit');
      final response = await _apiService.patch(
        '/api/profile/edit', // The specific PATCH endpoint
        body: profileData,
        headers: headers,
      );

      print('[UserRepository $methodName] API Response: $response');
      if (response['success'] == true) {
        print('[UserRepository $methodName] Profile edit successful.');
        return true;
      } else {
        final message =
            response['message']?.toString() ?? 'Failed to edit profile.';
        print('[UserRepository $methodName] Profile edit failed: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print('[UserRepository $methodName] API Exception: ${e.message}');
      rethrow;
    } catch (e) {
      print('[UserRepository $methodName] Unexpected Error: ${e.toString()}');
      throw ApiException(
          'An unexpected error occurred while editing profile: ${e.toString()}');
    }
  }
  // --- END ADDED editProfile METHOD ---

  // fetchHomeFeed remains the same
  Future<Map<String, dynamic>> fetchHomeFeed() async {
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
      if (response['success'] == true) {
        final profilesList =
            response['profiles'] as List? ?? []; // Handle null case
        final profiles = profilesList
            .map((profileJson) =>
                UserModel.fromJson(profileJson as Map<String, dynamic>))
            .toList();
        final hasMore = response['has_more'] as bool? ??
            false; // Default to false if missing

        print(
            '[UserRepository $methodName] Home feed fetch successful. Count: ${profiles.length}, Has More: $hasMore');
        return {'profiles': profiles, 'has_more': hasMore};
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
          return {
            'profiles': <UserModel>[],
            'has_more': false
          }; // Return empty list and has_more=false
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

  // fetchUserProfile remains the same
  Future<UserModel> fetchUserProfile() async {
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

  // updateProfile (DEPRECATED for edit - keep for onboarding step 2)
  // This uses the POST /api/profile endpoint
  Future<bool> updateProfile(UserModel userModel) async {
    print(
        "[UserRepository updateProfile] Calling updateProfileDetails (POST)...");
    Map<String, dynamic> profileData = userModel.toJsonForProfileUpdate();
    return await updateProfileDetails(profileData);
  }
}
