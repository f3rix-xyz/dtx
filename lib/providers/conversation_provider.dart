// File: lib/providers/conversation_provider.dart
import 'dart:async';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/service_provider.dart';
// Removed unused service_provider import
import 'package:dtx/providers/status_provider.dart';
import 'package:dtx/repositories/chat_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

// --- ConversationData Class (Keep as is) ---
class ConversationData {
  final List<ChatMessage> messages;
  final bool otherUserIsOnline;
  final DateTime? otherUserLastOnline;
  ConversationData(
      {required this.messages,
      required this.otherUserIsOnline,
      this.otherUserLastOnline});
}
// ---

// --- ConversationState Class (Keep as is) ---
class ConversationState {
  final bool isLoading;
  final List<ChatMessage> messages;
  final AppError? error;
  final bool otherUserIsOnline;
  final DateTime? otherUserLastOnline;

  const ConversationState({
    this.isLoading = false,
    this.messages = const [],
    this.error,
    this.otherUserIsOnline = false,
    this.otherUserLastOnline,
  });

  ConversationState copyWith({
    bool? isLoading,
    List<ChatMessage>? messages,
    AppError? Function()? error,
    bool? otherUserIsOnline,
    DateTime? Function()? otherUserLastOnline,
  }) {
    return ConversationState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      error: error != null ? error() : this.error,
      otherUserIsOnline: otherUserIsOnline ?? this.otherUserIsOnline,
      otherUserLastOnline: otherUserLastOnline != null
          ? otherUserLastOnline()
          : this.otherUserLastOnline,
    );
  }
}
// ---

class ConversationNotifier extends StateNotifier<ConversationState> {
  final ChatRepository _chatRepository;
  final int _otherUserId;
  // No longer need Ref or explicit subscription here

  ConversationNotifier(this._chatRepository, this._otherUserId)
      : super(const ConversationState()) {
    // Initial fetch is still good here
    print("[Provider Init: $_otherUserId] Fetching initial messages...");
    fetchMessages();
  }

  // No need for _listenToStatusUpdates here, handled by provider definition

  // --- Keep _updateOtherUserStatus ---
  // This method is now called directly by the listener in the provider definition
  void updateOtherUserStatus(bool isOnline, DateTime eventTimestamp) {
    if (!mounted) {
      print(
          "[Provider UpdateStatus WS: $_otherUserId] Not mounted, ignoring update.");
      return;
    }

    if (state.otherUserIsOnline != isOnline) {
      print(
          "[Provider UpdateStatus WS: $_otherUserId] Updating status from ${state.otherUserIsOnline} to $isOnline via WebSocket event.");

      final newLastOnline = isOnline ? null : eventTimestamp;

      state = state.copyWith(
        otherUserIsOnline: isOnline,
        otherUserLastOnline: () => newLastOnline,
      );
      print(
          "[Provider UpdateStatus WS: $_otherUserId] State updated: isOnline=$isOnline, lastOnline=$newLastOnline");
    } else {
      if (kDebugMode)
        print(
            "[Provider UpdateStatus WS: $_otherUserId] Received status update, but otherUserIsOnline ($isOnline) is already the same. No state change needed.");
    }
  }
  // ---

