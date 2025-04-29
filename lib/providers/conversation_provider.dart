// File: lib/providers/conversation_provider.dart
import 'dart:async';
// Removed unused json import
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/reaction_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/status_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/repositories/chat_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/services/chat_service.dart';
// Removed unused chat_service import
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
    fetchMessages(); // Fetch initial data
    _listenForReactionUpdates(); // Start listening for WS reaction updates
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
        // *** Filter update to only process if it's for this conversation ***
        // Check if the reactor or the other user in the convo matches _otherUserId
        // OR if the reactor is the current user (reacting to a message *from* _otherUserId)
        final currentUserId = _ref.read(currentUserIdProvider);
        if (next.reactorUserId ==
                _otherUserId || // Reaction from the other user
            (currentUserId != null && next.reactorUserId == currentUserId)) {
          // Reaction from me
          // Now check if the message actually belongs to this convo
          if (state.messages.any((msg) => msg.messageID == next.messageId)) {
            if (kDebugMode)
              print(
                  "[Provider ListenReactions CB: $_otherUserId] Update is relevant to this conversation. Applying...");
            _applyReactionUpdate(next);
          } else {
            if (kDebugMode)
              print(
                  "[Provider ListenReactions CB: $_otherUserId] Update is for a relevant user BUT message ${next.messageId} not found in current list. Ignoring.");
          }
        } else {
          if (kDebugMode)
            print(
                "[Provider ListenReactions CB: $_otherUserId] Update is for user ${next.reactorUserId}, which is not relevant to this conversation with $_otherUserId. Ignoring.");
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

  // --- *** SIMPLIFIED: fetchMessages *** ---
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
      // Step 1: Fetch main conversation data
      // ChatMessage.fromJson now handles parsing 'reactions' and 'current_user_reaction'
      final ConversationData conversationData =
          await _chatRepository.fetchConversation(otherUserId: _otherUserId);

      if (!mounted) return; // Check mount before setting state

      // Step 2: Update state directly (no separate reaction fetch needed)
      final oldMessagesHashCode = state.messages.hashCode;
      // Reverse the list for UI (newest first)
      final reversedMessages = conversationData.messages.reversed.toList();

      state = state.copyWith(
        isLoading: false,
        messages: reversedMessages, // Messages already include reaction info
        otherUserIsOnline: conversationData.otherUserIsOnline,
        otherUserLastOnline: () => conversationData.otherUserLastOnline,
        error: () => null, // Clear error on success
      );

      if (kDebugMode)
        print(
            "[Provider Fetch: $_otherUserId] API Fetch completed. Stored ${reversedMessages.length} messages (with reactions parsed). API Status Set: isOnline=${state.otherUserIsOnline}, lastOnline=${state.otherUserLastOnline}. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}");
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
  // --- *** END SIMPLIFIED fetchMessages *** ---

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

  // --- _applyReactionUpdate Method (Keep as is, now relies on correct model parsing) ---
  void _applyReactionUpdate(ReactionUpdate update) {
    if (!mounted) return;
    if (kDebugMode)
      print(
          "[Provider ApplyReaction: $_otherUserId] Applying reaction update for MsgID: ${update.messageId}");
    final messageIndex =
        state.messages.indexWhere((msg) => msg.messageID == update.messageId);
    if (messageIndex == -1) {
      if (kDebugMode)
        print(
            "[Provider ApplyReaction: $_otherUserId] Message ID ${update.messageId} not found in current state. Ignoring update.");
      return;
    }
    final messageToUpdate = state.messages[messageIndex];
    final currentUserId = _ref.read(currentUserIdProvider);

    // --- Logic to update reaction summary ---
    final Map<String, int> updatedSummary =
        Map<String, int>.from(messageToUpdate.reactionsSummary ?? {});
    String?
        previousEmojiForReactor; // Find the previous emoji this user had, if any

    // Find previous reaction ONLY IF this is an ADD/UPDATE (not removal)
    // or if it's a removal WITHOUT a specific emoji provided (less ideal case)
    if (!update.isRemoved || (update.isRemoved && update.emoji == null)) {
      // Try to find if the reactor had a *different* previous reaction
      messageToUpdate.reactionsSummary?.forEach((emoji, count) {
        // This is tricky without knowing *who* reacted with what previously.
        // The backend ideally should handle decrementing the *correct* previous emoji count
        // if a user changes their reaction.
        // We will assume for now the summary update logic handles this.
        // If the backend simply adds the new one without removing the old one
        // in the summary count for a user *changing* reaction, this needs more complex handling.
        // Let's assume the backend summary is mostly accurate based on additions/removals.

        // We still need to track the specific previous emoji *this user* had
        // if they are changing their reaction. The WS update doesn't give us that.
        // The simplest approach is to just update the count for the new emoji
        // and remove the old one if the user is the reactor.

        // If current_user_reaction was set from API, we know the old one for this user
        if (update.reactorUserId == currentUserId &&
            messageToUpdate.currentUserReaction != null) {
          previousEmojiForReactor = messageToUpdate.currentUserReaction;
        }
      });
    }

    // Update counts based on the incoming WebSocket event
    if (update.isRemoved) {
      if (update.emoji != null) {
        updatedSummary[update.emoji!] =
            (updatedSummary[update.emoji!] ?? 0) - 1;
        if (updatedSummary[update.emoji!]! <= 0) {
          updatedSummary.remove(update.emoji!);
        }
        if (kDebugMode)
          print(
              "[Provider ApplyReaction: $_otherUserId] Decremented/Removed reaction '${update.emoji}' from summary. New count: ${updatedSummary[update.emoji!]}");
      } else {
        // Removal without specific emoji: Cannot reliably update summary counts.
        if (kDebugMode)
          print(
              "[Provider ApplyReaction: $_otherUserId] WARNING: Received removal without specific emoji for user ${update.reactorUserId}. Summary map may be inaccurate if user had multiple reactions.");
      }
    } else if (update.emoji != null) {
      // If reactor is changing reaction, decrement their previous one first
      if (update.reactorUserId == currentUserId &&
          previousEmojiForReactor != null &&
          previousEmojiForReactor != update.emoji) {
        updatedSummary[previousEmojiForReactor!] =
            (updatedSummary[previousEmojiForReactor] ?? 0) - 1;
        if (updatedSummary[previousEmojiForReactor]! <= 0) {
          updatedSummary.remove(previousEmojiForReactor);
        }
        if (kDebugMode)
          print(
              "[Provider ApplyReaction: $_otherUserId] Decremented previous reaction '$previousEmojiForReactor' for reactor $currentUserId.");
      }

      // Increment the new/updated reaction
      updatedSummary[update.emoji!] = (updatedSummary[update.emoji!] ?? 0) + 1;
      if (kDebugMode)
        print(
            "[Provider ApplyReaction: $_otherUserId] Incremented/Added reaction '${update.emoji}'. New count: ${updatedSummary[update.emoji!]}");
    }

    // Determine the current user's reaction after the update
    String? newCurrentUserReaction = messageToUpdate.currentUserReaction;
    if (update.reactorUserId == currentUserId) {
      newCurrentUserReaction = update.isRemoved ? null : update.emoji;
      if (kDebugMode)
        print(
            "[Provider ApplyReaction: $_otherUserId] Current user's (${currentUserId}) reaction updated to: ${newCurrentUserReaction ?? 'null'}");
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
          "[Provider ApplyReaction: $_otherUserId] Reaction update applied for MsgID: ${update.messageId}. List hashCode changed: ${state.messages.hashCode != oldMessagesHashCode}");
  }
  // --- END _applyReactionUpdate Method ---
}

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
// --- END Provider Definition ---
