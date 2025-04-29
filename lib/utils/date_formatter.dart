// File: lib/utils/date_formatter.dart
import 'package:intl/intl.dart'; // Add intl package to pubspec.yaml if not already there
import 'package:flutter/foundation.dart';

String formatLastSeen(DateTime? lastSeen, {bool short = false}) {
  final methodName = 'formatLastSeen';
  if (lastSeen == null) {
    if (kDebugMode) print("[$methodName] Input DateTime is null.");
    return short ? '' : 'Last seen: unavailable';
  }

  final now = DateTime.now();
  final difference = now.difference(lastSeen);

  if (kDebugMode)
    print(
        "[$methodName] Formatting: Now=$now, LastSeen=$lastSeen, Diff=$difference");

  if (difference.inSeconds < 60) {
    return short ? 'just now' : 'Last seen: just now';
  } else if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return short
        ? '${minutes}m ago'
        : 'Last seen: $minutes minute${minutes > 1 ? 's' : ''} ago';
  } else if (difference.inHours < 24 && now.day == lastSeen.day) {
    final hours = difference.inHours;
    return short
        ? '${hours}h ago'
        : 'Last seen: $hours hour${hours > 1 ? 's' : ''} ago';
  } else if (difference.inDays == 1 ||
      (difference.inHours < 48 && now.day == lastSeen.day + 1)) {
    return short ? 'Yesterday' : 'Last seen: Yesterday';
  } else if (difference.inDays < 7) {
    // Within the last week, show day name
    final formatter = DateFormat('EEEE'); // e.g., 'Monday'
    final dayName = formatter.format(lastSeen);
    return short ? dayName : 'Last seen: $dayName';
  } else {
    // Older than a week, show date
    final formatter = DateFormat('MMM d, yyyy'); // e.g., 'Apr 29, 2025'
    final dateStr = formatter.format(lastSeen);
    return short ? dateStr : 'Last seen: $dateStr';
  }
}
