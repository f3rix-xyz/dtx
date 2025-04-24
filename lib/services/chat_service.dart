// lib/services/chat_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
    // ... (connect logic remains the same) ...
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

      // --- MODIFIED: Handle different message types ---
      ChatMessage chatMessage;
      if (type == 'text' && senderId != null) {
        chatMessage = ChatMessage(
          messageID: 0, // Not provided by WS
          senderUserID: senderId,
          recipientUserID: currentUserId,
          messageText: decodedMessage['text'] as String? ?? '',
          sentAt: DateTime.now().toUtc(), // Use UTC time from WS
          isRead: false,
          readAt: null,
          // Media fields will be null for text
          mediaUrl: null,
          mediaType: null,
        );
      } else if (['image', 'video', 'audio', 'file'].contains(type) &&
          senderId != null) {
        chatMessage = ChatMessage(
          messageID: 0, // Not provided by WS
          senderUserID: senderId,
          recipientUserID: currentUserId,
          messageText: '', // Text is empty for media
          sentAt: DateTime.now().toUtc(),
          isRead: false,
          readAt: null,
          // Populate media fields
          mediaUrl: decodedMessage['media_url'] as String?,
          mediaType: decodedMessage['media_type'] as String?,
        );
      } else if (type == 'error') {
        print(
            "[ChatService] Received error message: ${decodedMessage['content']}");
        // Optionally show error to user
        return; // Don't add error messages to conversation
      } else if (type == 'info') {
        print(
            "[ChatService] Received info message: ${decodedMessage['content']}");
        // Optionally show info to user
        return; // Don't add info messages to conversation
      } else {
        print(
            "[ChatService] Received unknown message structure: $decodedMessage");
        return; // Ignore unknown types
      }

      // Add the parsed message to the correct conversation provider
      _ref
          .read(conversationProvider(senderId!)
              .notifier) // Use senderId! as it's checked above
          .addReceivedMessage(chatMessage);
      print(
          "[ChatService] Added received message (type: $type) to conversation with $senderId");
      // --- END MODIFICATION ---
    } catch (e) {
      print("[ChatService] Error processing received message: $e");
    }
  }

  // --- MODIFIED: sendMessage signature and payload ---
  void sendMessage(
    int recipientUserId, {
    String? text,
    String? mediaUrl,
    String? mediaType,
  }) {
    if (_channel == null ||
        _ref.read(webSocketStateProvider) !=
            WebSocketConnectionState.connected) {
      print("[ChatService] Cannot send message: Not connected.");
      return;
    }

    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      print("[ChatService] Cannot send message: Current User ID is null.");
      return;
    }

    // Determine message type and build payload
    Map<String, dynamic> payload = {
      'recipient_user_id': recipientUserId,
    };
    String messageType = "text"; // Default

    if (mediaUrl != null && mediaType != null) {
      // Basic check for media type validity
      if (mediaType.startsWith('image/')) {
        messageType = "image";
      } else if (mediaType.startsWith('video/')) {
        messageType = "video";
      } else if (mediaType.startsWith('audio/')) {
        messageType = "audio";
      } else {
        messageType = "file"; // Generic file type
      }
      payload['type'] = messageType;
      payload['media_url'] = mediaUrl;
      payload['media_type'] = mediaType;
      payload['text'] = null; // Explicitly null for media
    } else if (text != null && text.trim().isNotEmpty) {
      messageType = "text";
      payload['type'] = messageType;
      payload['text'] = text.trim();
      payload['media_url'] = null;
      payload['media_type'] = null;
    } else {
      print("[ChatService] Cannot send: Message must have text or media.");
      return; // Nothing to send
    }

    final messageJson = jsonEncode(payload);
    print("[ChatService] Sending message (Type: $messageType): $messageJson");

    try {
      _channel!.sink.add(messageJson);

      // Optimistic UI Update (only for text messages for now)
      if (messageType == "text") {
        final sentMessage = ChatMessage(
          messageID: 0, // Temporary ID
          senderUserID: currentUserId,
          recipientUserID: recipientUserId,
          messageText: text!, // Use the original text
          sentAt: DateTime.now(),
          isRead: false,
          readAt: null,
          mediaUrl: null,
          mediaType: null,
        );
        _ref
            .read(conversationProvider(recipientUserId).notifier)
            .addSentMessage(sentMessage);
        print(
            "[ChatService] Added sent TEXT message optimistically to conversation with $recipientUserId");
      } else {
        // Optional: Add optimistic UI for media upload/sent status later
        print(
            "[ChatService] Media message sent to WebSocket. Optimistic UI not implemented yet.");
      }
    } catch (e) {
      print("[ChatService] Error sending message: $e");
      _handleError(e);
    }
  }
  // --- END MODIFICATION ---

  // ... (_handleDisconnect, _handleError, _scheduleReconnect, disconnect, _updateState remain the same) ...
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
    // *** FIX: Use bit-shift for power calculation ***
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
  return ref.watch(userProvider.select((user) => user.id));
});
