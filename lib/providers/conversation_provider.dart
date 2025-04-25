// lib/providers/conversation_provider.dart
import 'dart:async';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/repositories/chat_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // Import foundation for list identity check

// ConversationState definition remains the same...
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
    // ... (fetchMessages remains the same) ...
    if (state.isLoading) return;
    print("[Provider Fetch: $_otherUserId] Fetching ALL messages...");
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final messagesFromRepo = await _chatRepository.fetchConversation(
        otherUserId: _otherUserId,
      );

      if (mounted) {
        final reversedMessages = messagesFromRepo.reversed.toList();
        final oldMessagesHashCode = state.messages.hashCode; // Log hashCode
        state = state.copyWith(
          isLoading: false,
          messages: reversedMessages,
        );
        print(
            "[Provider Fetch: $_otherUserId] Fetched and reversed ${reversedMessages.length} messages. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}");
      }
    } on ApiException catch (e) {
      print(
          "[Provider Fetch Error: $_otherUserId] API Exception: ${e.message}");
      if (mounted) {
        state = state.copyWith(
            isLoading: false, error: () => AppError.server(e.message));
      }
    } catch (e) {
      print(
          "[Provider Fetch Error: $_otherUserId] Unexpected Error: ${e.toString()}");
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
        "[Provider AddSent: $_otherUserId] Adding message: TempID=${message.tempId}, RealID=${message.messageID}, Status=${message.status}, Type=${message.isMedia ? message.mediaType : 'text'}");
    final oldMessagesHashCode = state.messages.hashCode;
    state = state.copyWith(messages: [message, ...state.messages]);
    print(
        "[Provider AddSent: $_otherUserId] Message added. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. New count: ${state.messages.length}");
  }

  void addReceivedMessage(ChatMessage message) {
    if (!mounted) return;
    print(
        "[Provider AddRcvd: $_otherUserId] Adding received message: RealID=${message.messageID}, Type=${message.isMedia ? message.mediaType : 'text'}");
    final oldMessagesHashCode = state.messages.hashCode;
    state = state.copyWith(messages: [message, ...state.messages]);
    print(
        "[Provider AddRcvd: $_otherUserId] Message added. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. New count: ${state.messages.length}");
  }

  void updateMessageStatus(String tempId, ChatMessageStatus newStatus,
      {String? finalMediaUrl, String? errorMessage}) {
    if (!mounted) return;
    print(
        "[Provider UpdateStatus: $_otherUserId] Attempting update: TempID=$tempId, NewStatus=$newStatus, FinalURL=${finalMediaUrl != null}, Error=${errorMessage != null}");

    final currentMessages = state.messages;
    final messageIndex =
        currentMessages.indexWhere((msg) => msg.tempId == tempId);

    if (messageIndex != -1) {
      final messageToUpdate = currentMessages[messageIndex];
      print(
          "[Provider UpdateStatus: $_otherUserId] Found message at index $messageIndex. Current Status=${messageToUpdate.status}");

      final updatedMessage = messageToUpdate.copyWith(
        status: newStatus,
        mediaUrl: finalMediaUrl,
        errorMessage: errorMessage,
        clearErrorMessage: errorMessage == null,
        clearLocalFilePath: finalMediaUrl != null,
      );

      final updatedMessages = List<ChatMessage>.from(currentMessages);
      updatedMessages[messageIndex] = updatedMessage;

      final oldMessagesHashCode = state.messages.hashCode;
      final oldListIdentityHashCode =
          identityHashCode(state.messages); // Log list instance identity

      state = state.copyWith(messages: updatedMessages);

      final newListIdentityHashCode =
          identityHashCode(state.messages); // Log new list instance identity
      print(
          "[Provider UpdateStatus: $_otherUserId] Status updated for TempID $tempId. Final URL: ${updatedMessage.mediaUrl}. Error: ${updatedMessage.errorMessage}. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. List instance changed: ${oldListIdentityHashCode != newListIdentityHashCode}");
    } else {
      print(
          "[Provider UpdateStatus: $_otherUserId] WARNING: Could not find message with TempID $tempId to update status.");
    }
  }
}

// Provider definition remains the same
final conversationProvider =
    StateNotifierProvider.family<ConversationNotifier, ConversationState, int>(
        (ref, otherUserId) {
  final repo = ref.watch(chatRepositoryProvider);
  return ConversationNotifier(repo, otherUserId);
});