  // --- fetchMessages (Keep as is, including logging) ---
  Future<void> fetchMessages() async {
    if (state.isLoading) {
      print(
          "[Provider Fetch: $_otherUserId] Skipping fetch: isLoading=${state.isLoading}");
      return;
    }

    print(
        "[Provider Fetch: $_otherUserId] Fetching ALL messages and status via API...");
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final ConversationData conversationData =
          await _chatRepository.fetchConversation(otherUserId: _otherUserId);

      if (mounted) {
        bool statusBeforeAPISet = state.otherUserIsOnline;
        DateTime? lastOnlineBeforeAPISet = state.otherUserLastOnline;

        final oldMessagesHashCode = state.messages.hashCode;
        final reversedMessages = conversationData.messages.reversed.toList();

        state = state.copyWith(
          isLoading: false,
          messages: reversedMessages,
          // Set status based on API result during fetch
          otherUserIsOnline: conversationData.otherUserIsOnline,
          otherUserLastOnline: () => conversationData.otherUserLastOnline,
        );

        print(
            "[Provider Fetch: $_otherUserId] API Fetch completed. Fetched ${conversationData.messages.length} messages. Stored ${reversedMessages.length} (Newest first). API Status Set: isOnline=${state.otherUserIsOnline}, lastOnline=${state.otherUserLastOnline}. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}");

        // Log if API fetch potentially overwrote a very recent WS update
        if (kDebugMode &&
            (statusBeforeAPISet != state.otherUserIsOnline ||
                lastOnlineBeforeAPISet != state.otherUserLastOnline)) {
          print(
              "[Provider Fetch: $_otherUserId] Note: API status set. If a WS update occurred during fetch, it might be momentarily overwritten until the *next* WS event.");
        }
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

  // --- addSentMessage (Keep as is) ---
  void addSentMessage(ChatMessage message) {
    if (!mounted) return;
    print(
        "[Provider AddSent: $_otherUserId] Adding message to START: TempID=${message.tempId}, RealID=${message.messageID}, Status=${message.status}, Type=${message.isMedia ? message.mediaType : 'text'}");
    final oldMessagesHashCode = state.messages.hashCode;
    state = state.copyWith(messages: [message, ...state.messages]);
    print(
        "[Provider AddSent: $_otherUserId] Message added to start. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. New count: ${state.messages.length}");
  }

  // --- addReceivedMessage (Keep as is) ---
  void addReceivedMessage(ChatMessage message) {
    if (!mounted) return;
    print(
        "[Provider AddRcvd: $_otherUserId] Adding received message to START: RealID=${message.messageID}, Type=${message.isMedia ? message.mediaType : 'text'}");
    final oldMessagesHashCode = state.messages.hashCode;
    state = state.copyWith(messages: [message, ...state.messages]);
    print(
        "[Provider AddRcvd: $_otherUserId] Message added to start. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. New count: ${state.messages.length}");
  }

  // --- updateMessageStatus (Keep as is) ---
  void updateMessageStatus(String tempOrRealId, ChatMessageStatus newStatus,
      {int? finalMessageId, String? finalMediaUrl, String? errorMessage}) {
    if (!mounted) return;
    print(
        "[Provider UpdateStatus API: $_otherUserId] Attempting update: ID=$tempOrRealId, NewStatus=$newStatus, FinalMsgID=$finalMessageId, FinalURL=${finalMediaUrl != null}, Error=${errorMessage != null}");

    final currentMessages = state.messages;
    final messageIndex = currentMessages.indexWhere((msg) =>
        (msg.tempId != null && msg.tempId == tempOrRealId) ||
        (msg.messageID != 0 && msg.messageID.toString() == tempOrRealId));

    if (messageIndex != -1) {
      final messageToUpdate = currentMessages[messageIndex];
      print(
          "[Provider UpdateStatus API: $_otherUserId] Found message at index $messageIndex (Newest=0). Current Status=${messageToUpdate.status}");

      final updatedMessage = messageToUpdate.copyWith(
        status: newStatus,
        messageID: finalMessageId ?? messageToUpdate.messageID,
        mediaUrl: finalMediaUrl,
        errorMessage: errorMessage,
        clearErrorMessage: errorMessage == null,
        clearLocalFilePath: false,
      );

      final updatedMessages = List<ChatMessage>.from(currentMessages);
      updatedMessages[messageIndex] = updatedMessage;

      final oldMessagesHashCode = state.messages.hashCode;
      final oldListIdentityHashCode = identityHashCode(state.messages);

      state = state.copyWith(messages: updatedMessages);

      final newListIdentityHashCode = identityHashCode(state.messages);
      print(
          "[Provider UpdateStatus API: $_otherUserId] Status updated for ID $tempOrRealId. RealID: ${updatedMessage.messageID}, NewStatus: ${updatedMessage.status}. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. List instance changed: ${oldListIdentityHashCode != newListIdentityHashCode}");
    } else {
      print(
          "[Provider UpdateStatus API: $_otherUserId] WARNING: Could not find message with Temp/Real ID $tempOrRealId to update status.");
    }
  }

  // No explicit dispose needed here anymore, autoDispose handles it
}

// --- UPDATED Provider Definition ---
final conversationProvider = StateNotifierProvider.family
    .autoDispose<ConversationNotifier, ConversationState, int>(
        (ref, otherUserId) {
  final repo = ref.watch(chatRepositoryProvider);
  final notifier = ConversationNotifier(repo, otherUserId);

  // Listen to the global status updates provider
  final statusSubscription =
      ref.listen<UserStatusUpdate?>(userStatusUpdateProvider, (prev, next) {
    if (next != null && next.userId == otherUserId) {
      // If the update is for this conversation's user, call the notifier's method
      notifier.updateOtherUserStatus(next.isOnline, next.timestamp);
    }
  });

  // Ensure the subscription is cancelled when the provider is disposed
  ref.onDispose(() {
    print(
        "[Provider Dispose Hook: $otherUserId] Cancelling status listener subscription.");
    statusSubscription.close(); // Use close() on the subscription object
  });

  return notifier;
});
// --- END UPDATED ---
