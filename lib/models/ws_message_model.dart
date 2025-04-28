// START OF FILE: lib/models/ws_message_model.dart
// NEW FILE: lib/models/ws_message_model.dart

import 'dart:convert';

/// Represents the structure of messages exchanged over WebSocket.
/// Used for BOTH sending (client -> server) and receiving (server -> client).
/// Fields are nullable to accommodate different message types.
class WsMessage {
  // General fields
  final String
      type; // Type sent BY backend ("chat_message", "error", "info", "status_update", etc.)
  final int? id; // Message ID (usually for chat messages, sent by backend)

  // Chat Message specific fields
  final int? senderUserID;
  final int? recipientUserID; // REQUIRED when sending FROM client
  final String? text; // Nullable
  final String? mediaURL; // Nullable
  final String? mediaType; // Nullable
  final String? sentAt; // ISO 8601 string (sent by backend)
  final int? replyToMessageID; // Nullable

  // Reaction specific fields
  final int? messageID; // The ID of the message being reacted to
  final String? emoji; // Nullable
  final int? reactorUserID; // User who reacted (sent by backend)
  final bool? isRemoved; // True if reaction was removed (sent by backend)

  // Status update specific fields
  final int? userID; // User whose status changed (sent by backend)
  final String? status; // "online" or "offline" (sent by backend)

  // Read receipt specific fields (when other user reads messages)
  final int? readerUserID; // User who read the messages (sent by backend)
  // MessageID (re-used from reaction fields) indicates up to which message was read

  // Generic/Error/Info fields
  final String? content; // For error/info messages (sent by backend)

  // Acknowledgement specific fields (server confirms client message)
  final int? count; // e.g., for mark_read_ack

  WsMessage({
    required this.type, // Type is always required for received messages
    this.id,
    this.senderUserID,
    this.recipientUserID,
    this.text,
    this.mediaURL,
    this.mediaType,
    this.sentAt,
    this.replyToMessageID,
    this.messageID,
    this.emoji,
    this.reactorUserID,
    this.isRemoved,
    this.userID,
    this.status,
    this.readerUserID,
    this.content,
    this.count,
  });

  // Factory constructor for parsing JSON received from WebSocket
  factory WsMessage.fromJson(Map<String, dynamic> json) {
    // Helper function to safely get int?
    int? getInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Helper function to safely get bool?
    bool? getBool(String key) {
      final value = json[key];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is int) return value == 1;
      return null;
    }

    // Helper function to safely get String?
    String? getString(String key) {
      final value = json[key];
      if (value is String) return value;
      return null;
    }

    return WsMessage(
      type: getString('type') ?? 'unknown', // Default to 'unknown' if missing
      id: getInt('id'),
      senderUserID: getInt('sender_user_id'),
      recipientUserID: getInt('recipient_user_id'),
      text: getString('text'),
      mediaURL: getString('media_url'),
      mediaType: getString('media_type'),
      sentAt: getString('sent_at'), // Keep as string for now
      replyToMessageID: getInt('reply_to_message_id'),
      messageID: getInt('message_id'), // Used for reactions and read receipts
      emoji: getString('emoji'),
      reactorUserID: getInt('reactor_user_id'),
      isRemoved: getBool('is_removed'),
      userID: getInt('user_id'), // Used for status updates
      status: getString('status'),
      readerUserID: getInt('reader_user_id'),
      content: getString('content'),
      count: getInt('count'),
    );
  }

  // Method to convert to JSON (mainly for debugging, sending structure is simpler)
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'type': type,
    };
    // Add fields only if they are not null
    if (id != null) data['id'] = id;
    if (senderUserID != null) data['sender_user_id'] = senderUserID;
    if (recipientUserID != null) data['recipient_user_id'] = recipientUserID;
    if (text != null) data['text'] = text;
    if (mediaURL != null) data['media_url'] = mediaURL;
    if (mediaType != null) data['media_type'] = mediaType;
    if (sentAt != null) data['sent_at'] = sentAt;
    if (replyToMessageID != null)
      data['reply_to_message_id'] = replyToMessageID;
    if (messageID != null) data['message_id'] = messageID;
    if (emoji != null) data['emoji'] = emoji;
    if (reactorUserID != null) data['reactor_user_id'] = reactorUserID;
    if (isRemoved != null) data['is_removed'] = isRemoved;
    if (userID != null) data['user_id'] = userID;
    if (status != null) data['status'] = status;
    if (readerUserID != null) data['reader_user_id'] = readerUserID;
    if (content != null) data['content'] = content;
    if (count != null) data['count'] = count;
    return data;
  }
}

// END OF FILE: lib/models/ws_message_model.dart
