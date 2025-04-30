// START OF FILE: lib/models/ws_message_model.dart

import 'dart:convert';

/// Represents the structure of messages exchanged over WebSocket.
/// Used for BOTH sending (client -> server) and receiving (server -> client).
/// Fields are nullable to accommodate different message types.
class WsMessage {
  // General fields
  final String type;
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
  final int?
      messageID; // The ID of the message being reacted to OR last read message ID
  final String? emoji; // Nullable
  final int? reactorUserID; // User who reacted (sent by backend)
  final bool? isRemoved; // True if reaction was removed (sent by backend)

  // Status update specific fields
  final int? userID; // User whose status changed (sent by backend)
  final String? status; // "online" or "offline" (sent by backend)

  // Read receipt specific fields
  final int?
      readerUserID; // User who read the messages (sent by backend for messages_read_update)
  final int?
      otherUserID; // <<<--- ADDED BACK: User whose messages were marked read (used for mark_read send & mark_read_ack receive)

  // Typing/Recording indicator fields
  final int? typingUserID;
  final bool? isTyping;
  final int? recordingUserID;
  final bool? isRecording;

  // Generic/Error/Info/Ack fields
  final String? content; // For error/info/ack messages (sent by backend)
  final int? count; // e.g., for mark_read_ack

  WsMessage({
    required this.type,
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
    this.otherUserID, // <<<--- ADDED to constructor
    this.typingUserID,
    this.isTyping,
    this.recordingUserID,
    this.isRecording,
    this.content,
    this.count,
  });

  // Factory constructor for parsing JSON received from WebSocket
  factory WsMessage.fromJson(Map<String, dynamic> json) {
    // Helper functions (keep as is)
    int? getInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    bool? getBool(String key) {
      final value = json[key];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is int) return value == 1;
      return null;
    }

    String? getString(String key) {
      final value = json[key];
      if (value is String) return value;
      return null;
    }

    return WsMessage(
      type: getString('type') ?? 'unknown',
      id: getInt('id'),
      senderUserID: getInt('sender_user_id'),
      recipientUserID: getInt('recipient_user_id'),
      text: getString('text'),
      mediaURL: getString('media_url'),
      mediaType: getString('media_type'),
      sentAt: getString('sent_at'),
      replyToMessageID: getInt('reply_to_message_id'),
      messageID: getInt('message_id'),
      emoji: getString('emoji'),
      reactorUserID: getInt('reactor_user_id'),
      isRemoved: getBool('is_removed'),
      userID: getInt('user_id'),
      status: getString('status'),
      readerUserID: getInt('reader_user_id'),
      otherUserID: getInt('other_user_id'), // <<<--- ADDED parsing
      typingUserID: getInt('typing_user_id'),
      isTyping: getBool('is_typing'),
      recordingUserID: getInt('recording_user_id'),
      isRecording: getBool('is_recording'),
      content: getString('content'),
      count: getInt('count'),
    );
  }

  // Method to convert to JSON (for sending)
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'type': type,
    };
    // Add fields only if they are not null for sending
    // (Careful not to send fields meant only for receiving)
    if (recipientUserID != null) data['recipient_user_id'] = recipientUserID;
    if (text != null) data['text'] = text;
    if (mediaURL != null) data['media_url'] = mediaURL;
    if (mediaType != null) data['media_type'] = mediaType;
    if (replyToMessageID != null)
      data['reply_to_message_id'] = replyToMessageID;
    if (messageID != null)
      data['message_id'] = messageID; // Used for reactions and mark_read
    if (emoji != null) data['emoji'] = emoji; // Used for reactions
    if (otherUserID != null)
      data['other_user_id'] = otherUserID; // Used for mark_read
    if (isTyping != null) data['is_typing'] = isTyping; // Used for typing event
    if (isRecording != null)
      data['is_recording'] = isRecording; // Used for recording event

    return data;
  }
}

// END OF FILE: lib/models/ws_message_model.dart
