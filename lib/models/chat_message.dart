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
  final int messageID;
  final int senderUserID;
  final int recipientUserID;
  final String messageText;
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

  // *** Reply fields (Keep as is) ***
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
    required this.messageText,
    this.mediaUrl,
    this.mediaType,
    required this.sentAt,
    this.isRead = false,
    this.readAt,
    this.status = ChatMessageStatus.sent,
    this.localFilePath,
    this.initialLocalPath,
    this.errorMessage,
    // *** Reply fields to constructor (Keep as is) ***
    this.replyToMessageID,
    this.repliedMessageSenderID,
    this.repliedMessageTextSnippet,
    this.repliedMessageMediaType,
    // *** END ADDED ***
  });

  bool isMe(int currentUserId) => senderUserID == currentUserId;

  // *** isReply getter (Keep as is) ***
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

  // --- *** CORRECTED: fromJson Factory *** ---
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // --- Helper Functions (Keep as is) ---
    DateTime parseTimestamp(dynamic tsField) {
      if (tsField is String) {
        try {
          return DateTime.parse(tsField).toLocal();
        } catch (e) {
          print(
              "[ChatMessage.fromJson->parseTimestamp] Error parsing '$tsField': $e");
          return DateTime.now().toLocal();
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
      return DateTime.now().toLocal();
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
      if (field is String) {
        return field;
      } else if (field is Map &&
          field['Valid'] == true &&
          field['String'] is String) {
        return field['String'];
      }
      return '';
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
      if (field is int) {
        return field;
      } else if (field is Map && field['Valid'] == true) {
        if (field.containsKey('Int64') && field['Int64'] is num) {
          return (field['Int64'] as num).toInt();
        } else if (field.containsKey('Int32') && field['Int32'] is num) {
          return (field['Int32'] as num).toInt();
        }
      } else if (field is String) {
        return int.tryParse(field);
      }
      return null;
    }

    String parseMessageTextRobust(Map<String, dynamic> jsonData) {
      if (jsonData['text'] is String)
        return jsonData['text']; // Direct check added
      if (jsonData['message_text'] is String)
        return jsonData['message_text']; // Direct check added
      return parsePgtypeText(jsonData['message_text']);
    }
    // --- End Helper Functions ---

    final messageID = json['id'] as int? ?? 0;
    final senderUserID = json['sender_user_id'] as int? ?? 0;
    final recipientUserID = json['recipient_user_id'] as int? ?? 0;
    final text = parseMessageTextRobust(json);
    final mediaUrl = parseNullablePgtypeText(json['media_url']);
    final mediaType = parseNullablePgtypeText(json['media_type']);
    final sentAt = parseTimestamp(json['sent_at']);
    final isRead = json['is_read'] as bool? ?? false;
    final readAt = parseNullableTimestamp(json['read_at']);

    // *** CORRECTED: Parse reply fields from nested 'reply_to' object ***
    int? replyToMessageID;
    int? repliedMessageSenderID;
    String? repliedMessageTextSnippet;
    String? repliedMessageMediaType; // Need to parse this as well

    // Check if the 'reply_to' key exists and is a Map
    if (json.containsKey('reply_to') &&
        json['reply_to'] is Map<String, dynamic>) {
      final replyData = json['reply_to'] as Map<String, dynamic>;
      print(
          "[ChatMessage.fromJson ID: $messageID] Found 'reply_to' object: $replyData"); // Log found reply data

      // Try parsing fields within the 'reply_to' map
      replyToMessageID =
          parsePgtypeInt(replyData['message_id']); // Use helper for flexibility
      repliedMessageSenderID =
          parsePgtypeInt(replyData['sender_id']); // Use helper for flexibility

      // Snippet might be directly a string or null
      repliedMessageTextSnippet = replyData['text_snippet'] as String?;

      // Media type might be pgtype.Text or direct string
      repliedMessageMediaType =
          parseNullablePgtypeText(replyData['media_type']);
    } else if (json.containsKey('reply_to')) {
      print(
          "[ChatMessage.fromJson ID: $messageID] Found 'reply_to' key, but it's not a Map. Type: ${json['reply_to'].runtimeType}");
    }

    if (kDebugMode) {
      print(
          "[ChatMessage.fromJson ID: $messageID] Parsed Core: sender=$senderUserID, recipient=$recipientUserID, text='$text', mediaUrl=$mediaUrl, mediaType=$mediaType, sentAt=$sentAt, isRead=$isRead, readAt=$readAt");
      if (replyToMessageID != null) {
        print(
            "[ChatMessage.fromJson ID: $messageID] Parsed Reply Info: replyTo=$replyToMessageID, origSender=$repliedMessageSenderID, snippet='$repliedMessageTextSnippet', origMediaType=$repliedMessageMediaType");
      } else {
        print(
            "[ChatMessage.fromJson ID: $messageID] No valid reply info parsed.");
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
      status: ChatMessageStatus.sent,
      // *** Pass correctly parsed reply fields ***
      replyToMessageID: replyToMessageID,
      repliedMessageSenderID: repliedMessageSenderID,
      repliedMessageTextSnippet: repliedMessageTextSnippet,
      repliedMessageMediaType: repliedMessageMediaType,
      // *** END ADDED ***
    );
  }
  // --- END CORRECTED fromJson Factory ---

  // --- copyWith method (Keep as is) ---
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
    int? Function()? replyToMessageID,
    int? Function()? repliedMessageSenderID,
    String? Function()? repliedMessageTextSnippet,
    String? Function()? repliedMessageMediaType,
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
    );
  }
  // --- END copyWith ---
}
