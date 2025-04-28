// lib/models/chat_message.dart
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
  });

  bool isMe(int currentUserId) => senderUserID == currentUserId;

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

  // --- UPDATED: fromJson Factory with Corrected Parsing ---
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Helper functions for timestamps (remain the same)
    DateTime parseTimestamp(dynamic tsField) {
      if (tsField is String) {
        try {
          return DateTime.parse(tsField).toLocal();
        } catch (e) {
          print(
              "[ChatMessage.fromJson] Error parsing timestamp '$tsField': $e");
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

    // *** REVISED: Helper function to parse message text ***
    String parseMessageText(Map<String, dynamic> jsonData) {
      print(
          "[ChatMessage.fromJson->parseMessageText] Parsing message data: $jsonData");

      // --- NEW: Prioritize checking if 'message_text' is a String ---
      if (jsonData.containsKey('message_text') &&
          jsonData['message_text'] is String) {
        final extractedText = jsonData['message_text'];
        print(
            "[parseMessageText] Found 'message_text' key as String: '$extractedText'");
        return extractedText;
      }
      // --- END NEW ---

      // 1. Check for 'message_text' as a Map (pgtype.Text structure - Fallback)
      if (jsonData.containsKey('message_text') &&
          jsonData['message_text'] is Map) {
        print("[parseMessageText] Found 'message_text' key as Map.");
        final textMap = jsonData['message_text'] as Map<String, dynamic>;
        if (textMap['Valid'] == true && textMap['String'] is String) {
          final extractedText = textMap['String'];
          print(
              "[parseMessageText] Extracted text from message_text.String: '$extractedText'");
          return extractedText;
        } else {
          print(
              "[parseMessageText] message_text Map was not Valid or String key missing/invalid type. Map: $textMap");
        }
      } else if (jsonData.containsKey('message_text')) {
        // Log if 'message_text' exists but is not a String or Map we handled
        print(
            "[parseMessageText] Found 'message_text' key, but it's not a String or Map. Type: ${jsonData['message_text'].runtimeType}, Value: ${jsonData['message_text']}");
      } else {
        print("[parseMessageText] 'message_text' key NOT found.");
      }

      // 2. Fallback for 'text' key as a String
      if (jsonData.containsKey('text')) {
        if (jsonData['text'] is String) {
          final extractedText = jsonData['text'];
          print(
              "[parseMessageText] Found 'text' key as String: '$extractedText'");
          return extractedText;
        } else {
          print(
              "[parseMessageText] Found 'text' key, but it's NOT a String. Type: ${jsonData['text'].runtimeType}, Value: ${jsonData['text']}");
        }
      } else {
        print("[parseMessageText] 'text' key NOT found.");
      }

      // 3. Fallback for 'MessageText' key as a String
      if (jsonData.containsKey('MessageText')) {
        if (jsonData['MessageText'] is String) {
          final extractedText = jsonData['MessageText'];
          print(
              "[parseMessageText] Found 'MessageText' key as String: '$extractedText'");
          return extractedText;
        } else {
          print(
              "[parseMessageText] Found 'MessageText' key, but it's NOT a String. Type: ${jsonData['MessageText'].runtimeType}, Value: ${jsonData['MessageText']}");
        }
      } else {
        print("[parseMessageText] 'MessageText' key NOT found.");
      }

      // 4. Default if no valid text field found
      print(
          "[parseMessageText] No valid text found in expected keys. Returning empty string.");
      return '';
    }
    // *** END REVISED Helper ***

    final messageID = json['id'] as int? ?? 0;
    final senderUserID = json['sender_user_id'] as int? ?? 0;
    final recipientUserID = json['recipient_user_id'] as int? ?? 0;
    final text = parseMessageText(json); // Use revised helper
    final mediaUrl = json['media_url'] as String?;
    final mediaType = json['media_type'] as String?;
    final sentAt = parseTimestamp(json['sent_at']);
    final isRead = json['is_read'] as bool? ?? false;
    final readAt = parseNullableTimestamp(json['read_at']);

    print(
        "[ChatMessage.fromJson] Creating ChatMessage with: id=$messageID, sender=$senderUserID, recipient=$recipientUserID, text='$text', mediaUrl=$mediaUrl, mediaType=$mediaType, sentAt=$sentAt, isRead=$isRead, readAt=$readAt");

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
    );
  }
  // --- END UPDATED fromJson Factory ---

  // copyWith method remains the same
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
    );
  }
}
