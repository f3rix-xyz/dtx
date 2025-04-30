// File: lib/providers/conversation_provider.dart
// --- (Keep existing imports) ---
import 'dart:async';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/reaction_provider.dart';
import 'package:dtx/providers/read_update_provider.dart'; // <<<--- Ensure this is imported
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/status_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/repositories/chat_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/services/chat_service.dart';
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
  final ChatMessage? replyingToMessage;

  const ConversationState({
    this.isLoading = false,
    this.messages = const [],
    this.error,
    this.otherUserIsOnline = false,
    this.otherUserLastOnline,
    this.replyingToMessage,
  });

  ConversationState copyWith({
    bool? isLoading,
    List<ChatMessage>? messages,
    AppError? Function()? error,
    bool? otherUserIsOnline,
    DateTime? Function()? otherUserLastOnline,
    ChatMessage? Function()? replyingToMessage,
  }) {
    return ConversationState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      error: error != null ? error() : this.error,
      otherUserIsOnline: otherUserIsOnline ?? this.otherUserIsOnline,
      otherUserLastOnline: otherUserLastOnline != null
          ? otherUserLastOnline()
          : this.otherUserLastOnline,
      replyingToMessage: replyingToMessage != null
          ? replyingToMessage()
          : this.replyingToMessage,
    );
  }
}
// --- END ConversationState ---

class ConversationNotifier extends StateNotifier<ConversationState> {
  final ChatRepository _chatRepository;
  final int _otherUserId;
  final Ref _ref;

  // *** --- MODIFIED: Constructor (Phase 2) --- ***
  ConversationNotifier(this._ref, this._chatRepository, this._otherUserId)
      : super(const ConversationState()) {
    if (kDebugMode)
      print("[Provider Init: $_otherUserId] Fetching initial messages...");
    fetchMessages();
    _listenForReactionUpdates();
    _listenForReadUpdates(); // <-- Added call to start listening for read updates
  }
  // *** --- END MODIFIED --- ***

  void _listenForReactionUpdates() {
    // --- (Keep existing reaction listener code) ---
    if (kDebugMode)
      print(
          "[Provider ListenReactions: $_otherUserId] Setting up listener for reaction updates.");
    _ref.listen<ReactionUpdate?>(reactionUpdateProvider, (prev, next) {
      if (next != null) {
        if (kDebugMode)
          print(
              "[Provider ListenReactions CB: $_otherUserId] Received reaction update via provider: $next");
        final currentUserId = _ref.read(currentUserIdProvider);
        // Ensure the update is relevant and the message exists in state
        if ((next.reactorUserId == _otherUserId ||
                (currentUserId != null &&
                    next.reactorUserId == currentUserId)) &&
            state.messages.any((msg) => msg.messageID == next.messageId)) {
          if (kDebugMode)
            print(
                "[Provider ListenReactions CB: $_otherUserId] Update is relevant to this conversation. Applying...");
          _applyReactionUpdate(next);
        } else {
          if (kDebugMode)
            print(
                "[Provider ListenReactions CB: $_otherUserId] Update ignored: Not relevant or message ${next.messageId} not found.");
        }
      }
    });
  }

  // *** --- START: _listenForReadUpdates Added (Phase 2) --- ***
  /// Listens for read updates broadcasted by the ChatService via readUpdateProvider.
  void _listenForReadUpdates() {
    if (kDebugMode)
      print(
          "[Provider ListenRead: $_otherUserId] Setting up listener for read updates.");
    _ref.listen<ReadUpdate?>(readUpdateProvider, (prev, next) {
      if (next != null) {
        if (kDebugMode)
          print(
              "[Provider ListenRead CB: $_otherUserId] Received read update via provider: $next");
        // Check if the reader is the *other* user in this conversation
        if (next.readerUserId == _otherUserId) {
          if (kDebugMode)
            print(
                "[Provider ListenRead CB: $_otherUserId] Update is relevant (from other user). Applying...");
          // Call the method to update the message states
          _applyReadUpdate(next.lastReadMessageId);
        } else {
          if (kDebugMode)
            print(
                "[Provider ListenRead CB: $_otherUserId] Update ignored: Not from the other user in this conversation (Reader: ${next.readerUserId}).");
        }
      }
    });
  }
  // *** --- END: _listenForReadUpdates Added --- ***

