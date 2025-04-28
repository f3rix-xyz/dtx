// lib/repositories/chat_repository.dart
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/utils/token_storage.dart';

class ChatRepository {
  final ApiService _apiService;

  ChatRepository(this._apiService);

  Future<List<ChatMessage>> fetchConversation({
    required int otherUserId,
  }) async {
    final String methodName = 'fetchConversation';
    print(
        '[ChatRepository $methodName] Fetching conversation with $otherUserId');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');
      final headers = {'Authorization': 'Bearer $token'};

      final endpoint = '/api/conversation';
      final body = {'other_user_id': otherUserId};

      print('[ChatRepository $methodName] Making POST request to: $endpoint');
      print('[ChatRepository $methodName] Request Body: $body');

      final response = await _apiService.post(
        endpoint,
        body: body,
        headers: headers,
      );
      // print('[ChatRepository $methodName] Raw API Response Map: $response'); // Uncomment if needed, but can be large

      if (response['success'] == true) {
        final List<dynamic> messagesData = response['messages'] as List? ?? [];
        print(
            '[ChatRepository $methodName] API Success. Raw messagesData length: ${messagesData.length}'); // Log length

        final messages = messagesData
            .map((data) {
              // <<< --- ADDED LOGGING HERE --- >>>
              print(
                  "[ChatRepository map] Processing raw message data item: $data");
              // <<< --- END ADDED LOGGING --- >>>
              try {
                if (data is Map<String, dynamic>) {
                  return ChatMessage.fromJson(data);
                } else {
                  print(
                      "[ChatRepository map] Warning: Invalid item type in messages list: ${data.runtimeType}");
                  return null;
                }
              } catch (e, stacktrace) {
                // Add stacktrace
                print("[ChatRepository map] Error parsing chat message: $e");
                print(
                    "[ChatRepository map] Stacktrace: $stacktrace"); // Log stacktrace
                print(
                    "[ChatRepository map] Faulty Data: $data"); // Log faulty data
                return null;
              }
            })
            .whereType<ChatMessage>()
            .toList();

        print(
            '[ChatRepository $methodName] Parsed successfully. Final Message Count: ${messages.length}');
        return messages;
      } else {
        final message =
            response['message']?.toString() ?? 'Failed to fetch conversation.';
        print(
            '[ChatRepository $methodName] API call returned success=false: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print(
          '[ChatRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      rethrow;
    } catch (e, stacktrace) {
      // Add stacktrace
      print('[ChatRepository $methodName] Unexpected Error: $e');
      print(
          "[ChatRepository $methodName] Stacktrace: $stacktrace"); // Log stacktrace
      throw ApiException(
          'An unexpected error occurred while fetching conversation: ${e.toString()}');
    }
  }
}
