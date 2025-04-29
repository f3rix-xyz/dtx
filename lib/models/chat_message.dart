// lib/models/chat_message.dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// Enum for message status remains the same
enum ChatMessageStatus {
  pending,
  uploading,
  sent,
  failed,
}

class ChatMessage {
  final String? tempId;
  final int messageID; // Real ID from backend (0 or negative for optimistic)
  final int senderUserID;
  final int recipientUserID;
  final String messageText; // Final text content
  final String? mediaUrl;
  final String? mediaType;
  final DateTime sentAt;
  final bool isRead;
  final DateTime? readAt;

  // Fields for optimistic UI (remain the same)
  final ChatMessageStatus status;
  final String? localFilePath;
  final String? initialLocalPath;
  final String? errorMessage;

  // *** ADDED: Reply fields ***
  final int? replyToMessageID;
  final int? repliedMessageSenderID;
  final String? repliedMessageTextSnippet;
  final String? repliedMessageMediaType;
  // *** END ADDED ***

  ChatMessage({
    this.tempId,
    required this.messageID,
    required this.senderUserID,
    required this.recipientUserID,
    required this.messageText, // Use the final parsed text
    this.mediaUrl,
    this.mediaType,
    required this.sentAt,
    this.isRead = false,
    this.readAt,
    this.status = ChatMessageStatus.sent,
    this.localFilePath,
    this.initialLocalPath,
    this.errorMessage,
    // *** ADDED: Reply fields to constructor ***
    this.replyToMessageID,
    this.repliedMessageSenderID,
    this.repliedMessageTextSnippet,
    this.repliedMessageMediaType,
    // *** END ADDED ***
  });

  bool isMe(int currentUserId) => senderUserID == currentUserId;

  // *** ADDED: isReply getter ***
  bool get isReply => replyToMessageID != null && replyToMessageID! > 0;
  // *** END ADDED ***

  bool get isMedia =>
      (mediaUrl != null && mediaUrl!.isNotEmpty) ||
      (localFilePath != null && localFilePath!.isNotEmpty);

