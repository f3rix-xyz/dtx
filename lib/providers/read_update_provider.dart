// File: lib/providers/read_update_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a single event indicating messages have been read.
@immutable // Ensures the state object is immutable
class ReadUpdate {
  final int readerUserId; // ID of the user who read the messages
  final int lastReadMessageId; // ID of the latest message they read
  final DateTime timestamp; // Timestamp of the event

  // Constructor uses DateTime.now() to differentiate events
  ReadUpdate({
    required this.readerUserId,
    required this.lastReadMessageId,
  }) : timestamp = DateTime.now();

  // Optional: Override == and hashCode for potential comparisons
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadUpdate &&
          runtimeType == other.runtimeType &&
          readerUserId == other.readerUserId &&
          lastReadMessageId == other.lastReadMessageId &&
          timestamp == other.timestamp; // Include timestamp for uniqueness

  @override
  int get hashCode =>
      readerUserId.hashCode ^ lastReadMessageId.hashCode ^ timestamp.hashCode;

  @override
  String toString() {
    return 'ReadUpdate(readerUserId: $readerUserId, lastReadMessageId: $lastReadMessageId, timestamp: $timestamp)';
  }
}

/// Simple StateProvider to hold the *latest* read update event received.
/// ConversationNotifier will listen to this provider to update its message states.
final readUpdateProvider = StateProvider<ReadUpdate?>((ref) {
  // Initial state is null (no update received yet)
  return null;
});