  void updateOtherUserStatus(bool isOnline, DateTime eventTimestamp) {
    // --- (Keep existing implementation) ---
    if (!mounted) {
      if (kDebugMode)
        print(
            "[Provider UpdateStatus WS: $_otherUserId] Not mounted, ignoring update.");
      return;
    }
    if (state.otherUserIsOnline != isOnline) {
      if (kDebugMode)
        print(
            "[Provider UpdateStatus WS: $_otherUserId] Updating status from ${state.otherUserIsOnline} to $isOnline via WebSocket event.");
      final newLastOnline = isOnline ? null : eventTimestamp;
      state = state.copyWith(
        otherUserIsOnline: isOnline,
        otherUserLastOnline: () => newLastOnline,
      );
      if (kDebugMode)
        print(
            "[Provider UpdateStatus WS: $_otherUserId] State updated: isOnline=$isOnline, lastOnline=$newLastOnline");
    } else {
      if (kDebugMode)
        print(
            "[Provider UpdateStatus WS: $_otherUserId] Received status update, but otherUserIsOnline ($isOnline) is already the same. No state change needed.");
    }
  }

  // --- fetchMessages (Keep as is from Phase 1) ---
  Future<void> fetchMessages() async {
    if (state.isLoading) {
      if (kDebugMode)
        print(
            "[Provider Fetch: $_otherUserId] Skipping fetch: isLoading=${state.isLoading}");
      return;
    }
    if (kDebugMode)
      print(
          "[Provider Fetch: $_otherUserId] Fetching messages/status/reactions via API...");
    state = state.copyWith(isLoading: true, error: () => null);
    int? latestMessageIdFromOtherUser; // Variable to store the ID

    try {
      final ConversationData conversationData =
          await _chatRepository.fetchConversation(otherUserId: _otherUserId);

      if (!mounted) return;

      final List<ChatMessage> fetchedMessages = conversationData.messages;
      final oldMessagesHashCode = state.messages.hashCode;
      final reversedMessages = fetchedMessages.reversed.toList();

      state = state.copyWith(
        isLoading: false,
        messages: reversedMessages,
        otherUserIsOnline: conversationData.otherUserIsOnline,
        otherUserLastOnline: () => conversationData.otherUserLastOnline,
        error: () => null,
      );

      if (kDebugMode)
        print(
            "[Provider Fetch: $_otherUserId] API Fetch completed. Stored ${reversedMessages.length} messages. API Status Set: isOnline=${state.otherUserIsOnline}, lastOnline=${state.otherUserLastOnline}. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}");

      // --- Find latest message ID from the OTHER user ---
      for (final msg in fetchedMessages) {
        // Iterate the original fetch order (oldest to newest)
        if (msg.senderUserID == _otherUserId) {
          if (latestMessageIdFromOtherUser == null ||
              msg.messageID > latestMessageIdFromOtherUser!) {
            latestMessageIdFromOtherUser = msg.messageID;
          }
        }
      }

      if (kDebugMode && latestMessageIdFromOtherUser != null) {
        print(
            "[Provider Fetch: $_otherUserId] Found latest message ID from other user: $latestMessageIdFromOtherUser");
      } else if (kDebugMode) {
        print(
            "[Provider Fetch: $_otherUserId] No messages found from other user in this fetch.");
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

    // --- Send mark_read AFTER state update and outside try-catch ---
    if (latestMessageIdFromOtherUser != null &&
        latestMessageIdFromOtherUser > 0) {
      if (kDebugMode) {
        print(
            "[Provider Fetch: $_otherUserId] Sending mark_read via ChatService for otherUserId: $_otherUserId, lastMessageId: $latestMessageIdFromOtherUser");
      }
      try {
        _ref
            .read(chatServiceProvider)
            .sendMarkRead(_otherUserId, latestMessageIdFromOtherUser);
        if (kDebugMode) {
          print(
              "[Provider Fetch: $_otherUserId] sendMarkRead called successfully.");
        }
      } catch (e) {
        print(
            "[Provider Fetch Error: $_otherUserId] Failed to call sendMarkRead: $e");
      }
    } else {
      if (kDebugMode) {
        print(
            "[Provider Fetch: $_otherUserId] No relevant message ID found from other user, skipping sendMarkRead.");
      }
    }
  }

  void addSentMessage(ChatMessage message) {
    // ... (keep existing implementation) ...
    if (!mounted) return;
    if (kDebugMode)
      print(
          "[Provider AddSent: $_otherUserId] Adding message to START: TempID=${message.tempId}, RealID=${message.messageID}, Status=${message.status}, Type=${message.isMedia ? message.mediaType : 'text'}");
    final oldMessagesHashCode = state.messages.hashCode;
    state = state.copyWith(
      messages: [message, ...state.messages],
      replyingToMessage: () => null,
    );
    if (kDebugMode)
      print(
          "[Provider AddSent: $_otherUserId] Message added to start. Reply state cleared. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. New count: ${state.messages.length}");
  }

  void addReceivedMessage(ChatMessage message) {
    // ... (keep existing implementation) ...
    if (!mounted) return;
    if (kDebugMode)
      print(
          "[Provider AddRcvd: $_otherUserId] Adding received message to START: RealID=${message.messageID}, Type=${message.isMedia ? message.mediaType : 'text'}");
    final oldMessagesHashCode = state.messages.hashCode;
    state = state.copyWith(messages: [message, ...state.messages]);
    if (kDebugMode)
      print(
          "[Provider AddRcvd: $_otherUserId] Message added to start. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. New count: ${state.messages.length}");
  }

  void updateMessageStatus(String tempOrRealId, ChatMessageStatus newStatus,
      {int? finalMessageId, String? finalMediaUrl, String? errorMessage}) {
    // ... (keep existing implementation) ...
    if (!mounted) return;
    if (kDebugMode)
      print(
          "[Provider UpdateStatus API: $_otherUserId] Attempting update: ID=$tempOrRealId, NewStatus=$newStatus, FinalMsgID=$finalMessageId, FinalURL=${finalMediaUrl != null}, Error=${errorMessage != null}");
    final currentMessages = state.messages;
    final messageIndex = currentMessages.indexWhere((msg) =>
        (msg.tempId != null && msg.tempId == tempOrRealId) ||
        (msg.messageID != 0 && msg.messageID.toString() == tempOrRealId));
    if (messageIndex != -1) {
      final messageToUpdate = currentMessages[messageIndex];
      if (kDebugMode)
        print(
            "[Provider UpdateStatus API: $_otherUserId] Found message at index $messageIndex (Newest=0). Current Status=${messageToUpdate.status}");
      final updatedMessage = messageToUpdate.copyWith(
        status: newStatus,
        messageID: finalMessageId ?? messageToUpdate.messageID,
        mediaUrl: finalMediaUrl,
        errorMessage: errorMessage,
        clearErrorMessage: errorMessage == null,
        // NOTE: Do not clear localFilePath based on status update alone.
        // It should be cleared when the message is SENT and ACKNOWLEDGED potentially,
        // or handled by the UI component. Let's keep it for now for potential retry.
        clearLocalFilePath: false,
      );
      final updatedMessages = List<ChatMessage>.from(currentMessages);
      updatedMessages[messageIndex] = updatedMessage;
      final oldMessagesHashCode = state.messages.hashCode;
      final oldListIdentityHashCode = identityHashCode(state.messages);
      state = state.copyWith(messages: updatedMessages);
      final newListIdentityHashCode = identityHashCode(state.messages);
      if (kDebugMode)
        print(
            "[Provider UpdateStatus API: $_otherUserId] Status updated for ID $tempOrRealId. RealID: ${updatedMessage.messageID}, NewStatus: ${updatedMessage.status}. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}. List instance changed: ${oldListIdentityHashCode != newListIdentityHashCode}");
    } else {
      if (kDebugMode)
        print(
            "[Provider UpdateStatus API: $_otherUserId] WARNING: Could not find message with Temp/Real ID $tempOrRealId to update status.");
    }
  }

  void startReplying(ChatMessage messageToReply) {
    // ... (keep existing implementation) ...
    if (!mounted) return;
    if (kDebugMode)
      print(
          "[Provider Reply: $_otherUserId] Starting reply to Message ID: ${messageToReply.messageID}");
    state = state.copyWith(replyingToMessage: () => messageToReply);
  }

  void cancelReply() {
    // ... (keep existing implementation) ...
    if (!mounted) return;
    if (state.replyingToMessage != null) {
      if (kDebugMode)
        print("[Provider Reply: $_otherUserId] Cancelling reply.");
      state = state.copyWith(replyingToMessage: () => null);
    }
  }

  void optimisticallyApplyReaction(int messageId, String emoji) {
    // ... (keep existing implementation) ...
    if (!mounted) return;
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) return; // Should not happen

    if (kDebugMode)
      print(
          "[Provider OptimisticReact: $_otherUserId] Applying reaction optimistically for MsgID: $messageId, Emoji: $emoji");

    final messageIndex =
        state.messages.indexWhere((msg) => msg.messageID == messageId);
    if (messageIndex == -1) {
      if (kDebugMode)
        print(
            "[Provider OptimisticReact: $_otherUserId] Message ID $messageId not found. Cannot apply optimistically.");
      return;
    }

    final messageToUpdate = state.messages[messageIndex];
    final Map<String, int> updatedSummary =
        Map<String, int>.from(messageToUpdate.reactionsSummary ?? {});
    final String? previousReaction = messageToUpdate.currentUserReaction;
    String? newCurrentUserReaction;

    if (previousReaction == emoji) {
      updatedSummary[emoji] = (updatedSummary[emoji] ?? 1) - 1; // Decrement
      if (updatedSummary[emoji]! <= 0) {
        updatedSummary.remove(emoji); // Remove if count is zero or less
      }
      newCurrentUserReaction = null; // Clear current user reaction
      if (kDebugMode)
        print(
            "[Provider OptimisticReact: $_otherUserId] Optimistic REMOVAL of '$emoji'. New count: ${updatedSummary[emoji]}. User reaction cleared.");
    } else {
      // User is adding a new reaction or changing reaction
      if (previousReaction != null) {
        updatedSummary[previousReaction] =
            (updatedSummary[previousReaction] ?? 1) - 1; // Decrement
        if (updatedSummary[previousReaction]! <= 0) {
          updatedSummary.remove(previousReaction); // Remove if count is zero
        }
        if (kDebugMode)
          print(
              "[Provider OptimisticReact: $_otherUserId] Optimistic decrement of previous '$previousReaction'. New count: ${updatedSummary[previousReaction]}.");
      }
      updatedSummary[emoji] = (updatedSummary[emoji] ?? 0) + 1; // Increment
      newCurrentUserReaction = emoji; // Set new reaction
      if (kDebugMode)
        print(
            "[Provider OptimisticReact: $_otherUserId] Optimistic ADD/UPDATE to '$emoji'. New count: ${updatedSummary[emoji]}. User reaction set.");
    }

    final updatedMessage = messageToUpdate.copyWith(
      reactionsSummary: () => updatedSummary.isEmpty ? null : updatedSummary,
      currentUserReaction: () => newCurrentUserReaction,
    );

    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    final oldMessagesHashCode = state.messages.hashCode;
    state = state.copyWith(messages: updatedMessages);
    if (kDebugMode)
      print(
          "[Provider OptimisticReact: $_otherUserId] Optimistic update applied for MsgID: $messageId. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}");
  }

  void _applyReactionUpdate(ReactionUpdate update) {
    // ... (keep existing implementation) ...
    if (!mounted) return;
    if (kDebugMode)
      print(
          "[Provider ApplyReaction RECONCILE: $_otherUserId] Applying SERVER reaction update for MsgID: ${update.messageId}");

    final messageIndex =
        state.messages.indexWhere((msg) => msg.messageID == update.messageId);
    if (messageIndex == -1) {
      if (kDebugMode)
        print(
            "[Provider ApplyReaction RECONCILE: $_otherUserId] Message ID ${update.messageId} not found in current state. Ignoring server update.");
      return;
    }

    final messageToUpdate = state.messages[messageIndex];
    final currentUserId = _ref.read(currentUserIdProvider);
    final Map<String, int> updatedSummary =
        Map<String, int>.from(messageToUpdate.reactionsSummary ?? {});
    String? previousEmojiForReactor = null;
    if (update.reactorUserId == currentUserId) {
      previousEmojiForReactor = messageToUpdate.currentUserReaction;
    }

    if (update.isRemoved) {
      if (update.emoji != null) {
        updatedSummary[update.emoji!] =
            (updatedSummary[update.emoji!] ?? 1) - 1;
        if (updatedSummary[update.emoji!]! <= 0) {
          updatedSummary.remove(update.emoji!);
        }
        if (kDebugMode)
          print(
              "[Provider ApplyReaction RECONCILE: $_otherUserId] Server removed reaction '${update.emoji}'. New count: ${updatedSummary[update.emoji!]}");
      } else {
        if (kDebugMode)
          print(
              "[Provider ApplyReaction RECONCILE: $_otherUserId] WARNING: Server removal update without specific emoji for user ${update.reactorUserId}. Assuming removal based on reactor ID if it's current user.");
      }
    } else if (update.emoji != null) {
      if (update.reactorUserId == currentUserId &&
          previousEmojiForReactor != null &&
          previousEmojiForReactor != update.emoji) {
        updatedSummary[previousEmojiForReactor] =
            (updatedSummary[previousEmojiForReactor] ?? 1) - 1;
        if (updatedSummary[previousEmojiForReactor]! <= 0) {
          updatedSummary.remove(previousEmojiForReactor);
        }
        if (kDebugMode)
          print(
              "[Provider ApplyReaction RECONCILE: $_otherUserId] Decremented previous reaction '$previousEmojiForReactor' for current user.");
      }
      bool isConfirmingOptimisticAdd = update.reactorUserId == currentUserId &&
          messageToUpdate.currentUserReaction == update.emoji;
      if (!isConfirmingOptimisticAdd) {
        updatedSummary[update.emoji!] =
            (updatedSummary[update.emoji!] ?? 0) + 1;
        if (kDebugMode)
          print(
              "[Provider ApplyReaction RECONCILE: $_otherUserId] Server Added/Updated reaction '${update.emoji}'. New count: ${updatedSummary[update.emoji!]}");
      } else {
        if (kDebugMode)
          print(
              "[Provider ApplyReaction RECONCILE: $_otherUserId] Server confirmed optimistic add of '${update.emoji}'. Count remains ${updatedSummary[update.emoji!]}.");
      }
    }

    String? serverCurrentUserReaction = messageToUpdate.currentUserReaction;
    if (update.reactorUserId == currentUserId) {
      serverCurrentUserReaction = update.isRemoved ? null : update.emoji;
      if (kDebugMode)
        print(
            "[Provider ApplyReaction RECONCILE: $_otherUserId] Server state for current user's reaction: ${serverCurrentUserReaction ?? 'null'}");
    }

    final bool summaryChanged = !mapEquals(
        updatedSummary.isEmpty ? null : updatedSummary,
        messageToUpdate.reactionsSummary);
    final bool currentUserReactionChanged =
        serverCurrentUserReaction != messageToUpdate.currentUserReaction;

    if (!summaryChanged && !currentUserReactionChanged) {
      if (kDebugMode)
        print(
            "[Provider ApplyReaction RECONCILE: $_otherUserId] Calculated server state matches UI state for MsgID ${update.messageId}. No UI update needed.");
      return;
    }

    if (kDebugMode)
      print(
          "[Provider ApplyReaction RECONCILE: $_otherUserId] State difference detected for MsgID ${update.messageId}. Updating UI state to match server.");

    final updatedMessage = messageToUpdate.copyWith(
      reactionsSummary: () => updatedSummary.isEmpty ? null : updatedSummary,
      currentUserReaction: () => serverCurrentUserReaction,
    );

    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    final oldMessagesHashCode = state.messages.hashCode;
    state = state.copyWith(messages: updatedMessages);
    if (kDebugMode)
      print(
          "[Provider ApplyReaction RECONCILE: $_otherUserId] Reconciliation update applied for MsgID: ${update.messageId}. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}");
  }

  // *** --- START: _applyReadUpdate Added (Phase 2) --- ***
  /// Updates the isRead status of messages sent by the current user based on WS update.
  void _applyReadUpdate(int lastReadMessageId) {
    if (!mounted) {
      if (kDebugMode)
        print(
            "[Provider ApplyReadUpdate: $_otherUserId] Not mounted, ignoring read update.");
      return;
    }

    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      if (kDebugMode)
        print(
            "[Provider ApplyReadUpdate: $_otherUserId] Error: Current user ID is null. Cannot process read update.");
      return; // Safety check
    }

    if (kDebugMode)
      print(
          "[Provider ApplyReadUpdate: $_otherUserId] Applying read update from other user. Last read ID: $lastReadMessageId");

    bool stateChanged = false;
    // Map over the *current* list of messages in the state
    final List<ChatMessage> updatedMessages = state.messages.map((msg) {
      // Check if it's a message SENT BY ME, not already marked read, has a real ID,
      // AND its ID is less than or equal to the last read ID reported by the other user.
      if (msg.senderUserID == currentUserId &&
          !msg.isRead &&
          msg.messageID > 0 && // Ensure it's not an unsaved message
          msg.messageID <= lastReadMessageId) {
        if (kDebugMode)
          print(
              "[Provider ApplyReadUpdate: $_otherUserId] Marking message ID ${msg.messageID} as read.");
        stateChanged = true; // Flag that a change occurred
        // Return a *new* ChatMessage instance with the updated isRead status
        return msg.copyWith(isRead: true);
      }
      // Otherwise, return the original message object
      return msg;
    }).toList(); // Collect the results into a new list

    // Only update the state if any message's read status actually changed
    if (stateChanged) {
      final oldMessagesHashCode = state.messages.hashCode;
      state = state.copyWith(
          messages: updatedMessages); // Update the state with the new list
      if (kDebugMode)
        print(
            "[Provider ApplyReadUpdate: $_otherUserId] State updated with read receipts. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}");
    } else {
      if (kDebugMode)
        print(
            "[Provider ApplyReadUpdate: $_otherUserId] No messages needed updating for read receipt up to ID $lastReadMessageId.");
    }
  }
  // *** --- END: _applyReadUpdate Added --- ***
} // End ConversationNotifier

// --- Provider Definition (Keep as is) ---
final conversationProvider = StateNotifierProvider.family
    .autoDispose<ConversationNotifier, ConversationState, int>(
        (ref, otherUserId) {
  final repo = ref.watch(chatRepositoryProvider);
  final notifier = ConversationNotifier(ref, repo, otherUserId);
  // Listen to user status updates
  final statusSubscription =
      ref.listen<UserStatusUpdate?>(userStatusUpdateProvider, (prev, next) {
    if (next != null && next.userId == otherUserId) {
      notifier.updateOtherUserStatus(next.isOnline, next.timestamp);
    }
  });
  // Clean up listener on dispose
  ref.onDispose(() {
    if (kDebugMode)
      print(
          "[Provider Dispose Hook: $otherUserId] Cancelling status listener subscription.");
    statusSubscription.close();
    // No need to manually cancel readUpdateProvider or reactionUpdateProvider listeners here,
    // Riverpod handles listeners attached via ref.listen automatically.
  });
  return notifier;
});
