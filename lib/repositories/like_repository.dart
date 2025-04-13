// File: repositories/like_repository.dart
import '../models/like_models.dart';
import '../models/error_model.dart'; // Import AppError if needed by provider
import '../services/api_service.dart';
import '../utils/token_storage.dart';

class LikeRepository {
  final ApiService _apiService;

  LikeRepository(this._apiService);

  // likeContent(...) method from Phase 8...
  Future<bool> likeContent({
    required int likedUserId,
    required ContentLikeType contentType,
    required String contentIdentifier,
    required LikeInteractionType interactionType,
    String? comment,
  }) async {
    /* ... implementation ... */
    final String methodName = 'likeContent';
    print(
        '[LikeRepository $methodName] Liking UserID: $likedUserId, Type: ${contentType.value}, Identifier: $contentIdentifier, Interaction: ${interactionType.value}');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');
      final headers = {'Authorization': 'Bearer $token'};
      final body = {
        'liked_user_id': likedUserId,
        'content_type': contentType.value,
        'content_identifier': contentIdentifier,
        'interaction_type': interactionType.value,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      };
      print('[LikeRepository $methodName] Request Body: $body');
      final response =
          await _apiService.post('/api/like', body: body, headers: headers);
      print('[LikeRepository $methodName] API Response: $response');
      return response['success'] == true;
    } on ApiException catch (e) {
      /* ... specific exception handling ... */
      print(
          '[LikeRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      if (e.statusCode == 403) {
        if (e.message.toLowerCase().contains('limit reached'))
          throw LikeLimitExceededException(e.message);
        else if (e.message.toLowerCase().contains('insufficient consumables') ||
            e.message.toLowerCase().contains('rose'))
          throw InsufficientRosesException(e.message);
      }
      rethrow;
    } catch (e) {
      print('[LikeRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while liking content: ${e.toString()}');
    }
  }

  // dislikeUser(...) method from Phase 8...
  Future<bool> dislikeUser({required int dislikedUserId}) async {
    /* ... implementation ... */
    final String methodName = 'dislikeUser';
    print('[LikeRepository $methodName] Disliking UserID: $dislikedUserId');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');
      final headers = {'Authorization': 'Bearer $token'};
      final body = {'disliked_user_id': dislikedUserId};
      print('[LikeRepository $methodName] Request Body: $body');
      final response =
          await _apiService.post('/api/dislike', body: body, headers: headers);
      print('[LikeRepository $methodName] API Response: $response');
      return response['success'] == true;
    } on ApiException catch (e) {
      print(
          '[LikeRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      rethrow;
    } catch (e) {
      print('[LikeRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while disliking user: ${e.toString()}');
    }
  }

  // --- NEW METHOD: Fetch Received Likes ---
  Future<Map<String, List<dynamic>>> fetchReceivedLikes() async {
    final String methodName = 'fetchReceivedLikes';
    print('[LikeRepository $methodName] Fetching received likes...');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');

      final headers = {'Authorization': 'Bearer $token'};
      final response =
          await _apiService.get('/api/likes/received', headers: headers);
      print('[LikeRepository $methodName] API Response: $response');

      if (response['success'] == true) {
        final List<FullProfileLiker> fullProfiles =
            (response['full_profiles'] as List? ?? [])
                .map((data) =>
                    FullProfileLiker.fromJson(data as Map<String, dynamic>))
                .toList();

        final List<BasicProfileLiker> otherLikers =
            (response['other_likers'] as List? ?? [])
                .map((data) =>
                    BasicProfileLiker.fromJson(data as Map<String, dynamic>))
                .toList();
        print(
            '[LikeRepository $methodName] Parsed ${fullProfiles.length} full, ${otherLikers.length} basic profiles.');
        return {'full': fullProfiles, 'other': otherLikers};
      } else {
        final message = response['message']?.toString() ??
            'Failed to fetch received likes.';
        print('[LikeRepository $methodName] Fetch failed: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print(
          '[LikeRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      rethrow;
    } catch (e) {
      print('[LikeRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while fetching likes: ${e.toString()}');
    }
  }
  // --- END NEW METHOD ---

  Future<Map<String, dynamic>> fetchLikerProfile(int likerUserId) async {
    final String methodName = 'fetchLikerProfile';
    print(
        '[LikeRepository $methodName] Fetching profile for liker ID: $likerUserId');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');

      final headers = {'Authorization': 'Bearer $token'};
      // Construct the endpoint with the path parameter
      final endpoint = '/api/liker-profile/$likerUserId';
      print('[LikeRepository $methodName] Making GET request to: $endpoint');

      final response = await _apiService.get(endpoint, headers: headers);
      print('[LikeRepository $methodName] API Response: $response');

      if (response['success'] == true &&
          response['profile'] != null &&
          response['like_details'] != null) {
        // Ensure the nested data are maps before parsing
        if (response['profile'] is Map<String, dynamic> &&
            response['like_details'] is Map<String, dynamic>) {
          final profileData = UserProfileData.fromJson(
              response['profile'] as Map<String, dynamic>);
          final likeDetailsData = LikeInteractionDetails.fromJson(
              response['like_details'] as Map<String, dynamic>);
          print(
              '[LikeRepository $methodName] Successfully parsed profile and like details.');
          return {'profile': profileData, 'likeDetails': likeDetailsData};
        } else {
          print(
              '[LikeRepository $methodName] Error: Invalid data format in response.');
          throw ApiException('Invalid data format received for liker profile.');
        }
      } else {
        // Handle case where success might be true but data is missing (shouldn't happen ideally)
        final message = response['message']?.toString() ??
            'Failed to fetch liker profile or like details.';
        print('[LikeRepository $methodName] Fetch failed: $message');
        throw ApiException(message,
            statusCode: response['statusCode']
                as int?); // Pass status code if available
      }
    } on ApiException catch (e) {
      // Specific handling for 404 might be useful here if needed by the UI
      print(
          '[LikeRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      rethrow;
    } catch (e) {
      print('[LikeRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while fetching the liker profile: ${e.toString()}');
    }
  }
  // fetchLikerProfile(...) - Will be added in Phase 10
}
