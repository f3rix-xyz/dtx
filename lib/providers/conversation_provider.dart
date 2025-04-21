// lib/providers/conversation_provider.dart
import 'dart:async';

import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/repositories/chat_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const int _messagesPageLimit = 30; // Number of messages to fetch per page

class ConversationState {
  final bool isLoading;
  final bool isFetchingMore;
  final List<ChatMessage> messages;
  final bool hasMore;
  final AppError? error;

  const ConversationState({
    this.isLoading = false,
    this.isFetchingMore = false,
    this.messages = const [],
    this.hasMore = true, // Assume more initially
    this.error,
  });

  ConversationState copyWith({
    bool? isLoading,
    bool? isFetchingMore,
    List<ChatMessage>? messages,
    bool? hasMore,
    AppError? Function()? error,
  }) {
    return ConversationState(
      isLoading: isLoading ?? this.isLoading,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      error: error != null ? error() : this.error,
    );
  }
}

class ConversationNotifier extends StateNotifier<ConversationState> {
  final ChatRepository _chatRepository;
  final int _otherUserId;
  int _currentOffset = 0;

  ConversationNotifier(this._chatRepository, this._otherUserId)
      : super(const ConversationState()) {
    fetchInitialMessages();
  }

  Future<void> fetchInitialMessages() async {
    if (state.isLoading) return;
    print("[ConversationNotifier-$_otherUserId] Fetching initial messages...");
    state = state.copyWith(isLoading: true, error: () => null);
    _currentOffset = 0; // Reset offset

    try {
      final result = await _chatRepository.fetchConversation(
        otherUserId: _otherUserId,
        limit: _messagesPageLimit,
        offset: _currentOffset,
      );
      final messages = result['messages'] as List<ChatMessage>;
      final hasMore = result['hasMore'] as bool;

      _currentOffset += messages.length;

      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          messages: messages,
          hasMore: hasMore,
        );
        print(
            "[ConversationNotifier-$_otherUserId] Fetched ${messages.length} initial messages. HasMore: $hasMore");
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

  Future<void> fetchMoreMessages() async {
    if (state.isLoading || state.isFetchingMore || !state.hasMore) return;
    print(
        "[ConversationNotifier-$_otherUserId] Fetching more messages (offset: $_currentOffset)...");
    state = state.copyWith(isFetchingMore: true);

    try {
      final result = await _chatRepository.fetchConversation(
        otherUserId: _otherUserId,
        limit: _messagesPageLimit,
        offset: _currentOffset,
      );
      final newMessages = result['messages'] as List<ChatMessage>;
      final hasMore = result['hasMore'] as bool;

      _currentOffset += newMessages.length;

      if (mounted) {
        state = state.copyWith(
          isFetchingMore: false,
          messages: [...state.messages, ...newMessages], // Prepend new messages
          hasMore: hasMore,
        );
        print(
            "[ConversationNotifier-$_otherUserId] Fetched ${newMessages.length} more messages. HasMore: $hasMore");
      }
    } on ApiException catch (e) {
      print(
          "[ConversationNotifier-$_otherUserId] More API Exception: ${e.message}");
      if (mounted) {
        state = state.copyWith(
            isFetchingMore: false,
            error: () =>
                AppError.server(e.message)); // Show error fetching more
      }
    } catch (e) {
      print(
          "[ConversationNotifier-$_otherUserId] More Unexpected Error: ${e.toString()}");
      if (mounted) {
        state = state.copyWith(
            isFetchingMore: false,
            error: () => AppError.generic("Failed to load more messages."));
      }
    }
  }

  // Add a message sent by the current user (optimistic update maybe?)
  void addSentMessage(ChatMessage message) {
    if (!mounted) return;
    print(
        "[ConversationNotifier-$_otherUserId] Adding sent message: ${message.messageText}");
    // Add to the beginning of the list for reversed view
    state = state.copyWith(messages: [message, ...state.messages]);
  }

  // Add a message received from the other user
  void addReceivedMessage(ChatMessage message) {
    if (!mounted) return;
    print(
        "[ConversationNotifier-$_otherUserId] Adding received message: ${message.messageText}");
    // Add to the beginning of the list for reversed view
    state = state.copyWith(messages: [message, ...state.messages]);
    // Potentially mark as read here or trigger read status update? Backend handles read on fetch.
  }
}

// Family provider to get conversation for a specific user
final conversationProvider =
    StateNotifierProvider.family<ConversationNotifier, ConversationState, int>(
        (ref, otherUserId) {
  final repo = ref.watch(chatRepositoryProvider);
  return ConversationNotifier(repo, otherUserId);
});
