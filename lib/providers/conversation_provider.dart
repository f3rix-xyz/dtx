// lib/providers/conversation_provider.dart
import 'dart:async';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/repositories/chat_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // Import foundation for list identity check

class ConversationState {
  final bool isLoading;
  final List<ChatMessage> messages;
  final AppError? error;

  const ConversationState({
    this.isLoading = false,
    this.messages = const [],
    this.error,
  });

  ConversationState copyWith({
    bool? isLoading,
    List<ChatMessage>? messages,
    AppError? Function()? error,
  }) {
    return ConversationState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      error: error != null ? error() : this.error,
    );
  }
}

class ConversationNotifier extends StateNotifier<ConversationState> {
  final ChatRepository _chatRepository;
  final int _otherUserId;

  ConversationNotifier(this._chatRepository, this._otherUserId)
      : super(const ConversationState()) {
    print("[Provider Init: $_otherUserId] Fetching initial messages...");
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    // (fetchMessages remains the same)
    if (state.isLoading) return;
    print("[Provider Fetch: $_otherUserId] Fetching ALL messages...");
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final messagesFromRepo = await _chatRepository.fetchConversation(
        otherUserId: _otherUserId,
      );

      if (mounted) {
        final oldMessagesHashCode = state.messages.hashCode;
        state = state.copyWith(
          isLoading: false,
          // Messages from API are ASC, no need to reverse anymore?
          // If they ARE ASC and you want latest at bottom, keep as is.
          // If they are DESC and you want latest at bottom, use reversed.
          messages: messagesFromRepo,
        );
        print(
            "[Provider Fetch: $_otherUserId] Fetched ${messagesFromRepo.length} messages (ASC order). List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}");
      }
    } on ApiException catch (e) {
      print(
          "[Provider Fetch Error: $_otherUserId] API Exception: ${e.message}");
      if (mounted) {
        state = state.copyWith(
            isLoading: false, error: () => AppError.server(e.message));
      }
    } catch (e, stacktrace) {
      // Added stacktrace logging
      print("[Provider Fetch Error: $_otherUserId] Unexpected Error: $e");
      print(stacktrace); // Log stacktrace
      if (mounted) {
        state = state.copyWith(
            isLoading: false,
            error: () => AppError.generic("Failed to load conversation."));
      }
    }
  }

  void addSentMessage(ChatMessage message) {
    // (addSentMessage remains the same - adds to end)
    if (!mounted) return;
    print(
        "[Provider AddSent: $_otherUserId] Adding message: TempID=${message.tempId}, RealID=${message.messageID}, Status=${message.status}, Type=${message.isMedia ? message.mediaType : 'text'}");
    final oldMessagesHashCode = state.messages.hashCode;
    // Add new messages to the END of the list (assuming chronological order)
    state = state.copyWith(messages: [...state.messages, message]);
    print(
        "[Provider AddSent: $_otherUserId] Message added to end. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. New count: ${state.messages.length}");
  }

  void addReceivedMessage(ChatMessage message) {
    // (addReceivedMessage remains the same - adds to end)
    if (!mounted) return;
    print(
        "[Provider AddRcvd: $_otherUserId] Adding received message: RealID=${message.messageID}, Type=${message.isMedia ? message.mediaType : 'text'}");
    final oldMessagesHashCode = state.messages.hashCode;
    // Add new messages to the END of the list
    state = state.copyWith(messages: [...state.messages, message]);
    print(
        "[Provider AddRcvd: $_otherUserId] Message added to end. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. New count: ${state.messages.length}");
  }

  // --- CORRECTED: updateMessageStatus ---
  void updateMessageStatus(String tempOrRealId, ChatMessageStatus newStatus,
      {int? finalMessageId, String? finalMediaUrl, String? errorMessage}) {
    if (!mounted) return;
    print(
        "[Provider UpdateStatus: $_otherUserId] Attempting update: ID=$tempOrRealId, NewStatus=$newStatus, FinalMsgID=$finalMessageId, FinalURL=${finalMediaUrl != null}, Error=${errorMessage != null}");

    final currentMessages = state.messages;
    // Find message by tempId (for optimistic messages) OR by real messageID
    final messageIndex = currentMessages.indexWhere((msg) =>
        (msg.tempId != null && msg.tempId == tempOrRealId) ||
        (msg.messageID != 0 &&
            msg.messageID.toString() ==
                tempOrRealId)); // Compare string representation of ID

    if (messageIndex != -1) {
      final messageToUpdate = currentMessages[messageIndex];
      print(
          "[Provider UpdateStatus: $_otherUserId] Found message at index $messageIndex. Current Status=${messageToUpdate.status}");

      final updatedMessage = messageToUpdate.copyWith(
        status: newStatus,
        messageID: finalMessageId,
        // --- FIX: Pass String? directly ---
        mediaUrl: finalMediaUrl,
        errorMessage: errorMessage,
        // --- END FIX ---
        clearErrorMessage: errorMessage == null,
        clearLocalFilePath: false, // Keep local path as needed
      );

      final updatedMessages = List<ChatMessage>.from(currentMessages);
      updatedMessages[messageIndex] = updatedMessage;

      final oldMessagesHashCode = state.messages.hashCode;
      final oldListIdentityHashCode = identityHashCode(state.messages);

      state = state.copyWith(messages: updatedMessages);

      final newListIdentityHashCode = identityHashCode(state.messages);
      print(
          "[Provider UpdateStatus: $_otherUserId] Status updated for ID $tempOrRealId. RealID: ${updatedMessage.messageID} Final URL: ${updatedMessage.mediaUrl}. Local Path Kept: ${updatedMessage.localFilePath}. Error: ${updatedMessage.errorMessage}. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. List instance changed: ${oldListIdentityHashCode != newListIdentityHashCode}");
    } else {
      print(
          "[Provider UpdateStatus: $_otherUserId] WARNING: Could not find message with Temp/Real ID $tempOrRealId to update status.");
    }
  }
  // --- END CORRECTION ---
}

// Provider definition remains the same
final conversationProvider =
    StateNotifierProvider.family<ConversationNotifier, ConversationState, int>(
        (ref, otherUserId) {
  final repo = ref.watch(chatRepositoryProvider);
  return ConversationNotifier(repo, otherUserId);
});
