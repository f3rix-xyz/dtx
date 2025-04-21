// lib/repositories/match_repository.dart
import 'package:dtx/models/user_model.dart'; // Using UserModel as MatchUser
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
        // Assuming response['matches'] is a list of User JSON objects
        final matches = matchesData
            .map((data) => UserModel.fromJson(data as Map<String, dynamic>))
            .toList();
        print(
            '[MatchRepository $methodName] Successfully parsed ${matches.length} matches.');
        return matches;
      } else if (response['success'] == true && response['matches'] == null) {
        print('[MatchRepository $methodName] No matches found.');
        return []; // Return empty list if matches array is null or missing
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
