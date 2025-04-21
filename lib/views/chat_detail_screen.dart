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
  final FocusNode _inputFocusNode = FocusNode(); // Explicit FocusNode

  @override
  void initState() {
    super.initState();
    // Add listener for focus debugging
    _inputFocusNode.addListener(_handleFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatService = ref.read(chatServiceProvider);
      if (ref.read(webSocketStateProvider) !=
          WebSocketConnectionState.connected) {
        print("[ChatDetailScreen] Connecting WebSocket...");
        chatService.connect();
      }
      // Fetch initial messages (or ensure provider does this)
      // The provider now fetches automatically on initialization
      // ref.read(conversationProvider(widget.matchUserId).notifier).fetchMessages();
    });
  }

  void _handleFocusChange() {
    print(
        "[ChatDetailScreen] Input Field Focus Changed: ${_inputFocusNode.hasFocus}");
    // No need to call setState unless UI depends on focus state
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.removeListener(_handleFocusChange); // Remove listener
    _inputFocusNode.dispose(); // Dispose FocusNode
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
      // Manually update the send button state after clearing
      ref.read(messageInputProvider.notifier).state = false;
      // Request focus back after sending? Sometimes helpful.
      FocusScope.of(context).requestFocus(_inputFocusNode);
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
      chatService.connect();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationProvider(widget.matchUserId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final wsState = ref.watch(webSocketStateProvider);

    ref.listen<ConversationState>(conversationProvider(widget.matchUserId),
        (prev, next) {
      bool messageAdded =
          (prev == null || next.messages.length != prev.messages.length);
      if (messageAdded) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          // Add back button
          icon:
              Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.grey[700]),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize:
              MainAxisSize.min, // Prevent Row taking full width unnecessarily
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
            const SizedBox(width: 10), // Reduced spacing slightly
            // Flexible helps prevent overflow if name is long
            Flexible(
              child: Text(
                widget.matchName,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis, // Handle long names
              ),
            ),
          ],
        ),
        titleSpacing: 0, // Reduce default title spacing
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0), // Increased padding
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
          Expanded(
            child: GestureDetector(
              // Add GestureDetector to dismiss keyboard
              onTap: () =>
                  FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
              child: _buildMessagesList(state, currentUserId),
            ),
          ),
          _buildMessageInputArea(), // Use the refined input area
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

    // *** ADD LOGGING HERE ***
    print(
        "[ChatDetailScreen _buildMessagesList] Building list. Message count: ${state.messages.length}");
    // Log the first few messages (rendered at the bottom) and the last (rendered at the top)
    for (int i = 0; i < state.messages.length; i++) {
      final msg = state.messages[i];
      print(
          "  - State[${i}]: '${msg.messageText}' (Sender: ${msg.senderUserID})");
      if (i >= 2 && state.messages.length > 5) {
        // Log first 3 and last one if list is long
        print("  - ...");
        final lastMsg = state.messages.last;
        print(
            "  - State[${state.messages.length - 1}]: '${lastMsg.messageText}' (Sender: ${lastMsg.senderUserID})");
        break;
      }
    }
    // *** END LOGGING ***

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(
          vertical: 10.0, horizontal: 8.0), // Added horizontal padding
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        final bool isMe = currentUserId != null && message.isMe(currentUserId);
        bool showTail = true;
        if (index > 0) {
          final prevMessage = state.messages[index - 1];
          if (prevMessage.senderUserID == message.senderUserID) {
            final timeDiff = message.sentAt.difference(prevMessage.sentAt);
            // Show tail only if previous message is older than ~1 minute
            if (timeDiff.inSeconds < 60) {
              showTail = false;
            }
          }
        }
        // Add some padding between bubbles
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: MessageBubble(
            message: message,
            isMe: isMe,
            showTail: showTail,
          ),
        );
      },
    );
  }

  Widget _buildMessageInputArea() {
    // Listen to the controller to enable/disable send button
    final canSend = ref.watch(messageInputProvider);

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                // Container to provide background and padding
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    focusNode: _inputFocusNode, // Use the explicit focus node
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                      border:
                          InputBorder.none, // No border inside the container
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12.0), // Adjust padding
                    ),
                    onChanged: (text) {
                      // Update the state provider controlling the send button
                      ref.read(messageInputProvider.notifier).state =
                          text.trim().isNotEmpty;
                    },
                    onTap: () {
                      // Debugging tap
                      print("[ChatDetailScreen] TextField tapped!");
                    },
                    onSubmitted: (_) =>
                        canSend ? _sendMessage() : null, // Send only if valid
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    style: GoogleFonts.poppins(
                        color: Colors.black87, fontSize: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            IconButton(
              icon: const Icon(Icons.send_rounded),
              color: const Color(0xFF8B5CF6),
              // Disable button if text is empty
              onPressed: canSend ? _sendMessage : null,
              tooltip: "Send Message",
              disabledColor: Colors.grey[400], // Visual cue when disabled
            ),
          ],
        ),
      ),
    );
  }
}

// Simple provider to track if the input field has text
final messageInputProvider = StateProvider<bool>((ref) => false);
