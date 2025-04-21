// File: repositories/like_repository.dart
import '../models/like_models.dart';
import '../models/error_model.dart'; // Import AppError if needed by provider
import '../services/api_service.dart';
import '../utils/token_storage.dart';
import '../utils/app_enums.dart'; // <<<--- ADDED IMPORT FOR ContentLikeType

class LikeRepository {
  final ApiService _apiService;

  LikeRepository(this._apiService);

  // likeContent(...) method remains the same
  Future<bool> likeContent({
    required int likedUserId,
    required ContentLikeType contentType,
    required String contentIdentifier,
    required LikeInteractionType interactionType,
    String? comment,
  }) async {
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
      print(
          '[LikeRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      if (e.statusCode == 403) {
        if (e.message.toLowerCase().contains('limit reached'))
          throw LikeLimitExceededException(e.message);
        else if (e.message.toLowerCase().contains('insufficient consumables') ||
            e.message.toLowerCase().contains('rose'))
          throw InsufficientRosesException(e.message);
      }
      // --- ADDED CONFLICT HANDLING for Already Liked ---
      else if (e.statusCode == 409) {
        // Re-throw specifically or handle as needed
        // For now, rethrow so the UI can potentially inform the user
        print("[LikeRepository $methodName] Conflict: Already liked/matched?");
        rethrow;
      }
      // --- END ADDED ---
      rethrow;
    } catch (e) {
      print('[LikeRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while liking content: ${e.toString()}');
    }
  }

  // dislikeUser(...) method remains the same
  Future<bool> dislikeUser({required int dislikedUserId}) async {
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

  // --- ADDED: likeBackUserProfile Method ---
  Future<bool> likeBackUserProfile({required int likedUserId}) async {
    final String methodName = 'likeBackUserProfile';
    print('[LikeRepository $methodName] Liking back UserID: $likedUserId');
    try {
      // Use the existing likeContent method with specific parameters
      return await likeContent(
        likedUserId: likedUserId,
        contentType: ContentLikeType.profile, // Use the specific type
        contentIdentifier: ContentLikeType.profile.value, // Match type value
        interactionType: LikeInteractionType.standard, // Standard like back
        comment: null, // No comment needed for profile like back
      );
    } on ApiException catch (e) {
      // Specific handling or rethrow
      print(
          '[LikeRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      if (e.statusCode == 409) {
        print("[LikeRepository $methodName] Conflict: Already liked/matched?");
      }
      rethrow;
    } catch (e) {
      // Catch other potential errors from likeContent
      print('[LikeRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while liking back user: ${e.toString()}');
    }
  }
  // --- END ADDED Method ---

  // fetchReceivedLikes(...) method remains the same
  Future<Map<String, List<dynamic>>> fetchReceivedLikes() async {
    final String methodName = 'fetchReceivedLikes';
    print(
        '[LikeRepository $methodName] Fetching received likes...'); // Log Start
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        print(
            '[LikeRepository $methodName] Error: Authentication token missing.');
        throw ApiException('Authentication token missing');
      }

      final headers = {'Authorization': 'Bearer $token'};
      print(
          '[LikeRepository $methodName] Making GET request to /api/likes/received...'); // Log API call
      final response =
          await _apiService.get('/api/likes/received', headers: headers);
      print(
          '[LikeRepository $methodName] API Response received: $response'); // Log Response

      if (response['success'] == true) {
        print(
            '[LikeRepository $methodName] Parsing successful response...'); // Log Parsing Start
        final List<FullProfileLiker> fullProfiles =
            (response['full_profiles'] as List? ?? [])
                .map((data) {
                  try {
                    // Add inner try-catch for parsing individual items
                    return FullProfileLiker.fromJson(
                        data as Map<String, dynamic>);
                  } catch (e) {
                    print(
                        "[LikeRepository $methodName] Error parsing FullProfileLiker: $e, Data: $data");
                    return null; // Return null for problematic items
                  }
                })
                .whereType<FullProfileLiker>() // Filter out nulls
                .toList();

        final List<BasicProfileLiker> otherLikers =
            (response['other_likers'] as List? ?? [])
                .map((data) {
                  try {
                    return BasicProfileLiker.fromJson(
                        data as Map<String, dynamic>);
                  } catch (e) {
                    print(
                        "[LikeRepository $methodName] Error parsing BasicProfileLiker: $e, Data: $data");
                    return null;
                  }
                })
                .whereType<BasicProfileLiker>() // Filter out nulls
                .toList();

        print(
            '[LikeRepository $methodName] Parsed ${fullProfiles.length} full, ${otherLikers.length} basic profiles.');
        return {'full': fullProfiles, 'other': otherLikers};
      } else {
        final message = response['message']?.toString() ??
            'Failed to fetch received likes.';
        print(
            '[LikeRepository $methodName] Fetch failed in API response: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print(
          '[LikeRepository $methodName] API Exception caught: ${e.message}, Status: ${e.statusCode}');
      rethrow; // Re-throw API exceptions to be handled by the provider
    } catch (e, stacktrace) {
      // Catch other errors and stacktrace
      print('[LikeRepository $methodName] Unexpected Error caught: $e');
      print(
          '[LikeRepository $methodName] Stacktrace: $stacktrace'); // Log stacktrace
      throw ApiException(
          'An unexpected error occurred while fetching likes: ${e.toString()}');
    }
  }

  // fetchLikerProfile(...) method remains the same
  Future<Map<String, dynamic>> fetchLikerProfile(int likerUserId) async {
    final String methodName = 'fetchLikerProfile';
    print(
        '[LikeRepository $methodName] Fetching profile for liker ID: $likerUserId');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');

      final headers = {'Authorization': 'Bearer $token'};
      final endpoint = '/api/liker-profile/$likerUserId';
      print('[LikeRepository $methodName] Making GET request to: $endpoint');

      final response = await _apiService.get(endpoint, headers: headers);
      print('[LikeRepository $methodName] API Response: $response');

      if (response['success'] == true &&
          response['profile'] != null &&
          response['like_details'] != null) {
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
        final message = response['message']?.toString() ??
            'Failed to fetch liker profile or like details.';
        print('[LikeRepository $methodName] Fetch failed: $message');
        throw ApiException(message, statusCode: response['statusCode'] as int?);
      }
    } on ApiException catch (e) {
      print(
          '[LikeRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      rethrow;
    } catch (e) {
      print('[LikeRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while fetching the liker profile: ${e.toString()}');
    }
  }
}
