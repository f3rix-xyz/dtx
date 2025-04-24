// lib/models/chat_message.dart
import 'package:intl/intl.dart';

class ChatMessage {
  final int messageID;
  final int senderUserID;
  final int recipientUserID;
  final String messageText; // Keep for text messages
  final String? mediaUrl; // Nullable URL for media
  final String? mediaType; // Nullable type (e.g., "image/jpeg", "video/mp4")
  final DateTime sentAt;
  final bool isRead;
  final DateTime? readAt;

  ChatMessage({
    required this.messageID,
    required this.senderUserID,
    required this.recipientUserID,
    required this.messageText,
    this.mediaUrl, // Add to constructor
    this.mediaType, // Add to constructor
    required this.sentAt,
    required this.isRead,
    this.readAt,
  });

  bool isMe(int currentUserId) => senderUserID == currentUserId;

  // Method to determine if this is a media message
  bool get isMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  String get formattedTimestamp {
    // ... (timestamp formatting remains the same) ...
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(sentAt.year, sentAt.month, sentAt.day);

    if (messageDay == today) {
      return DateFormat.jm().format(sentAt.toLocal()); // e.g., 10:30 AM
    } else if (today.difference(messageDay).inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat.yMd().format(sentAt.toLocal()); // e.g., 10/25/2023
    }
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Helper to parse timestamp safely
    DateTime parseTimestamp(dynamic tsField) {
      if (tsField is String) {
        try {
          return DateTime.parse(tsField).toLocal();
        } catch (e) {
          print("Error parsing timestamp '$tsField': $e");
          return DateTime.now().toUtc(); // Fallback to UTC now
        }
      }
      return DateTime.now().toUtc(); // Fallback
    }

    DateTime? parseNullableTimestamp(dynamic tsField) {
      if (tsField is String) {
        try {
          return DateTime.parse(tsField).toLocal();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // --- MODIFIED: Include mediaUrl and mediaType parsing ---
    return ChatMessage(
      // Use keys matching the JSON response from GetConversationMessages
      // OR the structure received from WebSocket via ChatService._onMessageReceived
      messageID: json['MessageID'] as int? ??
          json['message_id'] as int? ??
          0, // Support both keys
      senderUserID:
          json['SenderUserID'] as int? ?? json['sender_user_id'] as int? ?? 0,
      recipientUserID: json['RecipientUserID'] as int? ??
          json['recipient_user_id'] as int? ??
          0,
      messageText: json['MessageText'] as String? ??
          json['text'] as String? ??
          '', // Prioritize DB key, fallback to WS key
      // Parse media fields (might be null)
      mediaUrl: json['MediaUrl'] as String? ?? json['media_url'] as String?,
      mediaType: json['MediaType'] as String? ?? json['media_type'] as String?,
      sentAt:
          parseTimestamp(json['SentAt'] ?? json['sent_at']), // Check both keys
      isRead: json['IsRead'] as bool? ?? json['is_read'] as bool? ?? false,
      readAt: parseNullableTimestamp(json['ReadAt'] ?? json['read_at']),
    );
    // --- END MODIFICATION ---
  }

  // No need for toJsonForSend as ChatService handles payload creation directly
}
