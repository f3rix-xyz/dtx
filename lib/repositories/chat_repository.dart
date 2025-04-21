// lib/repositories/chat_repository.dart
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/utils/token_storage.dart';

class ChatRepository {
  final ApiService _apiService;

  ChatRepository(this._apiService);

  Future<Map<String, dynamic>> fetchConversation({
    required int otherUserId,
    required int limit,
    required int offset,
  }) async {
    final String methodName = 'fetchConversation';
    print(
        '[ChatRepository $methodName] Fetching conversation with $otherUserId (limit: $limit, offset: $offset)');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');
      final headers = {'Authorization': 'Bearer $token'};

      final endpoint =
          '/api/conversation/$otherUserId?limit=$limit&offset=$offset';
      final response = await _apiService.get(endpoint, headers: headers);
      // print('[ChatRepository $methodName] API Response: $response'); // Debug careful with PII

      if (response['success'] == true && response['messages'] != null) {
        final List<dynamic> messagesData = response['messages'] as List? ?? [];
        final messages = messagesData
            .map((data) => ChatMessage.fromJson(data as Map<String, dynamic>))
            .toList();
        final hasMore = response['has_more'] as bool? ?? false;

        print(
            '[ChatRepository $methodName] Success. Count: ${messages.length}, HasMore: $hasMore');
        return {'messages': messages, 'hasMore': hasMore};
      } else if (response['success'] == true && response['messages'] == null) {
        print(
            '[ChatRepository $methodName] No messages found (API returned null).');
        return {
          'messages': <ChatMessage>[],
          'hasMore': false
        }; // Empty conversation
      } else {
        final message =
            response['message']?.toString() ?? 'Failed to fetch conversation.';
        print('[ChatRepository $methodName] Fetch failed: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print(
          '[ChatRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      rethrow;
    } catch (e) {
      print('[ChatRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while fetching conversation: ${e.toString()}');
    }
  }
}
