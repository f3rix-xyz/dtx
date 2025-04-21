// lib/providers/matches_provider.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/user_model.dart'; // Using UserModel as MatchUser
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/repositories/match_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MatchesState {
  final bool isLoading;
  final List<UserModel> matches; // Use UserModel
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

class MatchesNotifier extends StateNotifier<MatchesState> {
  final MatchRepository _matchRepository;

  MatchesNotifier(this._matchRepository) : super(const MatchesState());

  Future<void> fetchMatches({bool forceRefresh = false}) async {
    if (state.isLoading) return;
    if (state.matches.isNotEmpty && !forceRefresh)
      return; // Don't refetch if already loaded unless forced

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
    } catch (e) {
      print("[MatchesNotifier] Unexpected Error: ${e.toString()}");
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: () => AppError.generic("Failed to load matches."),
        );
      }
    }
  }
}

final matchesProvider =
    StateNotifierProvider<MatchesNotifier, MatchesState>((ref) {
  final repo = ref.watch(matchRepositoryProvider);
  return MatchesNotifier(repo);
});
