// File: lib/providers/status_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a single user status update event.
@immutable // Ensures the state object is immutable
class UserStatusUpdate {
  final int userId;
  final bool isOnline;
  final DateTime timestamp; // To differentiate events

  const UserStatusUpdate({
    required this.userId,
    required this.isOnline,
    required this.timestamp,
  });

  // Optional: Override == and hashCode if needed for complex comparisons,
  // but timestamp usually suffices for differentiation.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserStatusUpdate &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          isOnline == other.isOnline &&
          timestamp == other.timestamp;

  @override
  int get hashCode => userId.hashCode ^ isOnline.hashCode ^ timestamp.hashCode;

  @override
  String toString() {
    return 'UserStatusUpdate(userId: $userId, isOnline: $isOnline, timestamp: $timestamp)';
  }
}

// --- StateNotifier ---
class UserStatusNotifier extends StateNotifier<UserStatusUpdate?> {
  // Initialize with null state, meaning no update has occurred yet.
  UserStatusNotifier() : super(null);

  /// Updates the state with the latest status change.
  void updateStatus(int userId, bool isOnline) {
    final newStatus = UserStatusUpdate(
      userId: userId,
      isOnline: isOnline,
      timestamp: DateTime.now(), // Use current time for the event
    );
    if (kDebugMode) {
      print("[UserStatusNotifier] Broadcasting status update: $newStatus");
    }
    // Only update if it's different from the last state to avoid unnecessary rebuilds
    // (though timestamp makes it always different, good practice)
    if (state != newStatus) {
      state = newStatus;
    }
  }
}

// --- StateNotifierProvider ---
/// Provider that broadcasts the latest user status update event received via WebSocket.
/// Other providers (like MatchesNotifier, ConversationNotifier) can watch this
/// to react to real-time status changes.
final userStatusUpdateProvider =
    StateNotifierProvider<UserStatusNotifier, UserStatusUpdate?>((ref) {
  return UserStatusNotifier();
});
