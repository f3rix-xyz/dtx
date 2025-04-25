// lib/models/chat_message.dart
import 'package:intl/intl.dart';

// --- NEW: Enum for message status ---
enum ChatMessageStatus {
  pending, // Added to local list, upload not started/failed immediately
  uploading, // Upload in progress
  sent, // Confirmed sent (or received)
  failed, // Upload or send failed
}
// --- END NEW ---

class ChatMessage {
  // Use String for tempId for flexibility (e.g., timestamp-based)
  final String? tempId; // Unique temporary ID for optimistic messages
  final int messageID; // Real ID from backend (0 or negative for optimistic)
  final int senderUserID;
  final int recipientUserID;
  final String messageText;
  final String? mediaUrl; // Final URL after upload
  final String? mediaType; // Nullable type (e.g., "image/jpeg", "video/mp4")
  final DateTime sentAt; // Timestamp when *sent* or added optimistically
  final bool isRead; // Read status from recipient perspective
  final DateTime? readAt;

  // --- NEW: Fields for optimistic UI ---
  final ChatMessageStatus status; // Tracks sending state
  final String?
      localFilePath; // Path to the local file being uploaded (TEMPORARY, cleared after sent)
  final String?
      initialLocalPath; // NEW: Always store the first path if it was local
  final String? errorMessage; // Store failure reason
  // --- END NEW ---

  ChatMessage({
    this.tempId, // Add tempId
    required this.messageID,
    required this.senderUserID,
    required this.recipientUserID,
    required this.messageText,
    this.mediaUrl,
    this.mediaType,
    required this.sentAt,
    this.isRead = false,
    this.readAt,
    // --- NEW: Add status and local path to constructor ---
    this.status =
        ChatMessageStatus.sent, // Default to sent for received/fetched messages
    this.localFilePath,
    this.initialLocalPath, // Add initialLocalPath
    this.errorMessage,
    // --- END NEW ---
  });

  bool isMe(int currentUserId) => senderUserID == currentUserId;

  // Updated: Check either final URL or temporary local path
  bool get isMedia =>
      (mediaUrl != null && mediaUrl!.isNotEmpty) ||
      (localFilePath != null && localFilePath!.isNotEmpty);

  String get formattedTimestamp {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(sentAt.year, sentAt.month, sentAt.day);

    if (messageDay == today) {
      return DateFormat.jm().format(sentAt.toLocal());
    } else if (today.difference(messageDay).inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat.yMd().format(sentAt.toLocal());
    }
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // --- Helper functions remain the same ---
    DateTime parseTimestamp(dynamic tsField) {
      if (tsField is String) {
        try {
          return DateTime.parse(tsField).toLocal();
        } catch (e) {
          print("Error parsing timestamp '$tsField': $e");
          return DateTime.now().toUtc();
        }
      }
      return DateTime.now().toUtc();
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

    // --- Updated Factory ---
    return ChatMessage(
      // No tempId, localFilePath, initialLocalPath, errorMessage from JSON
      messageID: json['MessageID'] as int? ?? json['message_id'] as int? ?? 0,
      senderUserID:
          json['SenderUserID'] as int? ?? json['sender_user_id'] as int? ?? 0,
      recipientUserID: json['RecipientUserID'] as int? ??
          json['recipient_user_id'] as int? ??
          0,
      messageText:
          json['MessageText'] as String? ?? json['text'] as String? ?? '',
      mediaUrl: json['MediaUrl'] as String? ?? json['media_url'] as String?,
      mediaType: json['MediaType'] as String? ?? json['media_type'] as String?,
      sentAt: parseTimestamp(json['SentAt'] ?? json['sent_at']),
      isRead: json['IsRead'] as bool? ?? json['is_read'] as bool? ?? false,
      readAt: parseNullableTimestamp(json['ReadAt'] ?? json['read_at']),
      status:
          ChatMessageStatus.sent, // Messages from API/WS are considered 'sent'
    );
    // --- END Updated Factory ---
  }

  // --- Updated copyWith method ---
  ChatMessage copyWith({
    String? tempId,
    int? messageID,
    int? senderUserID,
    int? recipientUserID,
    String? messageText,
    String? mediaUrl,
    String? mediaType,
    DateTime? sentAt,
    bool? isRead,
    DateTime? readAt,
    ChatMessageStatus? status,
    String? localFilePath,
    bool clearLocalFilePath = false, // Flag to explicitly clear temporary path
    String? initialLocalPath, // Usually don't update this via copyWith
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ChatMessage(
      tempId: tempId ?? this.tempId,
      messageID: messageID ?? this.messageID,
      senderUserID: senderUserID ?? this.senderUserID,
      recipientUserID: recipientUserID ?? this.recipientUserID,
      messageText: messageText ?? this.messageText,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      status: status ?? this.status,
      // Clear localFilePath if flag is set OR use new value OR keep old
      localFilePath:
          clearLocalFilePath ? null : (localFilePath ?? this.localFilePath),
      initialLocalPath:
          initialLocalPath ?? this.initialLocalPath, // Preserve original path
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
  // --- END Updated copyWith method ---
}
