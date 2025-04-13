// File: views/who_liked_you_screen.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/recieved_likes_provider.dart';
import 'package:dtx/views/liker_profile_screen.dart'; // Import Liker Profile Screen
import 'package:dtx/widgets/basic_liker_profile_card.dart';
import 'package:dtx/widgets/full_liker_profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class WhoLikedYouScreen extends ConsumerStatefulWidget {
  const WhoLikedYouScreen({super.key});

  @override
  ConsumerState<WhoLikedYouScreen> createState() => _WhoLikedYouScreenState();
}

class _WhoLikedYouScreenState extends ConsumerState<WhoLikedYouScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch likes when the screen initializes
    // Use addPostFrameCallback to avoid calling during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("[WhoLikedYouScreen] Initial fetch triggered.");
      ref.read(receivedLikesProvider.notifier).fetchLikes();
    });
  }

  // Function to handle tapping on a liker card
  void _navigateToLikerProfile(int likerUserId) {
    print(
        "[WhoLikedYouScreen] Navigating to profile for liker ID: $likerUserId");
    // Clear any previous error before navigating
    ref.read(errorProvider.notifier).clearError();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LikerProfileScreen(likerUserId: likerUserId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receivedLikesProvider);
    final error = ref.watch(errorProvider); // Watch general errors too

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      appBar: AppBar(
        title: Text(
          "Likes You've Received",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black, // Back button color
      ),
      body: RefreshIndicator(
        color: const Color(0xFF8B5CF6), // Themed refresh indicator
        onRefresh: () => ref.read(receivedLikesProvider.notifier).fetchLikes(),
        child: _buildBody(state, error),
      ),
    );
  }

  Widget _buildBody(ReceivedLikesState state, AppError? generalError) {
    if (state.isLoading &&
        state.fullProfiles.isEmpty &&
        state.otherLikers.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    // Display provider-specific error first
    if (state.error != null) {
      return _buildErrorState(state.error!.message);
    }
    // Display general error if provider error is null
    if (generalError != null) {
      return _buildErrorState(generalError.message);
    }

    if (state.fullProfiles.isEmpty && state.otherLikers.isEmpty) {
      return _buildEmptyState();
    }

    // Use CustomScrollView for combining different list types
    return CustomScrollView(
      slivers: [
        // Section Header for Full Profiles
        if (state.fullProfiles.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                "Recent Likes & Roses", // Or just "Likes"
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),

        // Grid for Full Profiles
        if (state.fullProfiles.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Two columns
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75, // Adjust aspect ratio as needed
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final liker = state.fullProfiles[index];
                  return FullLikerProfileCard(
                    liker: liker,
                    onTap: () => _navigateToLikerProfile(liker.likerUserId),
                  );
                },
                childCount: state.fullProfiles.length,
              ),
            ),
          ),

        // Section Header for Other Likers
        if (state.otherLikers.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16,
                  state.fullProfiles.isNotEmpty ? 24 : 20,
                  16,
                  12), // Adjust top padding
              child: Text(
                state.fullProfiles.isNotEmpty
                    ? "Older Likes"
                    : "Likes", // Adjust title
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),

        // List for Other Likers
        if (state.otherLikers.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Add padding
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final liker = state.otherLikers[index];
                  return Padding(
                    padding: const EdgeInsets.only(
                        bottom: 10.0), // Spacing between basic cards
                    child: BasicLikerProfileCard(
                      liker: liker,
                      onTap: () => _navigateToLikerProfile(liker.likerUserId),
                    ),
                  );
                },
                childCount: state.otherLikers.length,
              ),
            ),
          ),
        // Add some bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded,
                size: 70, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              "No Likes Yet",
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            Text(
              "Keep swiping! Someone is bound to like you soon.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 60, color: Colors.redAccent[100]),
            const SizedBox(height: 20),
            Text(
              "Oops!",
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              onPressed: () =>
                  ref.read(receivedLikesProvider.notifier).fetchLikes(),
            ),
          ],
        ),
      ),
    );
  }
}
