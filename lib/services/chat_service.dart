// lib/services/chat_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io'; // For WebSocketException
// *** ADDED: math import (optional if using bit-shift) ***
// import 'dart:math';

// *** ADDED: web_socket_channel imports ***
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as WebSocketStatus;
import 'package:web_socket_channel/web_socket_channel.dart';
// *** END ADDED ***

import 'package:dtx/models/chat_message.dart';
import 'package:dtx/providers/auth_provider.dart'; // To get token
import 'package:dtx/providers/conversation_provider.dart'; // To add received messages
// *** ADDED: userProvider import ***
import 'package:dtx/providers/user_provider.dart';
// *** END ADDED ***
import 'package:dtx/utils/token_storage.dart'; // Fallback for token
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
    // Optional: Auto-connect if a token exists? Or connect on demand?
    // Let's connect on demand for now.
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
      // Include the token in the connection headers
      final headers = {'Authorization': 'Bearer $token'};
      _channel = IOWebSocketChannel.connect(
        Uri.parse(_wsUrl),
        headers: headers,
        // Optional: Add ping interval
        pingInterval: const Duration(seconds: 15),
      );

      print("[ChatService] WebSocket channel created. Listening...");

      _streamSubscription = _channel!.stream.listen(
        _onMessageReceived,
        onDone: _handleDisconnect,
        onError: _handleError,
        cancelOnError: false, // Keep listening after errors if possible
      );

      // If connection seems successful immediately (no error thrown by connect)
      _updateState(WebSocketConnectionState.connected);
      _reconnectAttempts =
          0; // Reset reconnect attempts on successful connection
      print("[ChatService] Connection established successfully.");
    } catch (e) {
      print("[ChatService] Connection failed: $e");
      _handleError(e); // Treat connection error as a disconnect/error
    }
  }

  void _onMessageReceived(dynamic message) {
    print("[ChatService] Message received: $message");
    try {
      final Map<String, dynamic> decodedMessage = jsonDecode(message);

      // --- Message Handling Logic ---
      final type = decodedMessage['type'] as String?;
      final content = decodedMessage['content'] as String?; // For info/error
      final senderId =
          decodedMessage['sender_user_id'] as int?; // For actual messages
      final currentUserId =
          _ref.read(currentUserIdProvider); // Get current user ID

      if (currentUserId == null) {
        print("[ChatService] Cannot process message: Current User ID is null.");
        return;
      }

      if (type == 'message' && senderId != null) {
        final chatMessage = ChatMessage.fromJson({
          // Adapt to ChatMessage structure
          // We don't get full ChatMessage JSON from WS, create it
          'MessageID': 0, // Not provided by WS, set to 0 or fetch later?
          'SenderUserID': senderId,
          'RecipientUserID': currentUserId, // The current user is recipient
          'MessageText': decodedMessage['text'] as String? ?? '',
          'SentAt':
              DateTime.now().toUtc().toIso8601String(), // Use current time
          'IsRead': false, // Assume unread initially
          'ReadAt': null,
        });
        // Add message to the correct conversation provider
        // Need the sender's ID to access the correct provider instance
        _ref
            .read(conversationProvider(senderId).notifier)
            .addReceivedMessage(chatMessage);
        print(
            "[ChatService] Added received message to conversation with $senderId");
      } else if (type == 'error') {
        print("[ChatService] Received error message: $content");
        // Optionally show error to user via a global snackbar provider?
      } else if (type == 'info') {
        print("[ChatService] Received info message: $content");
        // Optionally show info to user?
      } else {
        print(
            "[ChatService] Received unknown message structure: $decodedMessage");
      }
    } catch (e) {
      print("[ChatService] Error processing received message: $e");
    }
  }

  void sendMessage(int recipientUserId, String text) {
    if (_channel == null ||
        _ref.read(webSocketStateProvider) !=
            WebSocketConnectionState.connected) {
      print("[ChatService] Cannot send message: Not connected.");
      // Optionally try to reconnect here?
      // connect(); // Be careful with potential loops
      return;
    }

    // *** FIX: Use currentUserIdProvider ***
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      print("[ChatService] Cannot send message: Current User ID is null.");
      return; // Or handle appropriately
    }

    final messageJson = jsonEncode({
      'recipient_user_id': recipientUserId,
      'text': text,
    });

    print("[ChatService] Sending message: $messageJson");
    try {
      _channel!.sink.add(messageJson);

      // --- Optimistic UI Update ---
      // Create a temporary message object to display immediately
      final sentMessage = ChatMessage(
        messageID: 0, // Temporary ID
        senderUserID: currentUserId, // Current user is sender
        recipientUserID: recipientUserId,
        messageText: text,
        sentAt: DateTime.now(), // Use local time for immediate display
        isRead: false,
        readAt: null,
      );
      // Add it to the conversation provider
      _ref
          .read(conversationProvider(recipientUserId).notifier)
          .addSentMessage(sentMessage);
      print(
          "[ChatService] Added sent message optimistically to conversation with $recipientUserId");
      // --- End Optimistic Update ---
    } catch (e) {
      print("[ChatService] Error sending message: $e");
      // Handle potential sink errors (e.g., connection closed)
      _handleError(e);
    }
  }

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
    // Or use math.pow:
    // final delaySeconds = _initialReconnectDelay.inSeconds * pow(2, _reconnectAttempts - 1);
    // final delay = Duration(seconds: delaySeconds.toInt());

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

// Helper to get current user ID - needed often
final currentUserIdProvider = Provider<int?>((ref) {
  // Assuming you have user data in userProvider or authProvider
  // Adjust based on where your user ID is stored
  return ref.watch(userProvider.select((user) => user.id));
  // Or: return ref.watch(authProvider).userId; // Ensure authProvider state has userId if using this
});
