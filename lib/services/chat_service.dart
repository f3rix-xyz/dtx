// START OF FILE: lib/services/chat_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Keep for potential future use, though not directly used now
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as WebSocketStatus;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:dtx/models/chat_message.dart';
import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/providers/conversation_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/utils/token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum WebSocketConnectionState { disconnected, connecting, connected, error }

final webSocketStateProvider = StateProvider<WebSocketConnectionState>(
    (ref) => WebSocketConnectionState.disconnected);

class ChatService {
  final Ref _ref;
  final String _wsUrl;
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  Timer? _reconnectTimer;
  bool _isManualDisconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 2);

  ChatService(this._ref, this._wsUrl) {
    print("[ChatService] Initialized with URL: $_wsUrl");
  }

  Future<void> connect() async {
    _isManualDisconnect = false; // Reset flag on connect attempt
    if (_channel != null &&
        _ref.read(webSocketStateProvider) ==
            WebSocketConnectionState.connected) {
      print("[ChatService] Already connected.");
      return;
    }
    if (_ref.read(webSocketStateProvider) ==
        WebSocketConnectionState.connecting) {
      print("[ChatService] Connection attempt already in progress.");
      return;
    }

    print("[ChatService] Attempting to connect to $_wsUrl...");
    _updateState(WebSocketConnectionState.connecting);

    String? token =
        _ref.read(authProvider).jwtToken ?? await TokenStorage.getToken();

    if (token == null) {
      print("[ChatService] Connection failed: Auth token not found.");
      _updateState(WebSocketConnectionState.error); // Or disconnected
      return;
    }

    try {
      final headers = {'Authorization': 'Bearer $token'};
      _channel = IOWebSocketChannel.connect(
        Uri.parse(_wsUrl),
        headers: headers,
        pingInterval: const Duration(seconds: 15),
      );

      print("[ChatService] WebSocket channel created. Listening...");

      _streamSubscription = _channel!.stream.listen(
        _onMessageReceived,
        onDone: _handleDisconnect,
        onError: _handleError,
        cancelOnError: false,
      );

      _updateState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
      print("[ChatService] Connection established successfully.");
    } catch (e) {
      print("[ChatService] Connection failed: $e");
      _handleError(e);
    }
  }

  // --- Phase 2: Needs modification later ---
  void _onMessageReceived(dynamic message) {
    print("[ChatService] Message received: $message");
    try {
      final Map<String, dynamic> decodedMessage = jsonDecode(message);
      final type = decodedMessage['type'] as String?;
      final senderId = decodedMessage['sender_user_id'] as int?;
      final currentUserId = _ref.read(currentUserIdProvider);

      if (currentUserId == null) {
        print("[ChatService] Cannot process message: Current User ID is null.");
        return;
      }

      // --- THIS PART NEEDS TO BE UPDATED IN PHASE 2 ---
      // Current logic incorrectly expects type='text', 'image' etc.
      ChatMessage chatMessage;
      if (type == 'text' && senderId != null) {
        // <<< ISSUE: Expects type='text'
        chatMessage = ChatMessage(
          messageID: 0, // <<< ISSUE: Uses 0, should use server ID
          senderUserID: senderId,
          recipientUserID: currentUserId,
          messageText: decodedMessage['text'] as String? ?? '',
          sentAt: DateTime.now().toUtc(), // <<< ISSUE: Uses local time
          isRead: false,
          readAt: null,
          mediaUrl: null,
          mediaType: null,
        );
      } else if (['image', 'video', 'audio', 'file'].contains(type) &&
          senderId != null) {
        // <<< ISSUE: Expects type='image' etc.
        chatMessage = ChatMessage(
          messageID: 0, // <<< ISSUE: Uses 0
          senderUserID: senderId,
          recipientUserID: currentUserId,
          messageText: '',
          sentAt: DateTime.now().toUtc(), // <<< ISSUE: Uses local time
          isRead: false,
          readAt: null,
          mediaUrl: decodedMessage['media_url'] as String?,
          mediaType: decodedMessage['media_type'] as String?,
        );
      } else if (type == 'error') {
        print(
            "[ChatService] Received error message: ${decodedMessage['content']}");
        return;
      } else if (type == 'info') {
        print(
            "[ChatService] Received info message: ${decodedMessage['content']}");
        return;
      }
      // --- PHASE 3: Add 'message_ack' handling here later ---
      else {
        print(
            "[ChatService] Received unknown message structure or unhandled type '$type': $decodedMessage");
        return;
      }

      // Add the parsed message to the correct conversation provider
      _ref
          .read(conversationProvider(senderId!).notifier)
          .addReceivedMessage(chatMessage);
      print(
          "[ChatService] Added received message (type: $type) to conversation with $senderId");
      // --- END OF PART NEEDING UPDATE IN PHASE 2 ---
    } catch (e) {
      print("[ChatService] Error processing received message: $e");
    }
  }

  // --- Phase 1: Implemented ---
  void sendMessage(
    int recipientUserId, {
    String? text,
    String? mediaUrl,
    String? mediaType,
    int? replyToMessageId, // Optional: Add reply ID parameter
  }) {
    if (_channel == null ||
        _ref.read(webSocketStateProvider) !=
            WebSocketConnectionState.connected) {
      print("[ChatService] Cannot send message: Not connected.");
      // Optionally: Queue the message or attempt reconnect? For now, just return.
      return;
    }

    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      print("[ChatService] Cannot send message: Current User ID is null.");
      return;
    }

    // --- START PHASE 1 CHANGE ---
    // Always use "chat_message" type. Differentiate content using fields.
    Map<String, dynamic> payload = {
      'type': "chat_message", // <<< FIX: Always use "chat_message"
      'recipient_user_id': recipientUserId,
    };

    bool isMediaMessage = false; // Flag to track if it's media

    if (mediaUrl != null &&
        mediaUrl.isNotEmpty &&
        mediaType != null &&
        mediaType.isNotEmpty) {
      // Logic for Media Message
      payload['media_url'] = mediaUrl;
      payload['media_type'] = mediaType;
      payload['text'] = null; // Explicitly null for media
      isMediaMessage = true; // Mark as media
      print("[ChatService] Preparing media message payload.");
    } else if (text != null && text.trim().isNotEmpty) {
      // Logic for Text Message
      payload['text'] = text.trim();
      payload['media_url'] = null;
      payload['media_type'] = null;
      isMediaMessage = false; // Mark as text
      print("[ChatService] Preparing text message payload.");
    } else {
      print("[ChatService] Cannot send: Message must have text or media.");
      return; // Nothing to send
    }

    // Add reply ID if provided
    if (replyToMessageId != null && replyToMessageId > 0) {
      payload['reply_to_message_id'] = replyToMessageId;
      print("[ChatService] Adding replyToMessageId: $replyToMessageId");
    }

    // --- END PHASE 1 CHANGE ---

    final messageJson = jsonEncode(payload);
    // Log the corrected type being sent
    print("[ChatService] Sending message (Type: chat_message): $messageJson");

    try {
      _channel!.sink.add(messageJson);

      // --- Optimistic UI Update (Keep ONLY for TEXT for now) ---
      // Media optimistic UI update is handled in ChatDetailScreen initiateMediaSend
      // The 'sent' status for media will be handled later via message_ack (Phase 3)
      if (!isMediaMessage) {
        final sentMessage = ChatMessage(
          tempId: DateTime.now()
              .millisecondsSinceEpoch
              .toString(), // Use tempId for optimistic
          messageID: 0, // Real ID will come from ack (Phase 3)
          senderUserID: currentUserId,
          recipientUserID: recipientUserId,
          messageText: text!, // Use the original text
          sentAt: DateTime.now(), // Use local time for optimistic UI
          status: ChatMessageStatus.pending, // Start as pending
          isRead: false,
          readAt: null,
          mediaUrl: null,
          mediaType: null,
          // Add reply info here if needed for optimistic UI
        );
        _ref
            .read(conversationProvider(recipientUserId).notifier)
            .addSentMessage(sentMessage);
        print(
            "[ChatService] Added optimistic TEXT message (TempID: ${sentMessage.tempId}) to conversation with $recipientUserId");
      } else {
        // For media, the optimistic message (pending/uploading) is added in ChatDetailScreen
        print(
            "[ChatService] Media message sent to WebSocket sink. Optimistic message added by ChatDetailScreen.");
      }
    } catch (e) {
      print("[ChatService] Error sending message via WebSocket sink: $e");
      // Optionally: Update the optimistic message status to failed if possible
      // This might require passing the tempId back or handling the error differently.
      _handleError(e); // Handle error, maybe trigger reconnect
    }
  }
  // --- End Phase 1 Implementation ---

  // --- WebSocket Lifecycle Handlers (Keep as is) ---
  void _handleDisconnect() {
    print("[ChatService] WebSocket disconnected.");
    _channel = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _updateState(WebSocketConnectionState.disconnected);

    // Attempt to reconnect if it wasn't a manual disconnect
    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _handleError(dynamic error) {
    print("[ChatService] WebSocket error: $error");
    _channel = null; // Assume connection is lost on error
    _streamSubscription?.cancel(); // Cancel listener on error
    _streamSubscription = null;
    _updateState(WebSocketConnectionState.error);

    // Attempt to reconnect if it wasn't a manual disconnect
    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return; // Already scheduled
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print("[ChatService] Max reconnect attempts reached.");
      _updateState(WebSocketConnectionState.disconnected); // Stay disconnected
      return;
    }

    _reconnectAttempts++;
    // Use bit-shift for exponential backoff calculation
    final delayMilliseconds =
        _initialReconnectDelay.inMilliseconds * (1 << (_reconnectAttempts - 1));
    final delay = Duration(milliseconds: delayMilliseconds);

    print(
        "[ChatService] Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in $delay...");

    _reconnectTimer = Timer(delay, () {
      print("[ChatService] Attempting reconnect...");
      connect(); // Try connecting again
    });
  }

  void disconnect() {
    print("[ChatService] Manual disconnect initiated.");
    _isManualDisconnect = true; // Set flag to prevent auto-reconnect
    _reconnectTimer?.cancel(); // Cancel any pending reconnect
    _reconnectAttempts = 0; // Reset attempts on manual disconnect
    _streamSubscription?.cancel();
    _channel?.sink.close(WebSocketStatus.normalClosure);
    _channel = null;
    _streamSubscription = null;
    _updateState(WebSocketConnectionState.disconnected);
    print("[ChatService] Disconnected.");
  }

  void _updateState(WebSocketConnectionState newState) {
    // Update provider only if state changes
    if (_ref.read(webSocketStateProvider) != newState) {
      _ref.read(webSocketStateProvider.notifier).state = newState;
      print("[ChatService] WebSocket state updated to: $newState");
    }
  }
}

// Helper to get current user ID (remains the same)
final currentUserIdProvider = Provider<int?>((ref) {
  // Ensure userProvider is watched correctly if it can change
  return ref.watch(userProvider.select((user) => user.id));
});
// END OF FILE: lib/services/chat_service.dart
