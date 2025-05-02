// File: lib/views/who_liked_you_screen.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/recieved_likes_provider.dart';
import 'package:dtx/views/liker_profile_screen.dart'; // Import LikerProfileScreen
import 'package:dtx/widgets/basic_liker_profile_card.dart';
import 'package:dtx/widgets/full_liker_profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class WhoLikedYouScreen extends ConsumerStatefulWidget {
  const WhoLikedYouScreen({super.key});

  @override
  ConsumerState<WhoLikedYouScreen> createState() => _WhoLikedYouScreenState();
}

class _WhoLikedYouScreenState extends ConsumerState<WhoLikedYouScreen> {
  @override
  void initState() {
    super.initState();
    // Fetching is initiated in MainNavigationScreen initState now
  }

  // *** MODIFIED: _navigateToLikerProfile - Now accepts likeId ***
  void _navigateToLikerProfile(int likerUserId, int likeId) {
    if (kDebugMode) {
      print(
          "[WhoLikedYouScreen] Navigating to profile for liker ID: $likerUserId, Like ID: $likeId");
    }
    if (likeId <= 0) {
      if (kDebugMode) {
        print(
            "[WhoLikedYouScreen] ERROR: Invalid Like ID ($likeId) passed for navigation. Cannot log analytic event.");
      }
      // Optionally show a snackbar or just proceed without logging
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: Invalid like data.")));
      // return; // Or decide to navigate anyway without the analytic call? Let's navigate.
    }
    ref.read(errorProvider.notifier).clearError();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LikerProfileScreen(
          likerUserId: likerUserId,
          likeId: likeId, // <<<--- PASS likeId
        ),
      ),
    );
  }
  // *** END MODIFICATION ***

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receivedLikesProvider);
    final generalError = ref.watch(errorProvider);
    final displayError = state.error ?? generalError;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Likes You've Received",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        color: const Color(0xFF8B5CF6),
        onRefresh: () async {
          ref.read(errorProvider.notifier).clearError();
          await ref.read(receivedLikesProvider.notifier).fetchLikes();
        },
        child: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
            : _buildBody(state, displayError),
      ),
    );
  }

  Widget _buildBody(ReceivedLikesState state, AppError? error) {
    if (error != null) {
      return _buildErrorState(error.message);
    }

    if (state.fullProfiles.isEmpty && state.otherLikers.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      slivers: [
        if (state.fullProfiles.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                "Recent Likes & Roses",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
        if (state.fullProfiles.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final liker = state.fullProfiles[index];
                  // *** PASS liker.likeId ***
                  return FullLikerProfileCard(
                    liker: liker,
                    onTap: () => _navigateToLikerProfile(
                        liker.likerUserId, liker.likeId),
                  );
                  // *** END PASS ***
                },
                childCount: state.fullProfiles.length,
              ),
            ),
          ),
        if (state.otherLikers.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, state.fullProfiles.isNotEmpty ? 24 : 20, 16, 12),
              child: Text(
                state.fullProfiles.isNotEmpty ? "Older Likes" : "Likes",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
        if (state.otherLikers.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final liker = state.otherLikers[index];
                  // *** PASS liker.likeId ***
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: BasicLikerProfileCard(
                      liker: liker,
                      onTap: () => _navigateToLikerProfile(
                          liker.likerUserId, liker.likeId),
                    ),
                  );
                  // *** END PASS ***
                },
                childCount: state.otherLikers.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  // No changes needed for _buildEmptyState or _buildErrorState
  Widget _buildEmptyState() {
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
                  Icon(Icons.favorite_border_rounded,
                      size: 70, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  Text("No Likes Yet",
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700])),
                  const SizedBox(height: 10),
                  Text("People who like you will appear here.",
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

  Widget _buildErrorState(String message) {
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
                  Text("Oops!",
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700])),
                  const SizedBox(height: 10),
                  Text(message,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center),
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
                    onPressed: () =>
                        ref.read(receivedLikesProvider.notifier).fetchLikes(),
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
