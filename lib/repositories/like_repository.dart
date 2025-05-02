// File: repositories/like_repository.dart
import '../models/like_models.dart';
import '../models/error_model.dart';
import '../services/api_service.dart';
import '../utils/token_storage.dart';
import '../utils/app_enums.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class LikeRepository {
  final ApiService _apiService;

  LikeRepository(this._apiService);

  // --- Methods unchanged ---
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
      } else if (e.statusCode == 409) {
        print("[LikeRepository $methodName] Conflict: Already liked/matched?");
        rethrow;
      }
      rethrow;
    } catch (e) {
      print('[LikeRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while liking content: ${e.toString()}');
    }
  }

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

  Future<bool> likeBackUserProfile({required int likedUserId}) async {
    final String methodName = 'likeBackUserProfile';
    print('[LikeRepository $methodName] Liking back UserID: $likedUserId');
    try {
      return await likeContent(
        likedUserId: likedUserId,
        contentType: ContentLikeType.profile,
        contentIdentifier: ContentLikeType.profile.value,
        interactionType: LikeInteractionType.standard,
        comment: null,
      );
    } on ApiException catch (e) {
      print(
          '[LikeRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      if (e.statusCode == 409) {
        print("[LikeRepository $methodName] Conflict: Already liked/matched?");
      }
      rethrow;
    } catch (e) {
      print('[LikeRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while liking back user: ${e.toString()}');
    }
  }

  // --- fetchReceivedLikes - Ensure `like_id` is parsed ---
  Future<Map<String, List<dynamic>>> fetchReceivedLikes() async {
    final String methodName = 'fetchReceivedLikes';
    print('[LikeRepository $methodName] Fetching received likes...');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        print(
            '[LikeRepository $methodName] Error: Authentication token missing.');
        throw ApiException('Authentication token missing');
      }
      final headers = {'Authorization': 'Bearer $token'};
      print(
          '[LikeRepository $methodName] Making GET request to /api/likes/received...');
      final response =
          await _apiService.get('/api/likes/received', headers: headers);
      // Add more detailed logging of the raw response
      if (kDebugMode) {
        print(
            '[LikeRepository $methodName] Raw API Response: ${response.toString()}');
      }

      if (response['success'] == true) {
        print('[LikeRepository $methodName] Parsing successful response...');
        final List<FullProfileLiker> fullProfiles = (response['full_profiles']
                    as List? ??
                [])
            .map((data) {
              try {
                // Log the raw data item before parsing
                if (kDebugMode) {
                  print(
                      "[LikeRepository $methodName - full] Parsing Item: $data");
                }
                return FullProfileLiker.fromJson(data as Map<String, dynamic>);
              } catch (e, stacktrace) {
                // Add stacktrace
                print(
                    "[LikeRepository $methodName - full] Error parsing FullProfileLiker: $e, Data: $data");
                print(
                    "[LikeRepository $methodName - full] Stacktrace: $stacktrace"); // Log stacktrace
                return null;
              }
            })
            .whereType<
                FullProfileLiker>() // Filter out nulls from parsing errors
            .toList();

        final List<BasicProfileLiker> otherLikers =
            (response['other_likers'] as List? ?? [])
                .map((data) {
                  try {
                    // Log the raw data item before parsing
                    if (kDebugMode) {
                      print(
                          "[LikeRepository $methodName - other] Parsing Item: $data");
                    }
                    return BasicProfileLiker.fromJson(
                        data as Map<String, dynamic>);
                  } catch (e, stacktrace) {
                    // Add stacktrace
                    print(
                        "[LikeRepository $methodName - other] Error parsing BasicProfileLiker: $e, Data: $data");
                    print(
                        "[LikeRepository $methodName - other] Stacktrace: $stacktrace"); // Log stacktrace
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
      rethrow;
    } catch (e, stacktrace) {
      print('[LikeRepository $methodName] Unexpected Error caught: $e');
      print('[LikeRepository $methodName] Stacktrace: $stacktrace');
      throw ApiException(
          'An unexpected error occurred while fetching likes: ${e.toString()}');
    }
  }

  // --- fetchLikerProfile - No changes needed ---
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
    } catch (e, stacktrace) {
      // Added stacktrace
      print('[LikeRepository $methodName] Unexpected Error: $e');
      print(
          '[LikeRepository $methodName] Stacktrace: $stacktrace'); // Log stacktrace
      throw ApiException(
          'An unexpected error occurred while fetching the liker profile: ${e.toString()}');
    }
  }

  // --- unmatchUser - No changes needed ---
  Future<bool> unmatchUser({required int targetUserId}) async {
    final String methodName = 'unmatchUser';
    print('[LikeRepository $methodName] Unmatching UserID: $targetUserId');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');
      final headers = {'Authorization': 'Bearer $token'};
      final body = {'target_user_id': targetUserId};
      print('[LikeRepository $methodName] Request Body: $body');
      final response =
          await _apiService.post('/api/unmatch', body: body, headers: headers);
      print('[LikeRepository $methodName] API Response: $response');
      return response['success'] == true;
    } on ApiException catch (e) {
      print(
          '[LikeRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      rethrow;
    } catch (e) {
      print('[LikeRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while unmatching user: ${e.toString()}');
    }
  }

  // --- reportUser - No changes needed ---
  Future<bool> reportUser(
      {required int targetUserId, required ReportReason reason}) async {
    final String methodName = 'reportUser';
    print(
        '[LikeRepository $methodName] Reporting UserID: $targetUserId, Reason: ${reason.value}');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');
      final headers = {'Authorization': 'Bearer $token'};
      final body = {'reported_user_id': targetUserId, 'reason': reason.value};
      print('[LikeRepository $methodName] Request Body: $body');
      final response =
          await _apiService.post('/api/report', body: body, headers: headers);
      print('[LikeRepository $methodName] API Response: $response');
      return response['success'] == true;
    } on ApiException catch (e) {
      print(
          '[LikeRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      rethrow;
    } catch (e) {
      print('[LikeRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while reporting user: ${e.toString()}');
    }
  }

  // --- START: ADDED logLikerProfileView ---
  Future<void> logLikerProfileView(int likerUserId, int likeId) async {
    final String methodName = 'logLikerProfileView';
    print(
        '[LikeRepository $methodName] Logging view: Liker=$likerUserId, Like=$likeId');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        print('[LikeRepository $methodName] Error: Auth token missing.');
        // Don't throw, just log and return as this is non-critical
        return;
      }
      final headers = {'Authorization': 'Bearer $token'};
      final body = {
        'liker_user_id': likerUserId,
        'like_id': likeId,
      };
      print('[LikeRepository $methodName] Request Body: $body');

      final response = await _apiService.post(
        '/api/analytics/log-like-profile-view', // Analytics endpoint
        body: body,
        headers: headers,
      );

      print('[LikeRepository $methodName] API Response: $response');
      if (response['success'] != true) {
        print(
            '[LikeRepository $methodName] Warning: API call failed or returned success=false. Message: ${response['message']}');
        // Log warning but don't throw an error to the UI
      } else {
        print('[LikeRepository $methodName] View logged successfully.');
      }
    } on ApiException catch (e) {
      // Log API errors but don't throw
      print(
          '[LikeRepository $methodName] API Exception during logging: ${e.message}, Status: ${e.statusCode}');
    } catch (e, stacktrace) {
      // Log other errors but don't throw
      print('[LikeRepository $methodName] Unexpected Error during logging: $e');
      print('[LikeRepository $methodName] Stacktrace: $stacktrace');
    }
  }
  // --- END ADDED ---
}
