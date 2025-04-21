// lib/repositories/match_repository.dart
import 'package:dtx/models/user_model.dart'; // Explicitly import UserModel
import 'package:dtx/services/api_service.dart';
import 'package:dtx/utils/token_storage.dart';

class MatchRepository {
  final ApiService _apiService;

  MatchRepository(this._apiService);

  Future<List<UserModel>> fetchMatches() async {
    final String methodName = 'fetchMatches';
    print('[MatchRepository $methodName] Fetching matches...');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');
      final headers = {'Authorization': 'Bearer $token'};

      final response = await _apiService.get('/api/matches', headers: headers);
      print('[MatchRepository $methodName] API Response: $response');

      if (response['success'] == true && response['matches'] != null) {
        final List<dynamic> matchesData = response['matches'] as List? ?? [];

        // *** NEW SIMPLIFIED MAPPING LOGIC ***
        final matches = matchesData.map((data) {
          // Create a mutable map from the received data
          final Map<String, dynamic> modelInputData =
              Map<String, dynamic>.from(data as Map<String, dynamic>);

          // 1. Ensure 'id' key exists using 'matched_user_id'
          if (modelInputData.containsKey('matched_user_id')) {
            modelInputData['id'] = modelInputData['matched_user_id'];
          } else {
            modelInputData['id'] = null; // Ensure 'id' exists even if null
            print(
                "[MatchRepository $methodName] Warning: Missing 'matched_user_id' in match data: $data");
          }

          // 2. Ensure 'name' key exists (it's already correct in the curl response)
          if (!modelInputData.containsKey('name')) {
            modelInputData['name'] = null; // Ensure 'name' exists if missing
          }

          // 3. Ensure 'last_name' exists (not in curl, assume null/empty)
          if (!modelInputData.containsKey('last_name')) {
            modelInputData['last_name'] =
                null; // Or "" depending on UserModel needs
          }

          // 4. Create 'media_urls' from 'first_profile_pic_url'
          if (modelInputData.containsKey('first_profile_pic_url')) {
            final avatarUrl =
                modelInputData['first_profile_pic_url'] as String?;
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              modelInputData['media_urls'] = [avatarUrl];
            } else {
              modelInputData['media_urls'] = <String>[];
            }
          } else {
            modelInputData['media_urls'] = <String>[];
          }

          // 5. Add default/null values for other fields expected by UserModel.fromJson
          //    if they are not present in the /api/matches response. This prevents
          //    parsing errors in UserModel.fromJson.
          modelInputData.putIfAbsent('email', () => null);
          modelInputData.putIfAbsent('date_of_birth', () => null);
          modelInputData.putIfAbsent('latitude', () => null);
          modelInputData.putIfAbsent('longitude', () => null);
          modelInputData.putIfAbsent('gender', () => null);
          modelInputData.putIfAbsent('dating_intention', () => null);
          modelInputData.putIfAbsent('height', () => null);
          modelInputData.putIfAbsent('hometown', () => null);
          modelInputData.putIfAbsent('job_title', () => null);
          modelInputData.putIfAbsent('education', () => null);
          modelInputData.putIfAbsent('religious_beliefs', () => null);
          modelInputData.putIfAbsent('drinking_habit', () => null);
          modelInputData.putIfAbsent('smoking_habit', () => null);
          modelInputData.putIfAbsent(
              'verification_status', () => 'false'); // Default status?
          modelInputData.putIfAbsent('verification_pic', () => null);
          modelInputData.putIfAbsent('role', () => 'user'); // Default role?
          modelInputData.putIfAbsent('audio_prompt_question', () => null);
          modelInputData.putIfAbsent('audio_prompt_answer', () => null);
          modelInputData.putIfAbsent(
              'prompts', () => <dynamic>[]); // Default empty list

          // Now parse the prepared map
          try {
            print(
                "[MatchRepository $methodName] Parsing prepared data: $modelInputData");
            return UserModel.fromJson(modelInputData);
          } catch (e) {
            print(
                "[MatchRepository $methodName] ERROR parsing match data: $e. Data was: $modelInputData");
            // Return a default/empty UserModel or rethrow/handle as needed
            return UserModel(
                id: modelInputData['id']); // Return with ID at least
          }
        }).toList();
        // *** END SIMPLIFIED MAPPING LOGIC ***

        print(
            '[MatchRepository $methodName] Successfully processed ${matches.length} matches.');
        return matches;
      } else if (response['success'] == true && response['matches'] == null) {
        print('[MatchRepository $methodName] No matches found.');
        return [];
      } else {
        final message =
            response['message']?.toString() ?? 'Failed to fetch matches.';
        print('[MatchRepository $methodName] Fetch failed: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print(
          '[MatchRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      rethrow;
    } catch (e) {
      print('[MatchRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while fetching matches: ${e.toString()}');
    }
  }
}
