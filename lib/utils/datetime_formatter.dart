// File: lib/utils/date_formatter.dart
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class DateFormatter {
  // Static function to format the last seen timestamp
  static String formatLastSeen(DateTime? lastSeenUtc) {
    if (kDebugMode) {
      print("[DateFormatter formatLastSeen] Input (UTC?): $lastSeenUtc");
    }
    if (lastSeenUtc == null) {
      if (kDebugMode) {
        print("[DateFormatter formatLastSeen] Input is null, returning empty.");
      }
      return ""; // Return empty or maybe "Last seen: unavailable"
    }

    // Ensure we are comparing local times
    final DateTime lastSeenLocal = lastSeenUtc.toLocal();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(lastSeenLocal);

    if (kDebugMode) {
      print(
          "[DateFormatter formatLastSeen] Last Seen Local: $lastSeenLocal, Now: $now, Difference: ${difference.inMinutes} mins");
    }

    if (difference.isNegative) {
      // Timestamp is in the future? Should not happen, maybe due to clock skew.
      // Return a safe default.
      if (kDebugMode) {
        print(
            "[DateFormatter formatLastSeen] WARNING: Timestamp is in the future!");
      }
      return "Last seen: ${DateFormat.yMd().add_jm().format(lastSeenLocal)}";
    }

    if (difference.inSeconds < 60) {
      return "Last seen: just now";
    } else if (difference.inMinutes < 60) {
      return "Last seen: ${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      // Check if it was today but more than an hour ago
      if (lastSeenLocal.year == now.year &&
          lastSeenLocal.month == now.month &&
          lastSeenLocal.day == now.day) {
        return "Last seen: ${difference.inHours}h ago";
      } else {
        // If it crossed midnight but is less than 24 hours ago, show 'Yesterday'
        return "Last seen: Yesterday at ${DateFormat.jm().format(lastSeenLocal)}";
      }
    } else if (difference.inDays == 1 ||
        (difference.inHours < 48 &&
            (now.day - lastSeenLocal.day == 1 ||
                (now.day == 1 && lastSeenLocal.day >= 28)))) {
      // Handle 'Yesterday' specifically, accounting for day changes
      return "Last seen: Yesterday at ${DateFormat.jm().format(lastSeenLocal)}";
    } else if (difference.inDays < 7) {
      // Within the last week, show day name
      return "Last seen: ${DateFormat('EEEE').format(lastSeenLocal)} at ${DateFormat.jm().format(lastSeenLocal)}";
    } else {
      // Older than a week, show date
      return "Last seen: ${DateFormat.yMd().format(lastSeenLocal)}";
    }
  }

  // --- Keep your existing formatChatMessageTimestamp if you have it ---
  static String formatChatMessageTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final localTimestamp = timestamp.toLocal();

    if (now.year == localTimestamp.year &&
        now.month == localTimestamp.month &&
        now.day == localTimestamp.day) {
      // Today: Show time only
      return DateFormat.jm().format(localTimestamp);
    } else if (now.year == localTimestamp.year &&
        now.month == localTimestamp.month &&
        now.day - localTimestamp.day == 1) {
      // Yesterday: Show "Yesterday"
      return "Yesterday";
    } else if (now.difference(localTimestamp).inDays < 7) {
      // Within the last week: Show day name (e.g., "Tuesday")
      return DateFormat('EEEE').format(localTimestamp);
    } else {
      // Older than a week: Show date (e.g., "4/15/2024")
      return DateFormat.yMd().format(localTimestamp);
    }
  }
}
