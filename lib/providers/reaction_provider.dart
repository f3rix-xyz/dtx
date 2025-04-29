// File: lib/providers/reaction_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a single reaction update event received via WebSocket.
@immutable // Keep immutable annotation
class ReactionUpdate {
  final int messageId;
  final int reactorUserId;
  final String? emoji; // Null if reaction was removed
  final bool isRemoved;
  final DateTime timestamp; // To differentiate events

  // *** REMOVED const keyword from the constructor ***
  ReactionUpdate({
    required this.messageId,
    required this.reactorUserId,
    this.emoji,
    required this.isRemoved,
  }) : timestamp = DateTime.now(); // Use current time for the event

  // Optional: Override == and hashCode if needed
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReactionUpdate &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId &&
          reactorUserId == other.reactorUserId &&
          emoji == other.emoji &&
          isRemoved == other.isRemoved &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      messageId.hashCode ^
      reactorUserId.hashCode ^
      emoji.hashCode ^
      isRemoved.hashCode ^
      timestamp.hashCode;

  @override
  String toString() {
    return 'ReactionUpdate(messageId: $messageId, reactorUserId: $reactorUserId, emoji: $emoji, isRemoved: $isRemoved, timestamp: $timestamp)';
  }
}

/// Simple StateProvider to hold the *latest* reaction update received.
/// ConversationNotifier will listen to this provider.
final reactionUpdateProvider = StateProvider<ReactionUpdate?>((ref) {
  // Initial state is null (no update received yet)
  return null;
});
