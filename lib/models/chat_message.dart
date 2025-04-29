// File: lib/models/chat_message.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

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
  final ChatMessageStatus status;
  final String? localFilePath;
  final String? initialLocalPath;
  final String? errorMessage;
  final int? replyToMessageID;
  final int? repliedMessageSenderID;
  final String? repliedMessageTextSnippet;
  final String? repliedMessageMediaType;
  final Map<String, int>? reactionsSummary;
  final String? currentUserReaction;

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
    this.replyToMessageID,
    this.repliedMessageSenderID,
    this.repliedMessageTextSnippet,
    this.repliedMessageMediaType,
    this.reactionsSummary,
    this.currentUserReaction,
  });

  bool isMe(int currentUserId) => senderUserID == currentUserId;
  bool get isReply => replyToMessageID != null && replyToMessageID! > 0;
  bool get isMedia =>
      (mediaUrl != null && mediaUrl!.isNotEmpty) ||
      (localFilePath != null && localFilePath!.isNotEmpty);

  String get formattedTimestamp {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(sentAt.year, sentAt.month, sentAt.day);
    if (messageDay == today) return DateFormat.jm().format(sentAt.toLocal());
    if (today.difference(messageDay).inDays == 1) return 'Yesterday';
    return DateFormat.yMd().format(sentAt.toLocal());
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // --- Helper Functions (Keep) ---
    DateTime parseTimestamp(dynamic tsField) {
      if (tsField is String) {
        try {
          return DateTime.parse(tsField).toLocal();
        } catch (e) {
          if (kDebugMode)
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
          if (kDebugMode)
            print(
                "[ChatMessage.fromJson->parseTimestamp] Error parsing from map '$tsField': $e");
          return DateTime.now().toLocal();
        }
      }
      if (kDebugMode)
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
      if (field is String) return field;
      if (field is Map && field['Valid'] == true && field['String'] is String)
        return field['String'];
      return '';
    }

    String? parseNullablePgtypeText(dynamic field) {
      if (field is String) return field.isNotEmpty ? field : null;
      if (field is Map && field['Valid'] == true && field['String'] is String)
        return (field['String'] as String).isNotEmpty ? field['String'] : null;
      return null;
    }

    int? parsePgtypeInt(dynamic field) {
      if (field is int) return field;
      if (field is Map && field['Valid'] == true) {
        if (field.containsKey('Int64') && field['Int64'] is num)
          return (field['Int64'] as num).toInt();
        if (field.containsKey('Int32') && field['Int32'] is num)
          return (field['Int32'] as num).toInt();
      } else if (field is String) return int.tryParse(field);
      return null;
    }

    String parseMessageTextRobust(Map<String, dynamic> jsonData) {
      if (jsonData['text'] is String) return jsonData['text'];
      if (jsonData['message_text'] is String) return jsonData['message_text'];
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

    // Parse reply fields (Keep)
    int? replyToMessageID;
    int? repliedMessageSenderID;
    String? repliedMessageTextSnippet;
    String? repliedMessageMediaType;
    if (json.containsKey('reply_to') &&
        json['reply_to'] is Map<String, dynamic>) {
      final replyData = json['reply_to'] as Map<String, dynamic>;
      if (kDebugMode)
        print(
            "[ChatMessage.fromJson ID: $messageID] Found 'reply_to' object: $replyData");
      replyToMessageID = parsePgtypeInt(replyData['message_id']);
      repliedMessageSenderID = parsePgtypeInt(replyData['sender_id']);
      repliedMessageTextSnippet = replyData['text_snippet'] as String?;
      repliedMessageMediaType =
          parseNullablePgtypeText(replyData['media_type']);
    } else if (json.containsKey('reply_to')) {
      if (kDebugMode)
        print(
            "[ChatMessage.fromJson ID: $messageID] Found 'reply_to' key, but it's not a Map. Type: ${json['reply_to'].runtimeType}");
    }

    // *** --- START: Reaction Parsing MODIFIED --- ***
    Map<String, int>? reactionsSummary;
    // Use the correct key from the API spec: "reactions"
    final reactionsData = json['reactions'];

    if (kDebugMode)
      print(
          "[ChatMessage.fromJson ID: $messageID] Parsing 'reactions' field. Type: ${reactionsData.runtimeType}, Value: $reactionsData");

    // Directly check if it's a Map<String, dynamic> (likely from direct JSON parsing)
    if (reactionsData is Map<String, dynamic>) {
      try {
        reactionsSummary = reactionsData.map((key, value) {
          final count = value is num ? value.toInt() : 0;
          return MapEntry(key, count);
        });
        if (kDebugMode)
          print(
              "[ChatMessage.fromJson ID: $messageID] Parsed reactionsSummary directly from Map: $reactionsSummary");
      } catch (e) {
        if (kDebugMode)
          print(
              "[ChatMessage.fromJson ID: $messageID] Error converting Map<String, dynamic> to Map<String, int>: $e");
        reactionsSummary = {};
      }
    } else if (reactionsData is String) {
      // Handle case where it might be a JSON string
      if (reactionsData.isNotEmpty && reactionsData != "{}") {
        try {
          final decodedMap = jsonDecode(reactionsData) as Map<String, dynamic>;
          reactionsSummary = decodedMap.map((key, value) {
            final count = value is num ? value.toInt() : 0;
            return MapEntry(key, count);
          });
          if (kDebugMode)
            print(
                "[ChatMessage.fromJson ID: $messageID] Parsed reactionsSummary from String: $reactionsSummary");
        } catch (e) {
          if (kDebugMode)
            print(
                "[ChatMessage.fromJson ID: $messageID] Error decoding reactions JSON string: $e, Value: '$reactionsData'");
          reactionsSummary = {};
        }
      } else {
        if (kDebugMode)
          print(
              "[ChatMessage.fromJson ID: $messageID] reactions string is empty or '{}'. Setting summary to empty map.");
        reactionsSummary = {};
      }
    } else if (reactionsData is List<int>) {
      // Handle []byte / JSONB case
      if (reactionsData.isNotEmpty) {
        try {
          final jsonString = utf8.decode(reactionsData);
          if (jsonString.isNotEmpty && jsonString != "{}") {
            final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;
            reactionsSummary = decodedMap.map((key, value) {
              final count = value is num ? value.toInt() : 0;
              return MapEntry(key, count);
            });
            if (kDebugMode)
              print(
                  "[ChatMessage.fromJson ID: $messageID] Parsed reactionsSummary from bytes: $reactionsSummary");
          } else {
            if (kDebugMode)
              print(
                  "[ChatMessage.fromJson ID: $messageID] reactions bytes decoded to empty or '{}'. Setting summary to empty map.");
            reactionsSummary = {};
          }
        } catch (e) {
          if (kDebugMode)
            print(
                "[ChatMessage.fromJson ID: $messageID] Error decoding reactions bytes/JSON: $e");
          reactionsSummary = {};
        }
      } else {
        if (kDebugMode)
          print(
              "[ChatMessage.fromJson ID: $messageID] reactions byte list is empty. Setting summary to empty map.");
        reactionsSummary = {};
      }
    } else {
      if (kDebugMode)
        print(
            "[ChatMessage.fromJson ID: $messageID] 'reactions' field is null or unexpected type: ${reactionsData.runtimeType}. Setting summary to empty map.");
      reactionsSummary = {}; // Default to empty map if null or other type
    }

    // Parse current_user_reaction (Use the correct key from API spec)
    final currentUserReactionData = json['current_user_reaction'];
    String? currentUserReaction;
    if (currentUserReactionData is String &&
        currentUserReactionData.isNotEmpty) {
      currentUserReaction = currentUserReactionData;
      if (kDebugMode)
        print(
            "[ChatMessage.fromJson ID: $messageID] Parsed currentUserReaction: '$currentUserReaction'");
    } else {
      if (kDebugMode && currentUserReactionData != null) {
        print(
            "[ChatMessage.fromJson ID: $messageID] currentUserReaction is present but not a valid string. Type: ${currentUserReactionData.runtimeType}, Value: $currentUserReactionData");
      } else if (kDebugMode) {
        print(
            "[ChatMessage.fromJson ID: $messageID] currentUserReaction field is missing or null.");
      }
    }
    // *** --- END: Reaction Parsing MODIFIED --- ***

    // Logging core parsed fields (Keep)
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
      status: ChatMessageStatus
          .sent, // API messages are always 'sent' status initially
      replyToMessageID: replyToMessageID,
      repliedMessageSenderID: repliedMessageSenderID,
      repliedMessageTextSnippet: repliedMessageTextSnippet,
      repliedMessageMediaType: repliedMessageMediaType,
      reactionsSummary: reactionsSummary,
      currentUserReaction: currentUserReaction,
    );
  }

  // copyWith Method (Keep as previously modified)
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
    Map<String, int>? Function()? reactionsSummary,
    String? Function()? currentUserReaction,
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
      reactionsSummary:
          reactionsSummary != null ? reactionsSummary() : this.reactionsSummary,
      currentUserReaction: currentUserReaction != null
          ? currentUserReaction()
          : this.currentUserReaction,
    );
  }
}