  String get formattedTimestamp {
    // Formatting logic remains the same
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

  // --- MODIFIED: fromJson Factory ---
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // --- Helper Functions (Modified for Null Safety and pgtype) ---
    DateTime parseTimestamp(dynamic tsField) {
      if (tsField is String) {
        try {
          return DateTime.parse(tsField).toLocal();
        } catch (e) {
          print(
              "[ChatMessage.fromJson->parseTimestamp] Error parsing '$tsField': $e");
          return DateTime.now().toLocal(); // Fallback to local time
        }
      } else if (tsField is Map &&
          tsField['Valid'] == true &&
          tsField['Time'] is String) {
        try {
          return DateTime.parse(tsField['Time']).toLocal();
        } catch (e) {
          print(
              "[ChatMessage.fromJson->parseTimestamp] Error parsing from map '$tsField': $e");
          return DateTime.now().toLocal();
        }
      }
      print(
          "[ChatMessage.fromJson->parseTimestamp] Invalid timestamp type: ${tsField.runtimeType}. Returning local now.");
      return DateTime.now().toLocal(); // Fallback
    }

    DateTime? parseNullableTimestamp(dynamic tsField) {
      if (tsField is String) {
        try {
          return DateTime.parse(tsField).toLocal();
        } catch (_) {
          return null;
        }
      } else if (tsField is Map &&
          tsField['Valid'] == true &&
          tsField['Time'] is String) {
        try {
          return DateTime.parse(tsField['Time']).toLocal();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    String parsePgtypeText(dynamic field) {
      // Handles pgtype.Text (Map) or direct String
      if (field is String) {
        return field;
      } else if (field is Map &&
          field['Valid'] == true &&
          field['String'] is String) {
        return field['String'];
      }
      return ''; // Default empty string if null, not Valid, or wrong type
    }

    String? parseNullablePgtypeText(dynamic field) {
      if (field is String) {
        return field.isNotEmpty ? field : null;
      } else if (field is Map &&
          field['Valid'] == true &&
          field['String'] is String) {
        return (field['String'] as String).isNotEmpty ? field['String'] : null;
      }
      return null;
    }

    int? parsePgtypeInt(dynamic field) {
      // Handles pgtype.Int4/Int8 (Map) or direct int
      if (field is int) {
        return field;
      } else if (field is Map && field['Valid'] == true) {
        if (field.containsKey('Int64') && field['Int64'] is num) {
          return (field['Int64'] as num).toInt();
        } else if (field.containsKey('Int32') && field['Int32'] is num) {
          return (field['Int32'] as num).toInt();
        }
      } else if (field is String) {
        // Handle if backend sends int as string sometimes
        return int.tryParse(field);
      }
      return null; // Return null if invalid
    }

    String parseMessageTextRobust(Map<String, dynamic> jsonData) {
      // Check direct keys first (more likely from WS or simplified responses)
      if (jsonData['text'] is String) return jsonData['text'];
      if (jsonData['message_text'] is String) return jsonData['message_text'];
      // Check pgtype structure
      return parsePgtypeText(jsonData['message_text']);
    }
    // --- End Helper Functions ---

    final messageID = json['id'] as int? ?? 0;
    final senderUserID = json['sender_user_id'] as int? ?? 0;
    final recipientUserID = json['recipient_user_id'] as int? ?? 0;
    final text = parseMessageTextRobust(json); // Use robust helper
    final mediaUrl = parseNullablePgtypeText(json['media_url']);
    final mediaType = parseNullablePgtypeText(json['media_type']);
    final sentAt = parseTimestamp(json['sent_at']);
    final isRead = json['is_read'] as bool? ?? false;
    final readAt = parseNullableTimestamp(json['read_at']);

    // *** ADDED: Parse reply fields ***
    final replyToMessageID = parsePgtypeInt(json['reply_to_message_id']);
    final repliedMessageSenderID =
        parsePgtypeInt(json['replied_message_sender_id']);
    // replied_message_text_snippet is interface{}, likely String or null
    final repliedMessageTextSnippet =
        json['replied_message_text_snippet'] as String?;
    final repliedMessageMediaType =
        parseNullablePgtypeText(json['replied_message_media_type']);

    if (kDebugMode) {
      print(
          "[ChatMessage.fromJson ID: $messageID] Parsed Core: sender=$senderUserID, recipient=$recipientUserID, text='$text', mediaUrl=$mediaUrl, mediaType=$mediaType, sentAt=$sentAt, isRead=$isRead, readAt=$readAt");
      if (replyToMessageID != null) {
        print(
            "[ChatMessage.fromJson ID: $messageID] Parsed Reply Info: replyTo=$replyToMessageID, origSender=$repliedMessageSenderID, snippet='$repliedMessageTextSnippet', origMediaType=$repliedMessageMediaType");
      }
    }

    return ChatMessage(
      messageID: messageID,
      senderUserID: senderUserID,
      recipientUserID: recipientUserID,
      messageText: text,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      sentAt: sentAt,
      isRead: isRead,
      readAt: readAt,
      status: ChatMessageStatus.sent, // Default status for received messages
      // *** ADDED: Pass reply fields to constructor ***
      replyToMessageID: replyToMessageID,
      repliedMessageSenderID: repliedMessageSenderID,
      repliedMessageTextSnippet: repliedMessageTextSnippet,
      repliedMessageMediaType: repliedMessageMediaType,
      // *** END ADDED ***
    );
  }
  // --- END MODIFIED fromJson Factory ---

  // --- MODIFIED: copyWith method ---
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
    bool clearLocalFilePath = false,
    String? initialLocalPath,
    String? errorMessage,
    bool clearErrorMessage = false,
    // *** ADDED: Reply fields ***
    int? Function()? replyToMessageID, // Nullable function for clearing
    int? Function()? repliedMessageSenderID,
    String? Function()? repliedMessageTextSnippet,
    String? Function()? repliedMessageMediaType,
    // *** END ADDED ***
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
      localFilePath:
          clearLocalFilePath ? null : (localFilePath ?? this.localFilePath),
      initialLocalPath: initialLocalPath ?? this.initialLocalPath,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      // *** ADDED: Assign reply fields ***
      replyToMessageID:
          replyToMessageID != null ? replyToMessageID() : this.replyToMessageID,
      repliedMessageSenderID: repliedMessageSenderID != null
          ? repliedMessageSenderID()
          : this.repliedMessageSenderID,
      repliedMessageTextSnippet: repliedMessageTextSnippet != null
          ? repliedMessageTextSnippet()
          : this.repliedMessageTextSnippet,
      repliedMessageMediaType: repliedMessageMediaType != null
          ? repliedMessageMediaType()
          : this.repliedMessageMediaType,
      // *** END ADDED ***
    );
  }
  // --- END MODIFIED copyWith ---
}
