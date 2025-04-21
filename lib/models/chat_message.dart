// lib/models/chat_message.dart
import 'package:intl/intl.dart';

class ChatMessage {
  final int messageID;
  final int senderUserID;
  final int recipientUserID;
  final String messageText;
  final DateTime sentAt;
  final bool isRead;
  final DateTime? readAt; // Nullable DateTime

  ChatMessage({
    required this.messageID,
    required this.senderUserID,
    required this.recipientUserID,
    required this.messageText,
    required this.sentAt,
    required this.isRead,
    this.readAt,
  });

  // Helper to check if the message was sent by the currently authenticated user
  bool isMe(int currentUserId) => senderUserID == currentUserId;

  String get formattedTimestamp {
    // Example formatting, adjust as needed
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
          // Handle potential 'Z' for UTC time from Go
          return DateTime.parse(tsField).toLocal();
        } catch (e) {
          print("Error parsing timestamp '$tsField': $e");
          return DateTime.now(); // Fallback
        }
      }
      // Add more checks if backend sends different formats (e.g., Unix timestamp)
      return DateTime.now(); // Fallback
    }

    DateTime? parseNullableTimestamp(dynamic tsField) {
      if (tsField is String) {
        try {
          return DateTime.parse(tsField).toLocal();
        } catch (_) {
          return null; // Return null if parsing fails
        }
      }
      return null;
    }

    return ChatMessage(
      // Use keys matching the JSON response from GetConversationMessages
      messageID: json['MessageID'] as int? ?? 0,
      senderUserID: json['SenderUserID'] as int? ?? 0,
      recipientUserID: json['RecipientUserID'] as int? ?? 0,
      messageText: json['MessageText'] as String? ?? '',
      sentAt: parseTimestamp(json['SentAt']),
      isRead: json['IsRead'] as bool? ?? false,
      readAt: parseNullableTimestamp(json['ReadAt']),
    );
  }

  // Method to convert to the JSON format expected by the WebSocket server
  Map<String, dynamic> toJsonForSend(int recipientId) {
    return {
      'recipient_user_id': recipientId,
      'text': messageText,
    };
  }
}
