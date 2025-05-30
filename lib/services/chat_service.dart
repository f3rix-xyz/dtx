// File: lib/services/chat_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
// WebSocket Imports
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as WebSocketStatus;
import 'package:web_socket_channel/web_socket_channel.dart';

// App-specific Imports
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/ws_message_model.dart';
import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/providers/conversation_provider.dart';
import 'package:dtx/providers/reaction_provider.dart';
import 'package:dtx/providers/read_update_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/providers/status_provider.dart';
import 'package:dtx/utils/token_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- WebSocketConnectionState enum and webSocketStateProvider (Keep as is) ---
enum WebSocketConnectionState { disconnected, connecting, connected, error }

final webSocketStateProvider = StateProvider<WebSocketConnectionState>(
    (ref) => WebSocketConnectionState.disconnected);
// ---

// --- START: Helper Class for Pending Messages ---
/// Holds information about a message sent optimistically, waiting for ack.
class PendingMessageInfo {
  final int recipientId;
  final String? mediaUrl; // Store the final S3 URL if it's a media message

  PendingMessageInfo({required this.recipientId, this.mediaUrl});

  @override
  String toString() {
    return 'PendingMessageInfo(recipientId: $recipientId, hasMediaUrl: ${mediaUrl != null})';
  }
}
// --- END: Helper Class ---

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

  // --- MODIFIED: Use PendingMessageInfo ---
  // Tracks pending messages sent from this client, mapping tempId to its info.
  final Map<String, PendingMessageInfo> _pendingMessages = {};
  // --- END MODIFICATION ---

  ChatService(this._ref, this._wsUrl) {
    if (kDebugMode) print("[ChatService] Initialized with URL: $_wsUrl");
  }

  /// Establishes WebSocket connection.
  Future<void> connect() async {
    _isManualDisconnect =
        false; // Reset manual disconnect flag on connect attempt
    // Avoid concurrent connection attempts or connecting if already connected
    if (_channel != null &&
        _ref.read(webSocketStateProvider) ==
            WebSocketConnectionState.connected) {
      if (kDebugMode) print("[ChatService connect] Already connected.");
      return;
    }
    if (_ref.read(webSocketStateProvider) ==
        WebSocketConnectionState.connecting) {
      if (kDebugMode)
        print("[ChatService connect] Connection attempt already in progress.");
      return;
    }

    if (kDebugMode)
      print("[ChatService connect] Attempting to connect to $_wsUrl...");
    _updateState(
        WebSocketConnectionState.connecting); // Update state to connecting

    // Retrieve authentication token
    String? token =
        _ref.read(authProvider).jwtToken ?? await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode)
        print("[ChatService connect] Connection failed: Auth token not found.");
      _updateState(WebSocketConnectionState.error); // Update state to error
      return;
    }

    try {
      // Set Authorization header
      final headers = {'Authorization': 'Bearer $token'};

      // Establish WebSocket connection
      _channel = IOWebSocketChannel.connect(
        Uri.parse(_wsUrl),
        headers: headers,
        pingInterval: const Duration(seconds: 15), // Keep connection alive
      );
      if (kDebugMode)
        print("[ChatService connect] WebSocket channel created. Listening...");

      // Listen to incoming messages, completion, and errors
      _streamSubscription = _channel!.stream.listen(
        _onMessageReceived, // Handler for incoming messages
        onDone: _handleDisconnect, // Handler for connection closed
        onError: _handleError, // Handler for connection errors
        cancelOnError: false, // Keep listening even after an error if possible
      );

      // Update state to connected and reset reconnect attempts
      _updateState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
      if (kDebugMode)
        print("[ChatService connect] Connection established successfully.");
    } catch (e) {
      // Handle connection errors
      if (kDebugMode) print("[ChatService connect] Connection failed: $e");
      _handleError(e); // Trigger error handling and potential reconnect
    }
  }

  /// Handles incoming messages from the WebSocket server.
  void _onMessageReceived(dynamic message) {
    if (kDebugMode) print("[ChatService _onMessageReceived] Raw: $message");
    try {
      // Decode JSON message
      final Map<String, dynamic> decodedJson = jsonDecode(message);
      // Parse using the WsMessage model
      final WsMessage msg = WsMessage.fromJson(decodedJson);

      if (kDebugMode)
        print("[ChatService _onMessageReceived] Parsed type: ${msg.type}");

      // Process message based on its type
      switch (msg.type) {
        // --- Chat Message Handling ---
        case 'chat_message':
          // Validate essential fields
          if (msg.id == null ||
              msg.id! <= 0 ||
              msg.senderUserID == null ||
              msg.recipientUserID == null ||
              msg.sentAt == null) {
            if (kDebugMode)
              print(
                  "[ChatService _onMessageReceived] Received 'chat_message' with invalid/missing essential fields. Msg: $decodedJson");
            return;
          }
          final currentUserId = _ref.read(currentUserIdProvider);
          // Ignore messages not intended for the current user or self-messages
          if (currentUserId == null || msg.recipientUserID! != currentUserId) {
            if (kDebugMode)
              print(
                  "[ChatService _onMessageReceived] Received message not intended for current user ($currentUserId). Recipient was ${msg.recipientUserID}. Ignoring.");
            return;
          }
          if (msg.senderUserID == currentUserId) {
            if (kDebugMode)
              print(
                  "[ChatService _onMessageReceived] Received message loopback from self (ID: ${msg.id}). Ignoring.");
            return;
          }
          // Parse timestamp
          DateTime sentAt;
          try {
            sentAt = DateTime.parse(msg.sentAt!).toLocal();
          } catch (e) {
            if (kDebugMode)
              print(
                  "[ChatService _onMessageReceived] Error parsing sent_at '${msg.sentAt}': $e. Using local time as fallback.");
            sentAt = DateTime.now();
          }
          // Create ChatMessage object
          final ChatMessage chatMessage = ChatMessage(
            messageID: msg.id!,
            senderUserID: msg.senderUserID!,
            recipientUserID: msg.recipientUserID!,
            messageText: msg.text ?? '',
            mediaUrl: msg.mediaURL,
            mediaType: msg.mediaType,
            sentAt: sentAt,
            status: ChatMessageStatus.sent, // WS messages are considered sent
            isRead: false, // Initially marked as unread by this client
            readAt: null,
            replyToMessageID: msg.replyToMessageID,
          );
          // Add message to the relevant conversation provider
          _ref
              .read(conversationProvider(msg.senderUserID!).notifier)
              .addReceivedMessage(chatMessage);
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Added received 'chat_message' (ID: ${msg.id}) to conversation with ${msg.senderUserID}. ReplyTo: ${msg.replyToMessageID}");
          break;

        // --- Message Acknowledgement ---
        case 'message_ack':
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Received message_ack: $decodedJson");
          _handleMessageAck(decodedJson);
          break;

        // --- User Status Update ---
        case 'status_update':
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Received status_update: $decodedJson");
          if (msg.userID == null || msg.userID! <= 0 || msg.status == null) {
            if (kDebugMode)
              print(
                  "[ChatService _onMessageReceived] Invalid status_update message: Missing user_id or status. Data: $decodedJson");
            return;
          }
          final bool isOnline = msg.status!.toLowerCase() == 'online';
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Parsed status_update: UserID=${msg.userID}, isOnline=$isOnline");
          // Notify the status provider
          _ref
              .read(userStatusUpdateProvider.notifier)
              .updateStatus(msg.userID!, isOnline);
          break;

        // --- Reaction Update ---
        case 'reaction_update':
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Received reaction_update: $decodedJson");
          if (msg.messageID == null ||
              msg.reactorUserID == null ||
              msg.isRemoved == null ||
              (msg.emoji == null && !msg.isRemoved!)) {
            if (kDebugMode)
              print(
                  "[ChatService _onMessageReceived] Invalid reaction_update message: Missing required fields. Data: $decodedJson");
            return;
          }
          final reactionUpdate = ReactionUpdate(
            messageId: msg.messageID!,
            reactorUserId: msg.reactorUserID!,
            emoji: msg.emoji,
            isRemoved: msg.isRemoved!,
          );
          // Notify the reaction provider
          _ref.read(reactionUpdateProvider.notifier).state = reactionUpdate;
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Notified reactionUpdateProvider: $reactionUpdate");
          break;

        // --- Reaction Acknowledgement ---
        case 'reaction_ack':
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Received reaction_ack: $decodedJson");
          if (msg.messageID != null && msg.content != null) {
            if (kDebugMode)
              print(
                  "[ChatService _onMessageReceived] Reaction ack for message ${msg.messageID}: ${msg.content}");
          } else {
            if (kDebugMode)
              print(
                  "[ChatService _onMessageReceived] Received incomplete reaction_ack: $decodedJson");
          }
          break;

        // --- Messages Read Update (Phase 2 Implementation) ---
        case 'messages_read_update':
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Received messages_read_update: $decodedJson");
          // Validate necessary fields from the incoming message
          if (msg.readerUserID == null || msg.messageID == null) {
            if (kDebugMode)
              print(
                  "[ChatService _onMessageReceived] Invalid messages_read_update: Missing reader_user_id or message_id. Data: $decodedJson");
            return; // Stop processing if essential data is missing
          }
          // Create the ReadUpdate object
          final readUpdate = ReadUpdate(
            readerUserId: msg.readerUserID!,
            lastReadMessageId: msg.messageID!,
          );
          // Update the StateProvider with the new event
          _ref.read(readUpdateProvider.notifier).state = readUpdate;
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Notified readUpdateProvider: $readUpdate");
          break;
        // --- End messages_read_update ---

        // --- Mark Read Acknowledgement (Phase 1/4 Implementation - Corrected) ---
        case 'mark_read_ack':
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Received mark_read_ack: $decodedJson");
          // Use the otherUserID field from the parsed WsMessage
          if (msg.messageID != null && msg.otherUserID != null) {
            // *** Corrected field access ***
            if (kDebugMode)
              print(
                  "[ChatService _onMessageReceived] Mark read ack: Marked messages from user ${msg.otherUserID} up to ID ${msg.messageID} as seen. Count: ${msg.count ?? 'N/A'}. Server says: ${msg.content ?? ''}");
            // No UI state change needed here, just confirmation.
          } else {
            if (kDebugMode)
              print(
                  "[ChatService _onMessageReceived] Received incomplete mark_read_ack (missing messageID or otherUserID): $decodedJson");
          }
          break;
        // --- End mark_read_ack ---

        // --- Error from Server ---
        case 'error':
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Received error message from server: ${msg.content}");
          // TODO: Consider showing error to user via a provider/snackbar
          break;

        // --- Info from Server ---
        case 'info':
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Received info message from server: ${msg.content}");
          break;

        // --- Default for Unhandled Types ---
        default:
          if (kDebugMode)
            print(
                "[ChatService _onMessageReceived] Received unhandled message type '${msg.type}': $decodedJson");
      }
    } catch (e, stacktrace) {
      // Catch JSON decoding errors or other processing errors
      if (kDebugMode)
        print(
            "[ChatService _onMessageReceived] Error processing received message: $e");
      if (kDebugMode)
        print("[ChatService _onMessageReceived] Stacktrace: $stacktrace");
    }
  }

  /// Sends a chat message (text or media) via WebSocket.
  void sendMessage(
    int recipientUserId, {
    String? text,
    String? mediaUrl,
    String? mediaType,
    int? replyToMessageId,
  }) {
    if (_channel == null ||
        _ref.read(webSocketStateProvider) !=
            WebSocketConnectionState.connected) {
      if (kDebugMode)
        print("[ChatService sendMessage] Cannot send message: Not connected.");
      // TODO: Optionally queue the message or show an error
      return;
    }
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      if (kDebugMode)
        print(
            "[ChatService sendMessage] Cannot send message: Current User ID is null.");
      return;
    }

    // Construct payload
    Map<String, dynamic> payload = {
      'type': "chat_message", // Set message type for the backend
      'recipient_user_id': recipientUserId,
    };
    bool isMediaMessage = false;
    String? optimisticTempId;

    // Add text or media details
    if (mediaUrl != null &&
        mediaUrl.isNotEmpty &&
        mediaType != null &&
        mediaType.isNotEmpty) {
      payload['media_url'] = mediaUrl;
      payload['media_type'] = mediaType;
      payload['text'] = null; // Ensure text is null for media messages
      isMediaMessage = true;
      if (kDebugMode)
        print(
            "[ChatService sendMessage] Preparing media message payload with URL: $mediaUrl");
    } else if (text != null && text.trim().isNotEmpty) {
      payload['text'] = text.trim();
      payload['media_url'] = null; // Ensure media fields are null for text
      payload['media_type'] = null;
      isMediaMessage = false;
      if (kDebugMode)
        print("[ChatService sendMessage] Preparing text message payload.");
    } else {
      if (kDebugMode)
        print(
            "[ChatService sendMessage] Cannot send: Message must have text or media.");
      return; // Don't send empty messages
    }

    // Add reply info if provided
    if (replyToMessageId != null && replyToMessageId > 0) {
      payload['reply_to_message_id'] = replyToMessageId;
      if (kDebugMode)
        print(
            "[ChatService sendMessage] Adding replyToMessageId: $replyToMessageId to payload.");
    }

    final messageJson = jsonEncode(payload);
    if (kDebugMode)
      print(
          "[ChatService sendMessage] Sending message (Type: chat_message): $messageJson");

    try {
      // --- Optimistic UI Update for TEXT messages ---
      if (!isMediaMessage) {
        optimisticTempId = DateTime.now().millisecondsSinceEpoch.toString();
        final sentMessage = ChatMessage(
          tempId: optimisticTempId,
          messageID: 0, // Real ID will come from ack
          senderUserID: currentUserId,
          recipientUserID: recipientUserId,
          messageText: text!,
          sentAt: DateTime.now().toLocal(), // Use local time for immediate UI
          status: ChatMessageStatus.pending, // Initial status
          isRead: false, // Sent messages start as unread by recipient
          readAt: null,
          mediaUrl: null,
          mediaType: null,
          replyToMessageID: replyToMessageId, // Include reply info
        );
        // Track pending message and update conversation provider
        // Pass null for mediaUrl when tracking text messages
        addPendingMessage(optimisticTempId, recipientUserId, null);
        _ref
            .read(conversationProvider(recipientUserId).notifier)
            .addSentMessage(sentMessage);
        if (kDebugMode)
          print(
              "[ChatService sendMessage] Added optimistic TEXT message (TempID: $optimisticTempId) to conversation with $recipientUserId");
      }
      // Media messages are added optimistically by ChatDetailScreen before calling this.
      // The addPendingMessage call happens in ChatDetailScreen *after* upload, passing the mediaUrl.

      // Send the message through the WebSocket channel
      _channel!.sink.add(messageJson);
      if (kDebugMode)
        print("[ChatService sendMessage] Message added to WebSocket sink.");
    } catch (e) {
      // Handle errors during sending
      if (kDebugMode)
        print(
            "[ChatService sendMessage] Error adding message to WebSocket sink: $e");
      if (optimisticTempId != null) {
        // If it was an optimistic text message, mark it as failed
        if (kDebugMode)
          print(
              "[ChatService sendMessage] Marking optimistic message $optimisticTempId as failed due to sink error.");
        removePendingMessage(optimisticTempId);
        _ref
            .read(conversationProvider(recipientUserId).notifier)
            .updateMessageStatus(optimisticTempId, ChatMessageStatus.failed,
                errorMessage: "Failed to send message.");
      }
      // Trigger general error handling (e.g., reconnect)
      _handleError(e);
    }
  }

  /// Sends a reaction to a specific message.
  void sendReaction(int messageId, String emoji) {
    if (_channel == null ||
        _ref.read(webSocketStateProvider) !=
            WebSocketConnectionState.connected) {
      if (kDebugMode)
        print(
            "[ChatService sendReaction] Cannot send reaction: Not connected.");
      // TODO: Optionally queue or show error
      return;
    }
    // Validate input
    if (messageId <= 0) {
      if (kDebugMode)
        print(
            "[ChatService sendReaction] Cannot send reaction: Invalid messageId ($messageId).");
      return;
    }
    if (emoji.isEmpty) {
      if (kDebugMode)
        print(
            "[ChatService sendReaction] Cannot send reaction: Emoji is empty.");
      return;
    }

    // Construct payload
    final payload = {
      'type': 'react_to_message',
      'message_id': messageId,
      'emoji': emoji,
    };
    final messageJson = jsonEncode(payload);
    if (kDebugMode)
      print(
          "[ChatService sendReaction] Sending reaction (Type: react_to_message): $messageJson");

    try {
      // Send via WebSocket
      _channel!.sink.add(messageJson);
      if (kDebugMode)
        print(
            "[ChatService sendReaction] Reaction message added to WebSocket sink.");
    } catch (e) {
      // Handle send errors
      if (kDebugMode)
        print(
            "[ChatService sendReaction] Error adding reaction message to WebSocket sink: $e");
      _handleError(e); // Trigger general error handling
      // TODO: Optionally show specific feedback to user
    }
  }

  /// Sends a 'mark_read' message to the server (Phase 1).
  void sendMarkRead(int otherUserId, int lastMessageId) {
    if (_channel == null ||
        _ref.read(webSocketStateProvider) !=
            WebSocketConnectionState.connected) {
      if (kDebugMode)
        print("[ChatService sendMarkRead] Cannot send: Not connected.");
      return;
    }
    if (otherUserId <= 0 || lastMessageId <= 0) {
      if (kDebugMode)
        print(
            "[ChatService sendMarkRead] Invalid parameters: otherUserId=$otherUserId, lastMessageId=$lastMessageId");
      return;
    }

    // Construct payload
    final payload = {
      'type': 'mark_read',
      'other_user_id': otherUserId,
      'message_id': lastMessageId,
    };
    final messageJson = jsonEncode(payload);
    if (kDebugMode)
      print(
          "[ChatService sendMarkRead] Sending (Type: mark_read): $messageJson");

    try {
      // Send via WebSocket
      _channel!.sink.add(messageJson);
      if (kDebugMode)
        print(
            "[ChatService sendMarkRead] Mark read message added to WebSocket sink.");
    } catch (e) {
      // Handle send errors
      if (kDebugMode)
        print(
            "[ChatService sendMarkRead] Error adding mark_read message to WebSocket sink: $e");
      _handleError(e); // Trigger general error handling
    }
  }

  /// Handles message acknowledgement from the server. (Modified)
  void _handleMessageAck(Map<String, dynamic> ackData) {
    final realMessageId = ackData['id'] as int?;
    final ackContent = ackData['content'] as String?;
    // Note: media_url is NOT expected in the ack from backend for chat messages

    if (kDebugMode)
      print(
          "[ChatService _handleMessageAck] Received: RealID=$realMessageId, Content='$ackContent'");

    if (realMessageId == null || realMessageId <= 0) {
      if (kDebugMode)
        print(
            "[ChatService _handleMessageAck] Invalid ack: Missing or invalid real ID ($realMessageId).");
      return;
    }
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      if (kDebugMode)
        print(
            "[ChatService _handleMessageAck] Cannot process ack: Current User ID is null.");
      return;
    }

    // --- MODIFIED: Find pending message and its stored URL ---
    String? foundTempId;
    PendingMessageInfo? foundInfo;
    // Iterate to find the FIRST matching tempId (simple FIFO assumption)
    for (var entry in _pendingMessages.entries) {
      foundTempId = entry.key;
      foundInfo = entry.value;
      _pendingMessages.remove(foundTempId); // Remove the matched entry
      if (kDebugMode)
        print(
            "[ChatService _handleMessageAck] Found & removed pending message: TempID=$foundTempId, Info: $foundInfo");
      break; // Stop after finding the first (oldest)
    }
    // --- END MODIFICATION ---

    if (foundTempId != null && foundInfo != null) {
      if (kDebugMode)
        print(
            "[ChatService _handleMessageAck] Updating message (TempID: $foundTempId) for ack (Real ID: $realMessageId). Status -> Sent. Passing MediaURL: ${foundInfo.mediaUrl}");
      final conversationNotifier =
          _ref.read(conversationProvider(foundInfo.recipientId).notifier);

      // *** PASS the stored mediaUrl (foundInfo.mediaUrl) ***
      conversationNotifier.updateMessageStatus(
        foundTempId,
        ChatMessageStatus.sent,
        finalMessageId: realMessageId,
        finalMediaUrl: foundInfo.mediaUrl, // Use the URL stored with the tempId
      );
      if (kDebugMode)
        print(
            "[ChatService _handleMessageAck] Message status updated successfully.");
    } else {
      if (kDebugMode)
        print(
            "[ChatService _handleMessageAck] WARNING: Received message_ack for Real ID $realMessageId, but couldn't find/remove a matching tracked pending message. This might be okay if it was a pure text message ack or if tracking failed.");
    }
  }

  // --- MODIFIED: Helper methods for tracking pending messages ---
  /// Stores info about a message sent optimistically.
  /// [mediaUrl] should be the final S3 URL if it's a media message.
  void addPendingMessage(String tempId, int recipientId, String? mediaUrl) {
    _pendingMessages[tempId] = PendingMessageInfo(
        recipientId: recipientId,
        mediaUrl: mediaUrl // Store the URL along with recipient
        );
    if (kDebugMode)
      print(
          "[ChatService addPendingMessage] Added TempID: $tempId | Recipient: $recipientId | MediaURL: ${mediaUrl != null} | Pending Count: ${_pendingMessages.length}");
  }

  /// Removes a message from tracking (e.g., after ack or failure).
  void removePendingMessage(String tempId) {
    if (_pendingMessages.containsKey(tempId)) {
      _pendingMessages.remove(tempId);
      if (kDebugMode)
        print(
            "[ChatService removePendingMessage] Removed TempID: $tempId. Pending Count: ${_pendingMessages.length}");
    } else {
      if (kDebugMode)
        print(
            "[ChatService removePendingMessage] Attempted to remove TempID $tempId, but it was not found in the map.");
    }
  }
  // --- END MODIFICATION ---

  // --- WebSocket Lifecycle Handlers ---
  void _handleDisconnect() {
    if (kDebugMode)
      print("[ChatService _handleDisconnect] WebSocket disconnected.");
    _channel = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _pendingMessages.clear(); // Clear pending messages on disconnect
    if (kDebugMode)
      print("[ChatService _handleDisconnect] Cleared pending messages map.");
    _updateState(WebSocketConnectionState.disconnected);
    if (!_isManualDisconnect) {
      _scheduleReconnect(); // Attempt to reconnect if not manual
    }
  }

  void _handleError(dynamic error) {
    if (kDebugMode) print("[ChatService _handleError] WebSocket error: $error");
    _channel = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _pendingMessages.clear(); // Clear pending messages on error
    if (kDebugMode)
      print("[ChatService _handleError] Cleared pending messages map.");
    _updateState(WebSocketConnectionState.error);
    if (!_isManualDisconnect) {
      _scheduleReconnect(); // Attempt to reconnect if not manual
    }
  }

  /// Schedules reconnection attempts with exponential backoff.
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false)
      return; // Don't schedule if already scheduled
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode)
        print(
            "[ChatService _scheduleReconnect] Max reconnect attempts reached.");
      _updateState(WebSocketConnectionState.disconnected); // Stay disconnected
      return;
    }
    _reconnectAttempts++;
    // Exponential backoff calculation
    final delayMilliseconds =
        _initialReconnectDelay.inMilliseconds * (1 << (_reconnectAttempts - 1));
    final delay = Duration(milliseconds: delayMilliseconds);
    if (kDebugMode)
      print(
          "[ChatService _scheduleReconnect] Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in $delay...");
    _reconnectTimer = Timer(delay, () {
      if (kDebugMode)
        print(
            "[ChatService _scheduleReconnect] Timer fired. Attempting reconnect...");
      connect(); // Attempt to connect again
    });
  }

  /// Manually disconnects the WebSocket.
  void disconnect() {
    if (kDebugMode)
      print("[ChatService disconnect] Manual disconnect initiated.");
    _isManualDisconnect = true;
    _reconnectTimer?.cancel(); // Cancel any pending reconnect timers
    _reconnectAttempts = 0; // Reset attempts on manual disconnect
    _streamSubscription?.cancel(); // Cancel the stream listener
    _pendingMessages.clear(); // Clear pending messages
    if (kDebugMode)
      print("[ChatService disconnect] Cleared pending messages map.");
    _channel?.sink
        .close(WebSocketStatus.normalClosure); // Close the channel sink
    _channel = null; // Nullify the channel
    _streamSubscription = null; // Nullify the subscription
    _updateState(WebSocketConnectionState.disconnected); // Update state
    if (kDebugMode) print("[ChatService disconnect] Disconnected.");
  }

  /// Updates the global WebSocket connection state provider.
  void _updateState(WebSocketConnectionState newState) {
    // Use microtask to ensure updates happen after the current event loop
    Future.microtask(() {
      try {
        // Check if the state actually needs changing
        if (_ref.read(webSocketStateProvider) != newState) {
          _ref.read(webSocketStateProvider.notifier).state = newState;
          if (kDebugMode)
            print(
                "[ChatService _updateState] WebSocket state updated to: $newState");
        }
      } catch (e) {
        // Catch errors if the provider is accessed after disposal
        if (kDebugMode)
          print(
              "[ChatService _updateState] Error accessing provider (likely disposed): $e");
      }
    });
  }
} // End ChatService

// --- currentUserIdProvider ---
final currentUserIdProvider = Provider<int?>((ref) {
  final user = ref.watch(userProvider);
  return user.id;
});
// ---
