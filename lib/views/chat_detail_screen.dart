// lib/views/chat_detail_screen.dart
import 'dart:async';

import 'package:dtx/models/chat_message.dart';
import 'package:dtx/providers/conversation_provider.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/service_provider.dart'; // For ChatService
import 'package:dtx/providers/user_provider.dart'; // For current user ID
import 'package:dtx/services/chat_service.dart'; // For WebSocketState
import 'package:dtx/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final int matchUserId;
  final String matchName;
  final String? matchAvatarUrl;

  const ChatDetailScreen({
    super.key,
    required this.matchUserId,
    required this.matchName,
    this.matchAvatarUrl,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Ensure WebSocket connection is active when entering chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatService = ref.read(chatServiceProvider);
      if (ref.read(webSocketStateProvider) !=
          WebSocketConnectionState.connected) {
        print("[ChatDetailScreen] Connecting WebSocket...");
        chatService.connect();
      }
      _setupScrollListener();
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Check if scrolled to the top (or near the top)
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        // Trigger slightly before top
        // Fetch more messages if available
        final conversationState =
            ref.read(conversationProvider(widget.matchUserId));
        if (conversationState.hasMore && !conversationState.isFetchingMore) {
          ref
              .read(conversationProvider(widget.matchUserId).notifier)
              .fetchMoreMessages();
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Optional: Disconnect WebSocket here if it should only be active
    // while a chat screen is open. If it should persist globally,
    // manage connection/disconnection elsewhere (e.g., based on app lifecycle).
    // ref.read(chatServiceProvider).disconnect();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatService = ref.read(chatServiceProvider);
    final wsState = ref.read(webSocketStateProvider);

    if (wsState == WebSocketConnectionState.connected) {
      chatService.sendMessage(widget.matchUserId, text);
      _messageController.clear();
      // Scroll to bottom after sending (with slight delay for UI update)
      Timer(const Duration(milliseconds: 100), _scrollToBottom);
    } else {
      print(
          "[ChatDetailScreen] Cannot send, WebSocket not connected. State: $wsState");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cannot send message. Not connected.",
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
        ),
      );
      // Optionally try to reconnect?
      chatService.connect();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // Scroll to the top in a reversed list
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationProvider(widget.matchUserId));
    final currentUserId =
        ref.watch(currentUserIdProvider); // Get current user ID
    final wsState = ref.watch(webSocketStateProvider);

    // Scroll to bottom when new messages are added (after build)
    ref.listen<ConversationState>(conversationProvider(widget.matchUserId),
        (prev, next) {
      if (prev != null && next.messages.length > prev.messages.length) {
        // Only scroll if a new message was added (not just loading state change)
        // Use WidgetsBinding to schedule scroll after build
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.matchAvatarUrl != null
                  ? NetworkImage(widget.matchAvatarUrl!)
                  : null,
              backgroundColor: Colors.grey[300],
              child: widget.matchAvatarUrl == null
                  ? const Icon(Icons.person, size: 20, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              widget.matchName,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          // Optional: Connection Status Indicator
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Icon(
              Icons.circle,
              size: 10,
              color: wsState == WebSocketConnectionState.connected
                  ? Colors.green
                  : (wsState == WebSocketConnectionState.connecting
                      ? Colors.orange
                      : Colors.red),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Message List ---
          Expanded(
            child: _buildMessagesList(state, currentUserId),
          ),
          // --- Loading Indicator for Pagination ---
          if (state.isFetchingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                  child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF8B5CF6)))),
            ),
          // --- Message Input Area ---
          _buildMessageInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ConversationState state, int? currentUserId) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    if (state.error != null && state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            "Error loading messages: ${state.error!.message}",
            style: GoogleFonts.poppins(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!state.isLoading && state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            "Start the conversation!",
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Show newest messages at the bottom
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        final bool isMe = currentUserId != null && message.isMe(currentUserId);
        // Determine if the previous message was from the same sender
        // to adjust bubble appearance (e.g., tail)
        bool showTail = true;
        if (index > 0) {
          final prevMessage = state.messages[index - 1];
          if (prevMessage.senderUserID == message.senderUserID) {
            showTail = false;
          }
        }
        return MessageBubble(
          message: message,
          isMe: isMe,
          showTail: showTail, // Pass showTail to the bubble
        );
      },
    );
  }

  Widget _buildMessageInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        // Ensure input isn't under system UI (like home bar)
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10.0),
                ),
                onSubmitted: (_) => _sendMessage(), // Send on keyboard submit
                minLines: 1,
                maxLines: 5, // Allow multiline input
                keyboardType: TextInputType.multiline, // Set keyboard type
              ),
            ),
            const SizedBox(width: 8.0),
            IconButton(
              icon: const Icon(Icons.send_rounded),
              color: const Color(0xFF8B5CF6),
              onPressed: _sendMessage,
              tooltip: "Send Message",
            ),
          ],
        ),
      ),
    );
  }
}
