// lib/repositories/chat_repository.dart
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/providers/conversation_provider.dart'; // Import ConversationData
import 'package:dtx/services/api_service.dart';
import 'package:dtx/utils/token_storage.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'dart:convert'; // For jsonDecode if needed for raw logging

class ChatRepository {
  final ApiService _apiService;

  ChatRepository(this._apiService);

  // --- UPDATED Return Type and Logic ---
  Future<ConversationData> fetchConversation({
    required int otherUserId,
  }) async {
    final String methodName = 'fetchConversation';
    print(
        '[ChatRepository $methodName] Fetching conversation WITH STATUS for user $otherUserId');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        print("[ChatRepository $methodName] Auth token missing.");
        throw ApiException('Authentication token missing');
      }
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
      if (kDebugMode) {
        // Log raw response only in debug mode
        try {
          print(
              '[ChatRepository $methodName] Raw API Response Map: ${jsonEncode(response)}');
        } catch (e) {
          print(
              '[ChatRepository $methodName] Raw API Response Map: (Could not encode, likely large or complex)');
        }
      }

      if (response['success'] == true) {
        // --- PARSE MESSAGES ---
        final List<dynamic> messagesData = response['messages'] as List? ?? [];
        print(
            '[ChatRepository $methodName] API Success. Raw messagesData length: ${messagesData.length}');

        final messages = messagesData
            .map((data) {
              if (kDebugMode)
                print(
                    "[ChatRepository $methodName map] Processing raw message data item: $data");
              try {
                if (data is Map<String, dynamic>) {
                  return ChatMessage.fromJson(data);
                } else {
                  print(
                      "[ChatRepository $methodName map] Warning: Invalid item type in messages list: ${data.runtimeType}");
                  return null;
                }
              } catch (e, stacktrace) {
                print(
                    "[ChatRepository $methodName map] Error parsing chat message: $e");
                print(
                    "[ChatRepository $methodName map] Stacktrace: $stacktrace");
                print("[ChatRepository $methodName map] Faulty Data: $data");
                return null;
              }
            })
            .whereType<ChatMessage>()
            .toList();
        print(
            '[ChatRepository $methodName] Parsed Messages Count: ${messages.length}');

        // --- PARSE STATUS ---
        final bool isOnline = response['other_user_is_online'] as bool? ??
            false; // Default to false
        final String? lastOnlineStr =
            response['other_user_last_online'] as String?;
        DateTime? lastOnline;
        if (lastOnlineStr != null) {
          try {
            lastOnline = DateTime.parse(lastOnlineStr)
                .toLocal(); // Parse and convert to local time
          } catch (e) {
            print(
                "[ChatRepository $methodName] Error parsing lastOnline timestamp '$lastOnlineStr': $e");
          }
        }
        print(
            '[ChatRepository $methodName] Parsed Status: isOnline=$isOnline, lastOnline=$lastOnline');

        // --- RETURN ConversationData ---
        return ConversationData(
          messages: messages,
          otherUserIsOnline: isOnline,
          otherUserLastOnline: lastOnline,
        );
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
      print('[ChatRepository $methodName] Unexpected Error: $e');
      print("[ChatRepository $methodName] Stacktrace: $stacktrace");
      throw ApiException(
          'An unexpected error occurred while fetching conversation: ${e.toString()}');
    }
  }
}
