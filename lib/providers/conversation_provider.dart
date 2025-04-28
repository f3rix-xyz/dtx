// START OF FILE: lib/providers/conversation_provider.dart
import 'dart:async';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/service_provider.dart'; // Keep if needed, maybe not directly
import 'package:dtx/repositories/chat_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // Keep for list identity check

class ConversationState {
  final bool isLoading;
  final List<ChatMessage> messages; // List order: Newest at index 0
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
    if (state.isLoading) return;
    print("[Provider Fetch: $_otherUserId] Fetching ALL messages...");
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final messagesFromRepo = await _chatRepository.fetchConversation(
        otherUserId: _otherUserId,
      ); // Messages from API are ASC (Oldest first)

      if (mounted) {
        final oldMessagesHashCode = state.messages.hashCode;
        // --- FIX: Reverse the list before setting state ---
        final reversedMessages = messagesFromRepo.reversed.toList();
        state = state.copyWith(
          isLoading: false,
          messages: reversedMessages, // Store newest first
        );
        // --- END FIX ---
        print(
            "[Provider Fetch: $_otherUserId] Fetched ${messagesFromRepo.length} messages. Stored ${reversedMessages.length} (Newest first). List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}");
      }
    } on ApiException catch (e) {
      print(
          "[Provider Fetch Error: $_otherUserId] API Exception: ${e.message}");
      if (mounted) {
        state = state.copyWith(
            isLoading: false, error: () => AppError.server(e.message));
      }
    } catch (e, stacktrace) {
      print("[Provider Fetch Error: $_otherUserId] Unexpected Error: $e");
      print(stacktrace);
      if (mounted) {
        state = state.copyWith(
            isLoading: false,
            error: () => AppError.generic("Failed to load conversation."));
      }
    }
  }

  void addSentMessage(ChatMessage message) {
    if (!mounted) return;
    print(
        "[Provider AddSent: $_otherUserId] Adding message to START: TempID=${message.tempId}, RealID=${message.messageID}, Status=${message.status}, Type=${message.isMedia ? message.mediaType : 'text'}");
    final oldMessagesHashCode = state.messages.hashCode;
    // --- FIX: Add new message to the START of the list ---
    state = state.copyWith(messages: [message, ...state.messages]);
    // --- END FIX ---
    print(
        "[Provider AddSent: $_otherUserId] Message added to start. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. New count: ${state.messages.length}");
  }

  void addReceivedMessage(ChatMessage message) {
    if (!mounted) return;
    print(
        "[Provider AddRcvd: $_otherUserId] Adding received message to START: RealID=${message.messageID}, Type=${message.isMedia ? message.mediaType : 'text'}");
    final oldMessagesHashCode = state.messages.hashCode;
    // --- FIX: Add new message to the START of the list ---
    state = state.copyWith(messages: [message, ...state.messages]);
    // --- END FIX ---
    print(
        "[Provider AddRcvd: $_otherUserId] Message added to start. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. New count: ${state.messages.length}");
  }

  void updateMessageStatus(String tempOrRealId, ChatMessageStatus newStatus,
      {int? finalMessageId, String? finalMediaUrl, String? errorMessage}) {
    if (!mounted) return;
    print(
        "[Provider UpdateStatus: $_otherUserId] Attempting update: ID=$tempOrRealId, NewStatus=$newStatus, FinalMsgID=$finalMessageId, FinalURL=${finalMediaUrl != null}, Error=${errorMessage != null}");

    final currentMessages = state.messages;
    // Find message by tempId OR real messageID (using String comparison for flexibility)
    // Since the list is newest-first, finding the index is still valid.
    final messageIndex = currentMessages.indexWhere((msg) =>
        (msg.tempId != null && msg.tempId == tempOrRealId) ||
        (msg.messageID != 0 && msg.messageID.toString() == tempOrRealId));

    if (messageIndex != -1) {
      final messageToUpdate = currentMessages[messageIndex];
      print(
          "[Provider UpdateStatus: $_otherUserId] Found message at index $messageIndex (Newest=0). Current Status=${messageToUpdate.status}");

      final updatedMessage = messageToUpdate.copyWith(
        status: newStatus,
        messageID: finalMessageId ??
            messageToUpdate.messageID, // Use new ID if provided
        mediaUrl: finalMediaUrl, // Update URL if provided
        errorMessage: errorMessage,
        clearErrorMessage: errorMessage == null,
        clearLocalFilePath: false, // Keep local path as needed
      );

      final updatedMessages = List<ChatMessage>.from(currentMessages);
      updatedMessages[messageIndex] = updatedMessage;

      final oldMessagesHashCode = state.messages.hashCode;
      final oldListIdentityHashCode = identityHashCode(state.messages);

      state = state.copyWith(messages: updatedMessages); // Set the updated list

      final newListIdentityHashCode = identityHashCode(state.messages);
      print(
          "[Provider UpdateStatus: $_otherUserId] Status updated for ID $tempOrRealId. RealID: ${updatedMessage.messageID}, NewStatus: ${updatedMessage.status}. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. List instance changed: ${oldListIdentityHashCode != newListIdentityHashCode}");
    } else {
      print(
          "[Provider UpdateStatus: $_otherUserId] WARNING: Could not find message with Temp/Real ID $tempOrRealId to update status.");
    }
  }
}

// Provider definition remains the same
final conversationProvider =
    StateNotifierProvider.family<ConversationNotifier, ConversationState, int>(
        (ref, otherUserId) {
  // Ensure ChatRepository is watched/provided correctly
  final repo = ref.watch(chatRepositoryProvider);
  return ConversationNotifier(repo, otherUserId);
});
// END OF FILE: lib/providers/conversation_provider.dart
