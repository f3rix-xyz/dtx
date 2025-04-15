import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/recieved_likes_provider.dart';
import 'package:dtx/views/liker_profile_screen.dart';
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
    // Fetching is now initiated in MainNavigationScreen initState
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   print("[WhoLikedYouScreen] Initial fetch triggered.");
    //   ref.read(receivedLikesProvider.notifier).fetchLikes();
    // });
  }

  void _navigateToLikerProfile(int likerUserId) {
    print(
        "[WhoLikedYouScreen] Navigating to profile for liker ID: $likerUserId");
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
    // Watch general errors *as well*, but prioritize state.error
    final generalError = ref.watch(errorProvider);
    final displayError = state.error ?? generalError;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Likes You've Received",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false, // No back button in a tab screen
      ),
      body: RefreshIndicator(
        color: const Color(0xFF8B5CF6),
        onRefresh: () => ref.read(receivedLikesProvider.notifier).fetchLikes(),
        // Add Loading Check Here
        child: state.isLoading &&
                state.fullProfiles.isEmpty &&
                state.otherLikers.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
            : _buildBody(state, displayError), // Pass combined error
      ),
    );
  }

  Widget _buildBody(ReceivedLikesState state, AppError? error) {
    // Loading is handled before calling _buildBody now

    if (error != null) {
      return _buildErrorState(error.message);
    }

    if (state.fullProfiles.isEmpty && state.otherLikers.isEmpty) {
      return _buildEmptyState();
    }

    // CustomScrollView remains the same
    return CustomScrollView(
      slivers: [
        // Section Header for Full Profiles
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

        // Grid for Full Profiles
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

        // List for Other Likers
        if (state.otherLikers.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final liker = state.otherLikers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
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
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  // _buildEmptyState and _buildErrorState remain the same
  Widget _buildEmptyState() {
    return LayoutBuilder(
      // Use LayoutBuilder to ensure Center takes full space for scrollable refresh
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
      // Use LayoutBuilder for scrollable refresh
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
