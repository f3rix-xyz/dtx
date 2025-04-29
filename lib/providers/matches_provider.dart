// File: lib/providers/matches_provider.dart
import 'dart:async';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/user_model.dart'; // Using UserModel as MatchUser
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/status_provider.dart'; // <-- IMPORT ADDED
import 'package:dtx/repositories/match_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // <-- IMPORT ADDED

// --- MatchesState remains the same ---
class MatchesState {
  final bool isLoading;
  final List<UserModel> matches;
  final AppError? error;

  const MatchesState({
    this.isLoading = false,
    this.matches = const [],
    this.error,
  });

  MatchesState copyWith({
    bool? isLoading,
    List<UserModel>? matches,
    AppError? Function()? error,
  }) {
    return MatchesState(
      isLoading: isLoading ?? this.isLoading,
      matches: matches ?? this.matches,
      error: error != null ? error() : this.error,
    );
  }
}
// --- End MatchesState ---

class MatchesNotifier extends StateNotifier<MatchesState> {
  final MatchRepository _matchRepository;
  final Ref _ref; // <-- REF ADDED
  StreamSubscription? _statusSubscription; // <-- Listener Subscription

  MatchesNotifier(this._matchRepository, this._ref) // <-- REF ADDED
      : super(const MatchesState()) {
    _listenToStatusUpdates(); // <-- Start listening on creation
  }

  // --- CORRECTED: Listen for status updates ---
  void _listenToStatusUpdates() {
    print("[MatchesNotifier] Initializing status update listener.");
    // Use ref.listen, NOT listenManual
    _ref.listen<UserStatusUpdate?>(userStatusUpdateProvider, (prev, next) {
      // Listener callback receives previous and next state
      if (next != null) {
        if (kDebugMode)
          print(
              "[MatchesNotifier Listener Callback] Received status update: UserID=${next.userId}, isOnline=${next.isOnline}");
        _updateMatchStatus(next.userId, next.isOnline);
      }
    });
  }
  // --- END CORRECTION ---

  // --- NEW: Update status in the list ---
  void _updateMatchStatus(int userId, bool isOnline) {
    if (!mounted) {
      print(
          "[MatchesNotifier _updateMatchStatus] Not mounted, ignoring update for UserID: $userId");
      return;
    }

    final currentMatches = state.matches;
    final matchIndex = currentMatches.indexWhere((match) => match.id == userId);

    if (matchIndex != -1) {
      final matchToUpdate = currentMatches[matchIndex];

      // Only update if the status has actually changed
      if (matchToUpdate.isOnline != isOnline) {
        print(
            "[MatchesNotifier _updateMatchStatus] Found match UserID: $userId at index $matchIndex. Updating status from ${matchToUpdate.isOnline} to $isOnline.");

        // Create updated user model
        // CORRECTED: Pass function for nullable lastOnline
        final updatedMatch = matchToUpdate.copyWith(
          isOnline: isOnline,
          // Pass a function returning the value for nullable fields in copyWith
          lastOnline: () => matchToUpdate.lastOnline,
        );

        // Create new list with updated model
        final updatedMatches = List<UserModel>.from(currentMatches);
        updatedMatches[matchIndex] = updatedMatch;

        // Update state
        state = state.copyWith(matches: updatedMatches);
        print(
            "[MatchesNotifier _updateMatchStatus] State updated for UserID: $userId.");
      } else {
        if (kDebugMode)
          print(
              "[MatchesNotifier _updateMatchStatus] Match UserID: $userId found, but isOnline status ($isOnline) is already the same. No state change needed.");
      }
    } else {
      if (kDebugMode)
        print(
            "[MatchesNotifier _updateMatchStatus] Received status update for UserID: $userId, but they are not in the current matches list.");
    }
  }
  // --- END NEW ---

  // --- fetchMatches remains the same ---
  Future<void> fetchMatches({bool forceRefresh = false}) async {
    if (state.isLoading) return;
    if (state.matches.isNotEmpty && !forceRefresh) return;

    print("[MatchesNotifier] Fetching matches...");
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final matches = await _matchRepository.fetchMatches();
      if (mounted) {
        state = state.copyWith(isLoading: false, matches: matches);
        print("[MatchesNotifier] Fetched ${matches.length} matches.");
      }
    } on ApiException catch (e) {
      print("[MatchesNotifier] API Exception: ${e.message}");
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: () => AppError.server(e.message),
        );
      }
    } catch (e, stacktrace) {
      print("[MatchesNotifier] Unexpected Error: $e");
      print("[MatchesNotifier] Stacktrace: $stacktrace");
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: () => AppError.generic("Failed to load matches."),
        );
      }
    }
  }

  // --- ADDED dispose ---
  // Note: We don't need to manually cancel the subscription created with ref.listen.
  // Riverpod handles the lifecycle automatically when the provider is disposed.
  // However, explicitly overriding dispose is fine for logging or other cleanup.
  @override
  void dispose() {
    print("[MatchesNotifier] Disposing.");
    // _statusSubscription?.cancel(); // Cancellation handled by Riverpod for ref.listen
    super.dispose();
  }
  // --- END ADDED ---
}

// --- UPDATED Provider Definition ---
final matchesProvider =
    StateNotifierProvider<MatchesNotifier, MatchesState>((ref) {
  final repo = ref.watch(matchRepositoryProvider);
  // Pass the ref to the notifier's constructor
  final notifier = MatchesNotifier(repo, ref);
  // The listener is now started inside the constructor.
  return notifier;
});
// --- END UPDATED ---
