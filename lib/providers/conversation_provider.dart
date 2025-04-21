// lib/providers/conversation_provider.dart
import 'dart:async';

import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/repositories/chat_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    if (state.isLoading) return;
    print("[ConversationNotifier-$_otherUserId] Fetching ALL messages...");
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      // Fetch messages (currently oldest first from repo)
      final messagesFromRepo = await _chatRepository.fetchConversation(
        otherUserId: _otherUserId,
      );

      if (mounted) {
        // *** REVERSE the list HERE before setting state ***
        final reversedMessages = messagesFromRepo.reversed.toList();
        // *** END REVERSAL ***

        state = state.copyWith(
          isLoading: false,
          messages: reversedMessages, // Store newest message at index 0
        );
        print(
            "[ConversationNotifier-$_otherUserId] Fetched and reversed ${reversedMessages.length} total messages.");
      }
    } on ApiException catch (e) {
      print("[ConversationNotifier-$_otherUserId] API Exception: ${e.message}");
      if (mounted) {
        state = state.copyWith(
            isLoading: false, error: () => AppError.server(e.message));
      }
    } catch (e) {
      print(
          "[ConversationNotifier-$_otherUserId] Unexpected Error: ${e.toString()}");
      if (mounted) {
        state = state.copyWith(
            isLoading: false,
            error: () => AppError.generic("Failed to load conversation."));
      }
    }
  }

  // addSentMessage and addReceivedMessage correctly prepend (add to index 0)
  // so they DO NOT need to be changed.
  void addSentMessage(ChatMessage message) {
    if (!mounted) return;
    print(
        "[ConversationNotifier-$_otherUserId] Adding sent message: ${message.messageText}");
    // Prepending means the newest is always at index 0
    state = state.copyWith(messages: [message, ...state.messages]);
  }

  void addReceivedMessage(ChatMessage message) {
    if (!mounted) return;
    print(
        "[ConversationNotifier-$_otherUserId] Adding received message: ${message.messageText}");
    // Prepending means the newest is always at index 0
    state = state.copyWith(messages: [message, ...state.messages]);
  }
}

// Provider definition remains the same
final conversationProvider =
    StateNotifierProvider.family<ConversationNotifier, ConversationState, int>(
        (ref, otherUserId) {
  final repo = ref.watch(chatRepositoryProvider);
  return ConversationNotifier(repo, otherUserId);
});
