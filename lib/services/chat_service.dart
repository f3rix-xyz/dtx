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
import 'package:dtx/models/ws_message_model.dart'; // <<<--- ADDED Import for WsMessage model
import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/providers/conversation_provider.dart';
import 'package:dtx/providers/reaction_provider.dart'; // <<<--- ADDED Import for reaction provider
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

  final Map<String, int> _pendingMessages = {};

  ChatService(this._ref, this._wsUrl) {
    print("[ChatService] Initialized with URL: $_wsUrl");
  }

  // --- connect (Keep as is) ---
  Future<void> connect() async {
    _isManualDisconnect = false;
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
      _updateState(WebSocketConnectionState.error);
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

  // --- *** MODIFIED: _onMessageReceived *** ---
  void _onMessageReceived(dynamic message) {
    if (kDebugMode) print("[ChatService] Message received: $message");
    try {
      final Map<String, dynamic> decodedJson = jsonDecode(message);
      // Use the WsMessage model to parse *incoming* messages
      final WsMessage msg = WsMessage.fromJson(decodedJson);

      if (kDebugMode) print("[ChatService] Parsed message type: ${msg.type}");

      switch (msg.type) {
        case 'chat_message':
          // --- Existing chat message handling (No changes here) ---
          if (msg.id == null ||
              msg.id! <= 0 ||
              msg.senderUserID == null ||
              msg.recipientUserID == null ||
              msg.sentAt == null) {
            print(
                "[ChatService] Received 'chat_message' with invalid/missing essential fields. Msg: $decodedJson");
            return;
          }
          final currentUserId = _ref.read(currentUserIdProvider);
          if (currentUserId == null || msg.recipientUserID! != currentUserId) {
            if (kDebugMode)
              print(
                  "[ChatService] Received message not intended for current user ($currentUserId). Recipient was ${msg.recipientUserID}. Ignoring.");
            return;
          }
          if (msg.senderUserID == currentUserId) {
            if (kDebugMode)
              print(
                  "[ChatService] Received message loopback from self (ID: ${msg.id}). Ignoring.");
            return;
          }
          DateTime sentAt;
          try {
            sentAt = DateTime.parse(msg.sentAt!).toLocal();
          } catch (e) {
            print(
                "[ChatService] Error parsing sent_at '${msg.sentAt}': $e. Using local time as fallback.");
            sentAt = DateTime.now();
          }
          final ChatMessage chatMessage = ChatMessage(
            messageID: msg.id!,
            senderUserID: msg.senderUserID!,
            recipientUserID: msg.recipientUserID!,
            messageText: msg.text ?? '',
            mediaUrl: msg.mediaURL,
            mediaType: msg.mediaType,
            sentAt: sentAt,
            status: ChatMessageStatus.sent,
            isRead: false,
            readAt: null,
            replyToMessageID: msg.replyToMessageID,
            // Note: The reply preview fields (repliedMessageSenderID etc.)
            // are populated by the API call, not the basic WebSocket message.
            // If the backend *did* send them via WS, you'd parse msg.replied... here.
          );
          _ref
              .read(conversationProvider(msg.senderUserID!).notifier)
              .addReceivedMessage(chatMessage);
          if (kDebugMode)
            print(
                "[ChatService] Added received 'chat_message' (ID: ${msg.id}) to conversation with ${msg.senderUserID}. ReplyTo: ${msg.replyToMessageID}");
          break;
        // --- End existing chat message handling ---

        case 'message_ack':
          if (kDebugMode)
            print("[ChatService] Received message_ack: $decodedJson");
          _handleMessageAck(decodedJson);
          break;

        case 'status_update':
          if (kDebugMode)
            print("[ChatService] Received status_update: $decodedJson");
          // --- Existing status update handling (No changes here) ---
          if (msg.userID == null || msg.userID! <= 0 || msg.status == null) {
            print(
                "[ChatService] Invalid status_update message: Missing user_id or status. Data: $decodedJson");
            return;
          }
          final bool isOnline = msg.status!.toLowerCase() == 'online';
          if (kDebugMode)
            print(
                "[ChatService] Parsed status_update: UserID=${msg.userID}, isOnline=$isOnline");
          _ref
              .read(userStatusUpdateProvider.notifier)
              .updateStatus(msg.userID!, isOnline);
          break;
        // --- End existing status update handling ---

        // *** --- START: Reaction Handling ADDED --- ***
        case 'reaction_update':
          if (kDebugMode)
            print("[ChatService] Received reaction_update: $decodedJson");
          // Validate necessary fields
          if (msg.messageID == null ||
              msg.reactorUserID == null ||
              msg.isRemoved == null ||
              (msg.emoji == null && !msg.isRemoved!)) {
            print(
                "[ChatService] Invalid reaction_update message: Missing required fields. Data: $decodedJson");
            return;
          }
          // Create the update object
          final reactionUpdate = ReactionUpdate(
            messageId: msg.messageID!,
            reactorUserId: msg.reactorUserID!,
            emoji: msg.emoji, // Can be null if removed
            isRemoved: msg.isRemoved!,
          );
          // Notify the reaction provider
          _ref.read(reactionUpdateProvider.notifier).state = reactionUpdate;
          if (kDebugMode)
            print(
                "[ChatService] Notified reactionUpdateProvider: $reactionUpdate");
          break;

        case 'reaction_ack':
          // This confirms *your* reaction was processed by the server
          if (kDebugMode)
            print("[ChatService] Received reaction_ack: $decodedJson");
          if (msg.messageID != null && msg.content != null) {
            print(
                "[ChatService] Reaction ack for message ${msg.messageID}: ${msg.content}");
            // Optionally show a temporary confirmation (e.g., snackbar),
            // but the reaction_update provides the actual state change.
          } else {
            print(
                "[ChatService] Received incomplete reaction_ack: $decodedJson");
          }
          break;
        // *** --- END: Reaction Handling ADDED --- ***

        case 'error':
          print(
              "[ChatService] Received error message from server: ${msg.content}");
          break;

        case 'info':
          print(
              "[ChatService] Received info message from server: ${msg.content}");
          break;

        default:
          print(
              "[ChatService] Received unhandled message type '${msg.type}': $decodedJson");
      }
    } catch (e, stacktrace) {
      print("[ChatService] Error processing received message: $e");
      print("[ChatService] Stacktrace: $stacktrace");
      // Optionally disconnect or try to handle specific parsing errors
    }
  }
  // --- *** END MODIFIED *** ---

  // --- sendMessage (Keep as previously modified) ---
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
      print("[ChatService] Cannot send message: Not connected.");
      return;
    }
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      print("[ChatService] Cannot send message: Current User ID is null.");
      return;
    }
    Map<String, dynamic> payload = {
      'type': "chat_message",
      'recipient_user_id': recipientUserId,
    };
    bool isMediaMessage = false;
    String? optimisticTempId;
    if (mediaUrl != null &&
        mediaUrl.isNotEmpty &&
        mediaType != null &&
        mediaType.isNotEmpty) {
      payload['media_url'] = mediaUrl;
      payload['media_type'] = mediaType;
      payload['text'] = null;
      isMediaMessage = true;
      if (kDebugMode) print("[ChatService] Preparing media message payload.");
    } else if (text != null && text.trim().isNotEmpty) {
      payload['text'] = text.trim();
      payload['media_url'] = null;
      payload['media_type'] = null;
      isMediaMessage = false;
      if (kDebugMode) print("[ChatService] Preparing text message payload.");
    } else {
      print("[ChatService] Cannot send: Message must have text or media.");
      return;
    }
    if (replyToMessageId != null && replyToMessageId > 0) {
      payload['reply_to_message_id'] = replyToMessageId;
      if (kDebugMode)
        print(
            "[ChatService] Adding replyToMessageId: $replyToMessageId to payload.");
    }
    final messageJson = jsonEncode(payload);
    if (kDebugMode)
      print("[ChatService] Sending message (Type: chat_message): $messageJson");
    try {
      if (!isMediaMessage) {
        optimisticTempId = DateTime.now().millisecondsSinceEpoch.toString();
        final sentMessage = ChatMessage(
          tempId: optimisticTempId,
          messageID: 0,
          senderUserID: currentUserId,
          recipientUserID: recipientUserId,
          messageText: text!,
          sentAt: DateTime.now().toLocal(),
          status: ChatMessageStatus.pending,
          isRead: false,
          readAt: null,
          mediaUrl: null,
          mediaType: null,
        );
        addPendingMessage(optimisticTempId, recipientUserId);
        _ref
            .read(conversationProvider(recipientUserId).notifier)
            .addSentMessage(sentMessage);
        if (kDebugMode)
          print(
              "[ChatService] Added optimistic TEXT message (TempID: $optimisticTempId) to conversation with $recipientUserId");
      } else {
        if (kDebugMode)
          print(
              "[ChatService] Media message payload prepared. Optimistic message added by ChatDetailScreen.");
      }
      _channel!.sink.add(messageJson);
      if (kDebugMode) print("[ChatService] Message added to WebSocket sink.");
    } catch (e) {
      print("[ChatService] Error adding message to WebSocket sink: $e");
      if (optimisticTempId != null) {
        print(
            "[ChatService] Marking optimistic message $optimisticTempId as failed due to sink error.");
        removePendingMessage(optimisticTempId);
        _ref
            .read(conversationProvider(recipientUserId).notifier)
            .updateMessageStatus(optimisticTempId, ChatMessageStatus.failed,
                errorMessage: "Failed to send message.");
      }
      _handleError(e);
    }
  }

  // --- *** START: sendReaction Method ADDED *** ---
  void sendReaction(int messageId, String emoji) {
    if (_channel == null ||
        _ref.read(webSocketStateProvider) !=
            WebSocketConnectionState.connected) {
      print("[ChatService] Cannot send reaction: Not connected.");
      // Optionally: Show a snackbar to the user
      return;
    }
    if (messageId <= 0) {
      print(
          "[ChatService] Cannot send reaction: Invalid messageId ($messageId).");
      return;
    }
    if (emoji.isEmpty) {
      print("[ChatService] Cannot send reaction: Emoji is empty.");
      return;
    }

    final payload = {
      'type': 'react_to_message',
      'message_id': messageId,
      'emoji': emoji,
    };
    final messageJson = jsonEncode(payload);
    print(
        "[ChatService] Sending reaction (Type: react_to_message): $messageJson");

    try {
      _channel!.sink.add(messageJson);
      print("[ChatService] Reaction message added to WebSocket sink.");
    } catch (e) {
      print(
          "[ChatService] Error adding reaction message to WebSocket sink: $e");
      _handleError(e); // Trigger reconnect or error state
      // Optionally: Show a snackbar to the user that reaction failed
    }
  }
  // --- *** END: sendReaction Method ADDED *** ---

  // --- _handleMessageAck (Keep as is) ---
  void _handleMessageAck(Map<String, dynamic> ackData) {
    final realMessageId = ackData['id'] as int?;
    final ackContent = ackData['content'] as String?;
    final mediaUrlAck = ackData['media_url'] as String?;
    if (kDebugMode)
      print(
          "[ChatService _handleMessageAck] Received: RealID=$realMessageId, Content='$ackContent', MediaURL='$mediaUrlAck'");
    if (realMessageId == null) {
      print("[ChatService _handleMessageAck] Invalid ack: Missing real ID.");
      return;
    }
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      print(
          "[ChatService _handleMessageAck] Cannot process ack: Current User ID is null.");
      return;
    }
    String? foundTempId;
    int? foundRecipientId;
    // Find the *first* matching tempId (assuming FIFO for acks)
    // This is a simplification; a more robust system might use message UUIDs
    if (_pendingMessages.isNotEmpty) {
      // Find *a* pending message for the recipient associated with the ack.
      // Since we don't get recipient ID in ack, we find the *oldest* pending msg.
      // THIS IS A LIMITATION. A better ACK would include tempId or recipientId.
      foundTempId = _pendingMessages.keys.first;
      foundRecipientId =
          _pendingMessages.remove(foundTempId); // Remove it once processed
      if (kDebugMode)
        print(
            "[ChatService _handleMessageAck] Found oldest pending message via map: TempID=$foundTempId for Recipient=$foundRecipientId");
    } else {
      print(
          "[ChatService _handleMessageAck] No pending messages found in tracking map.");
    }

    if (foundTempId != null && foundRecipientId != null) {
      if (kDebugMode)
        print(
            "[ChatService _handleMessageAck] Updating message (TempID: $foundTempId) for ack (Real ID: $realMessageId). Status -> Sent.");
      final conversationNotifier =
          _ref.read(conversationProvider(foundRecipientId).notifier);
      conversationNotifier.updateMessageStatus(
          foundTempId, ChatMessageStatus.sent,
          finalMessageId: realMessageId,
          finalMediaUrl: mediaUrlAck // Pass media URL from ack if present
          );
      if (kDebugMode)
        print(
            "[ChatService _handleMessageAck] Message status updated successfully.");
    } else {
      print(
          "[ChatService _handleMessageAck] WARNING: Received message_ack for Real ID $realMessageId, but couldn't find/remove a matching tracked pending message.");
    }
  }

  // --- Public Helper methods for tracking pending messages (Keep as is) ---
  void addPendingMessage(String tempId, int recipientId) {
    _pendingMessages[tempId] = recipientId;
    print(
        "[ChatService addPendingMessage] Added TempID: $tempId for Recipient: $recipientId. Count: ${_pendingMessages.length}");
  }

  void removePendingMessage(String tempId) {
    if (_pendingMessages.containsKey(tempId)) {
      _pendingMessages.remove(tempId);
      print(
          "[ChatService removePendingMessage] Removed TempID: $tempId. Count: ${_pendingMessages.length}");
    }
  }
  // --- End Public Helpers ---

  // --- WebSocket Lifecycle Handlers (Keep as is) ---
  void _handleDisconnect() {
    print("[ChatService] WebSocket disconnected.");
    _channel = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _pendingMessages.clear();
    print("[ChatService _handleDisconnect] Cleared pending messages map.");
    _updateState(WebSocketConnectionState.disconnected);
    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _handleError(dynamic error) {
    print("[ChatService] WebSocket error: $error");
    _channel = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _pendingMessages.clear();
    print("[ChatService _handleError] Cleared pending messages map.");
    _updateState(WebSocketConnectionState.error);
    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print("[ChatService] Max reconnect attempts reached.");
      _updateState(WebSocketConnectionState.disconnected);
      return;
    }
    _reconnectAttempts++;
    final delayMilliseconds =
        _initialReconnectDelay.inMilliseconds * (1 << (_reconnectAttempts - 1));
    final delay = Duration(milliseconds: delayMilliseconds);
    print(
        "[ChatService] Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in $delay...");
    _reconnectTimer = Timer(delay, () {
      print("[ChatService] Attempting reconnect...");
      connect();
    });
  }

  void disconnect() {
    print("[ChatService] Manual disconnect initiated.");
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _streamSubscription?.cancel();
    _pendingMessages.clear();
    print("[ChatService disconnect] Cleared pending messages map.");
    _channel?.sink.close(WebSocketStatus.normalClosure);
    _channel = null;
    _streamSubscription = null;
    _updateState(WebSocketConnectionState.disconnected);
    print("[ChatService] Disconnected.");
  }

  void _updateState(WebSocketConnectionState newState) {
    Future.microtask(() {
      // Check if provider is still alive before updating
      try {
        if (_ref.read(webSocketStateProvider) != newState) {
          _ref.read(webSocketStateProvider.notifier).state = newState;
          print("[ChatService] WebSocket state updated to: $newState");
        }
      } catch (e) {
        print(
            "[ChatService _updateState] Error accessing provider (likely disposed): $e");
      }
    });
  }
  // --- End Lifecycle Handlers ---
}

// --- currentUserIdProvider (Keep as is) ---
final currentUserIdProvider = Provider<int?>((ref) {
  // Ensure userProvider is watched correctly
  final user = ref.watch(userProvider);
  return user.id;
});
// ---
