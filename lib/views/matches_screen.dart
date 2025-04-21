// lib/views/matches_screen.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/user_model.dart'; // Using UserModel as MatchUser
import 'package:dtx/providers/matches_provider.dart';
import 'package:dtx/views/chat_detail_screen.dart'; // Import ChatDetailScreen
import 'package:dtx/widgets/match_list_tile.dart'; // Import MatchListTile
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch matches when the screen loads if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(matchesProvider);
      if (state.matches.isEmpty && !state.isLoading) {
        print("[MatchesScreen] Initial fetch trigger."); // Log fetch trigger
        ref.read(matchesProvider.notifier).fetchMatches();
      }
    });
  }

  Future<void> _refreshMatches() async {
    print("[MatchesScreen] Refreshing matches."); // Log refresh action
    await ref.read(matchesProvider.notifier).fetchMatches(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchesProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Matches & Chats',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        automaticallyImplyLeading: false, // No back button in a tab screen
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMatches,
        color: const Color(0xFF8B5CF6),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(MatchesState state) {
    if (state.isLoading && state.matches.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    if (state.error != null && state.matches.isEmpty) {
      return _buildErrorState(state.error!);
    }

    if (state.matches.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: state.matches.length,
      itemBuilder: (context, index) {
        final match = state.matches[index];
        return MatchListTile(
          matchUser: match,
          onTap: () {
            // *** ADD LOGGING HERE ***
            print(
                "[MatchesScreen onTap] Attempting to navigate to chat for match. User ID: ${match.id}, Name: ${match.name}, Avatar: ${match.firstMediaUrl}");
            // *** END LOGGING ***

            if (match.id == null || match.id == 0) {
              // Added check for 0 ID as well
              print(
                  "[MatchesScreen onTap] ERROR: Invalid User ID detected (${match.id}). Cannot navigate.");
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Cannot open chat: Invalid user ID.")));
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(
                  matchUserId: match.id!,
                  matchName: match.name ??
                      'Match', // Default to 'Match' if name is still null after parsing
                  matchAvatarUrl: match.firstMediaUrl,
                ),
              ),
            );
          },
        );
      },
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        indent: 80, // Indent divider to align past avatar
        color: Colors.grey[200],
      ),
    );
  }

  Widget _buildEmptyState() {
    // (Keep previous implementation)
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 70, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  Text("No Matches Yet",
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700])),
                  const SizedBox(height: 10),
                  Text("Start liking profiles to find your matches!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 15, color: Colors.grey[500])),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(AppError error) {
    // (Keep previous implementation)
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 60, color: Colors.redAccent[100]),
                  const SizedBox(height: 20),
                  Text(
                    "Oops! Couldn't load matches",
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    error.message,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text("Retry"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
                    ),
                    onPressed: _refreshMatches,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
