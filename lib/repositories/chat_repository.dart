// lib/repositories/chat_repository.dart
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/utils/token_storage.dart';

class ChatRepository {
  final ApiService _apiService;

  ChatRepository(this._apiService);

  // --- MODIFIED: fetchConversation ---
  Future<List<ChatMessage>> fetchConversation({
    required int otherUserId,
    // Removed limit and offset parameters
  }) async {
    final String methodName = 'fetchConversation';
    print(
        '[ChatRepository $methodName] Fetching conversation with $otherUserId');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');
      final headers = {'Authorization': 'Bearer $token'};

      // Endpoint does NOT include the user ID anymore
      final endpoint = '/api/conversation';
      final body = {'other_user_id': otherUserId}; // Send ID in the body

      // Change to POST request
      final response = await _apiService.post(
        endpoint,
        body: body,
        headers: headers,
      );
      // print('[ChatRepository $methodName] API Response: $response'); // Debug careful with PII

      // API now returns success and messages directly
      if (response['success'] == true && response['messages'] != null) {
        final List<dynamic> messagesData = response['messages'] as List? ?? [];
        final messages = messagesData
            .map((data) => ChatMessage.fromJson(data as Map<String, dynamic>))
            .toList();

        print(
            '[ChatRepository $methodName] Success. Count: ${messages.length}');
        // Return only the list of messages
        return messages;
      } else if (response['success'] == true && response['messages'] == null) {
        print(
            '[ChatRepository $methodName] No messages found (API returned null).');
        return <ChatMessage>[]; // Empty conversation
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
  // --- END MODIFIED ---
}
