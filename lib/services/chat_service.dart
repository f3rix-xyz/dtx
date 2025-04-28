// START OF FILE: lib/services/chat_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Keep for potential future use
// WebSocket Imports
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as WebSocketStatus;
import 'package:web_socket_channel/web_socket_channel.dart';

// App-specific Imports
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

  // Map to track optimistic messages (No Lock Needed)
  final Map<String, int> _pendingMessages = {};

  ChatService(this._ref, this._wsUrl) {
    print("[ChatService] Initialized with URL: $_wsUrl");
  }

  Future<void> connect() async {
    // --- connect logic remains the same ---
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

  void _onMessageReceived(dynamic message) {
    // --- _onMessageReceived logic remains the same ---
    print("[ChatService] Message received: $message");
    try {
      final Map<String, dynamic> decodedMessage = jsonDecode(message);
      final type = decodedMessage['type'] as String?;
      if (type == 'chat_message') {
        final messageId = decodedMessage['id'] as int?;
        final senderId = decodedMessage['sender_user_id'] as int?;
        final recipientId = decodedMessage['recipient_user_id'] as int?;
        final sentAtString = decodedMessage['sent_at'] as String?;
        final textContent = decodedMessage['text'] as String?;
        final mediaUrlContent = decodedMessage['media_url'] as String?;
        final mediaTypeContent = decodedMessage['media_type'] as String?;
        if (messageId == null ||
            messageId <= 0 ||
            senderId == null ||
            recipientId == null ||
            sentAtString == null) {
          print(
              "[ChatService] Received 'chat_message' with invalid/missing essential fields. Msg: $decodedMessage");
          return;
        }
        final currentUserId = _ref.read(currentUserIdProvider);
        if (currentUserId == null || recipientId != currentUserId) {
          print(
              "[ChatService] Received message not intended for current user ($currentUserId). Recipient was $recipientId. Ignoring.");
          return;
        }
        if (senderId == currentUserId) {
          print(
              "[ChatService] Received message loopback from self (ID: $messageId). Ignoring.");
          return;
        }
        DateTime sentAt;
        try {
          sentAt = DateTime.parse(sentAtString).toLocal();
        } catch (e) {
          print(
              "[ChatService] Error parsing sent_at '$sentAtString': $e. Using local time as fallback.");
          sentAt = DateTime.now();
        }
        final ChatMessage chatMessage = ChatMessage(
          messageID: messageId,
          senderUserID: senderId,
          recipientUserID: recipientId,
          messageText: textContent ?? '',
          mediaUrl: mediaUrlContent,
          mediaType: mediaTypeContent,
          sentAt: sentAt,
          status: ChatMessageStatus.sent,
          isRead: false,
          readAt: null,
        );
        _ref
            .read(conversationProvider(senderId).notifier)
            .addReceivedMessage(chatMessage);
        print(
            "[ChatService] Added received 'chat_message' (ID: $messageId) to conversation with $senderId");
      } else if (type == 'message_ack') {
        print("[ChatService] Received message_ack: $decodedMessage");
        _handleMessageAck(decodedMessage);
      } else if (type == 'error') {
        print(
            "[ChatService] Received error message from server: ${decodedMessage['content']}");
      } else if (type == 'info') {
        print(
            "[ChatService] Received info message from server: ${decodedMessage['content']}");
      } else {
        print(
            "[ChatService] Received unhandled message type '$type': $decodedMessage");
      }
    } catch (e, stacktrace) {
      print("[ChatService] Error processing received message: $e");
      print("[ChatService] Stacktrace: $stacktrace");
    }
  }

  void sendMessage(
    int recipientUserId, {
    String? text,
    String? mediaUrl,
    String? mediaType,
    int? replyToMessageId,
  }) {
    // --- sendMessage logic remains the same ---
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
      print("[ChatService] Preparing media message payload.");
    } else if (text != null && text.trim().isNotEmpty) {
      payload['text'] = text.trim();
      payload['media_url'] = null;
      payload['media_type'] = null;
      isMediaMessage = false;
      print("[ChatService] Preparing text message payload.");
    } else {
      print("[ChatService] Cannot send: Message must have text or media.");
      return;
    }
    if (replyToMessageId != null && replyToMessageId > 0) {
      payload['reply_to_message_id'] = replyToMessageId;
      print("[ChatService] Adding replyToMessageId: $replyToMessageId");
    }
    final messageJson = jsonEncode(payload);
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
          sentAt: DateTime.now(),
          status: ChatMessageStatus.pending,
          isRead: false,
          readAt: null,
          mediaUrl: null,
          mediaType: null,
        );
        addPendingMessage(
            optimisticTempId, recipientUserId); // <<< Use public method
        _ref
            .read(conversationProvider(recipientUserId).notifier)
            .addSentMessage(sentMessage);
        print(
            "[ChatService] Added optimistic TEXT message (TempID: $optimisticTempId) to conversation with $recipientUserId");
      } else {
        print(
            "[ChatService] Media message payload prepared. Optimistic message added by ChatDetailScreen.");
      }
      _channel!.sink.add(messageJson);
      print("[ChatService] Message added to WebSocket sink.");
    } catch (e) {
      print("[ChatService] Error adding message to WebSocket sink: $e");
      if (optimisticTempId != null) {
        print(
            "[ChatService] Marking optimistic message $optimisticTempId as failed due to sink error.");
        removePendingMessage(optimisticTempId); // <<< Use public method
        _ref
            .read(conversationProvider(recipientUserId).notifier)
            .updateMessageStatus(optimisticTempId, ChatMessageStatus.failed,
                errorMessage: "Failed to send message.");
      }
      _handleError(e);
    }
  }

  void _handleMessageAck(Map<String, dynamic> ackData) {
    // --- _handleMessageAck logic remains the same ---
    final realMessageId = ackData['id'] as int?;
    final ackContent = ackData['content'] as String?;
    final mediaUrlAck = ackData['media_url'] as String?;
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
    if (_pendingMessages.isNotEmpty) {
      foundTempId = _pendingMessages.keys.first;
      foundRecipientId = _pendingMessages.values.first;
      print(
          "[ChatService _handleMessageAck] Found pending message via map: TempID=$foundTempId for Recipient=$foundRecipientId");
      removePendingMessage(foundTempId); // <<< Use public method
    } else {
      print(
          "[ChatService _handleMessageAck] No pending messages found in tracking map.");
    }
    if (foundTempId != null && foundRecipientId != null) {
      print(
          "[ChatService _handleMessageAck] Updating message (TempID: $foundTempId) for ack (Real ID: $realMessageId). Status -> Sent.");
      final conversationNotifier =
          _ref.read(conversationProvider(foundRecipientId).notifier);
      conversationNotifier.updateMessageStatus(
          foundTempId, ChatMessageStatus.sent,
          finalMessageId: realMessageId, finalMediaUrl: mediaUrlAck);
      print(
          "[ChatService _handleMessageAck] Message status updated successfully.");
    } else {
      print(
          "[ChatService _handleMessageAck] WARNING: Received message_ack for Real ID $realMessageId, but couldn't find a matching tracked pending message.");
    }
  }

  // --- Helper methods for tracking pending messages (NOW PUBLIC) ---
  void addPendingMessage(String tempId, int recipientId) {
    // <<< Renamed (Public)
    _pendingMessages[tempId] = recipientId;
    print(
        "[ChatService addPendingMessage] Added TempID: $tempId for Recipient: $recipientId. Count: ${_pendingMessages.length}");
  }

  void removePendingMessage(String tempId) {
    // <<< Renamed (Public)
    if (_pendingMessages.containsKey(tempId)) {
      _pendingMessages.remove(tempId);
      print(
          "[ChatService removePendingMessage] Removed TempID: $tempId. Count: ${_pendingMessages.length}");
    }
  }

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
    if (_ref.read(webSocketStateProvider) != newState) {
      _ref.read(webSocketStateProvider.notifier).state = newState;
      print("[ChatService] WebSocket state updated to: $newState");
    }
  }
}

// --- currentUserIdProvider remains the same ---
final currentUserIdProvider = Provider<int?>((ref) {
  return ref.watch(userProvider.select((user) => user.id));
});
// END OF FILE: lib/services/chat_service.dart
