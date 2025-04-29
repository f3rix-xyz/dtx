// File: lib/providers/conversation_provider.dart
import 'dart:async';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/reaction_provider.dart';
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

  ConversationNotifier(this._ref, this._chatRepository, this._otherUserId)
      : super(const ConversationState()) {
    if (kDebugMode)
      print("[Provider Init: $_otherUserId] Fetching initial messages...");
    fetchMessages();
    _listenForReactionUpdates();
  }

  void _listenForReactionUpdates() {
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

  // --- updateOtherUserStatus (Keep as is) ---
  void updateOtherUserStatus(bool isOnline, DateTime eventTimestamp) {
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

  // --- fetchMessages (Keep as is from previous step) ---
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
    try {
      // API call now returns messages with reactionsSummary and currentUserReaction parsed by ChatMessage.fromJson
      final ConversationData conversationData =
          await _chatRepository.fetchConversation(otherUserId: _otherUserId);

      if (!mounted) return;

      final List<ChatMessage> fetchedMessages = conversationData.messages;

      // Update state directly
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
            "[Provider Fetch: $_otherUserId] API Fetch completed. Stored ${reversedMessages.length} messages (reactions parsed by model). API Status Set: isOnline=${state.otherUserIsOnline}, lastOnline=${state.otherUserLastOnline}. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}");
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
  // --- End fetchMessages ---

  // --- addSentMessage (Keep as is) ---
  void addSentMessage(ChatMessage message) {
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

  // --- addReceivedMessage (Keep as is) ---
  void addReceivedMessage(ChatMessage message) {
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

  // --- updateMessageStatus (Keep as is) ---
  void updateMessageStatus(String tempOrRealId, ChatMessageStatus newStatus,
      {int? finalMessageId, String? finalMediaUrl, String? errorMessage}) {
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

  // --- Reply State Methods (Keep as is) ---
  void startReplying(ChatMessage messageToReply) {
    if (!mounted) return;
    if (kDebugMode)
      print(
          "[Provider Reply: $_otherUserId] Starting reply to Message ID: ${messageToReply.messageID}");
    state = state.copyWith(replyingToMessage: () => messageToReply);
  }

  void cancelReply() {
    if (!mounted) return;
    if (state.replyingToMessage != null) {
      if (kDebugMode)
        print("[Provider Reply: $_otherUserId] Cancelling reply.");
      state = state.copyWith(replyingToMessage: () => null);
    }
  }
  // --- End Reply State Methods ---

  // --- optimisticallyApplyReaction (Keep as is from previous step) ---
  /// Updates the local state immediately when the current user reacts.
  void optimisticallyApplyReaction(int messageId, String emoji) {
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

    // Logic for optimistic update:
    if (previousReaction == emoji) {
      // User tapped the same emoji again - remove reaction
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
      // 1. Decrement previous reaction if it exists AND is different
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
      // 2. Increment new reaction
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
  // --- End optimisticallyApplyReaction ---

  // *** --- START: _applyReactionUpdate Method MODIFIED --- ***
  /// Reconciles the local state with updates received from the server.
  void _applyReactionUpdate(ReactionUpdate update) {
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

    // --- Start Reconciliation Logic ---

    // 1. Handle Previous Reaction of the *Reactor* specified in the update
    //    (Only relevant if the reactor is changing their reaction)
    String? previousEmojiForReactor = null;
    if (update.reactorUserId == currentUserId) {
      previousEmojiForReactor = messageToUpdate.currentUserReaction;
    } else {
      // If reactor is the *other* user, we don't store their specific previous
      // reaction locally, so we infer based on the counts. This is less precise
      // but necessary without storing other users' reactions explicitly.
      // Find *an* emoji in the current summary that this other user *might* have had.
      // This part is tricky and might not be perfectly accurate if multiple users react.
      // For simplicity, we'll focus on accurate reconciliation for the *current* user.
      // We'll simply adjust the counts based on the server event below.
    }

    // 2. Adjust Counts based *solely* on the Server Event
    if (update.isRemoved) {
      // Server says a reaction was removed
      if (update.emoji != null) {
        // Server tells us which emoji was removed
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
        // If it was the current user removing, we handle their state below.
        // If it was the *other* user, we can't know which emoji to decrement without the server telling us.
      }
    } else if (update.emoji != null) {
      // Server says a reaction was added/updated
      // If the reactor is the *current user* and they had a *different* previous reaction,
      // we need to decrement the count for that previous reaction first.
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

      // Now, increment the count for the emoji specified in the server update.
      // *** CRITICAL FIX: Check if this is just confirming our optimistic add ***
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
    // --- End Reconciliation Logic ---

    // Determine the current user's reaction based solely on SERVER update for *this* user
    String? serverCurrentUserReaction = messageToUpdate.currentUserReaction;
    if (update.reactorUserId == currentUserId) {
      serverCurrentUserReaction = update.isRemoved ? null : update.emoji;
      if (kDebugMode)
        print(
            "[Provider ApplyReaction RECONCILE: $_otherUserId] Server state for current user's reaction: ${serverCurrentUserReaction ?? 'null'}");
    }

    // --- State Update (if needed) ---
    // Check if the *final calculated state* differs from the *current UI state*
    final bool summaryChanged = !mapEquals(
        updatedSummary.isEmpty ? null : updatedSummary,
        messageToUpdate.reactionsSummary);
    final bool currentUserReactionChanged =
        serverCurrentUserReaction != messageToUpdate.currentUserReaction;

    if (!summaryChanged && !currentUserReactionChanged) {
      if (kDebugMode)
        print(
            "[Provider ApplyReaction RECONCILE: $_otherUserId] Calculated server state matches UI state for MsgID ${update.messageId}. No UI update needed.");
      return; // No need to update state if it already matches
    }

    if (kDebugMode)
      print(
          "[Provider ApplyReaction RECONCILE: $_otherUserId] State difference detected for MsgID ${update.messageId}. Updating UI state to match server.");

    // Create the updated message object based on the calculated server state
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
  // *** --- END: _applyReactionUpdate Method MODIFIED --- ***
} // End ConversationNotifier

// --- Provider Definition (Keep as is) ---
final conversationProvider = StateNotifierProvider.family
    .autoDispose<ConversationNotifier, ConversationState, int>(
        (ref, otherUserId) {
  final repo = ref.watch(chatRepositoryProvider);
  final notifier = ConversationNotifier(ref, repo, otherUserId);
  final statusSubscription =
      ref.listen<UserStatusUpdate?>(userStatusUpdateProvider, (prev, next) {
    if (next != null && next.userId == otherUserId) {
      notifier.updateOtherUserStatus(next.isOnline, next.timestamp);
    }
  });
  ref.onDispose(() {
    if (kDebugMode)
      print(
          "[Provider Dispose Hook: $otherUserId] Cancelling status listener subscription.");
    statusSubscription.close();
  });
  return notifier;
});
