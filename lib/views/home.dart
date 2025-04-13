// File: lib/views/home.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/name.dart';
import 'package:dtx/views/profile_screens.dart';
import 'package:dtx/views/who_liked_you_screen.dart';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/models/feed_models.dart';
import 'package:dtx/widgets/quick_profile_card.dart';
import 'package:dtx/widgets/home_profile_card.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/repositories/like_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final FeedType initialFeedType;
  const HomeScreen({super.key, required this.initialFeedType});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late FeedType _currentFeedType;
  bool _isLoadingFeed = true;
  List<UserModel> _homeFeedProfiles = [];
  List<QuickFeedProfile> _quickFeedProfiles = [];
  bool _isInteracting = false;

  // Removed PageController

  @override
  void initState() {
    super.initState();
    _currentFeedType = widget.initialFeedType;
    print("[HomeScreen initState] Initial Feed Type: $_currentFeedType");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFeed();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchFeed() async {
    print("[HomeScreen _fetchFeed] Fetching feed for type: $_currentFeedType");
    if (!mounted) return;
    setState(() {
      _isLoadingFeed = true;
      _homeFeedProfiles = [];
      _quickFeedProfiles = [];
      _isInteracting = false;
    });
    ref.read(errorProvider.notifier).clearError();
    try {
      final repo = ref.read(userRepositoryProvider);
      if (_currentFeedType == FeedType.quick) {
        final profiles = await repo.fetchQuickFeed();
        if (!mounted) return;
        setState(() {
          _quickFeedProfiles = profiles;
          _isLoadingFeed = false;
        });
      } else {
        final profiles = await repo.fetchHomeFeed();
        if (!mounted) return;
        setState(() {
          _homeFeedProfiles = profiles;
          _isLoadingFeed = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingFeed = false);
      ref.read(errorProvider.notifier).setError(AppError.server(e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingFeed = false);
      ref
          .read(errorProvider.notifier)
          .setError(AppError.generic("Failed to load feed."));
    }
  }

  void _removeTopCard() {
    print("[HomeScreen _removeTopCard] Removing top card.");
    if (!mounted) return;
    setState(() {
      if (_currentFeedType == FeedType.home && _homeFeedProfiles.isNotEmpty) {
        _homeFeedProfiles.removeAt(0);
      } else if (_currentFeedType == FeedType.quick &&
          _quickFeedProfiles.isNotEmpty) {
        _quickFeedProfiles.removeAt(0);
      }
      _isInteracting = false;
    });
    _checkAndFetchMoreProfilesIfNeeded();
  }

  void _checkAndFetchMoreProfilesIfNeeded() {
    if (_currentFeedType == FeedType.home &&
        !_isLoadingFeed &&
        _homeFeedProfiles.length < 3) {
      _fetchFeed();
    }
  }

  Future<void> _handleDislikeButtonPressed() async {
    print("[HomeScreen _handleDislikeButtonPressed] Dislike button tapped.");
    if (_currentFeedType == FeedType.quick) {
      _showCompleteProfileDialog();
      return;
    }
    if (_homeFeedProfiles.isEmpty || _isInteracting) {
      return;
    }
    final targetProfile = _homeFeedProfiles[0];
    if (targetProfile.id == null) {
      return;
    }
    await _performDislike(targetProfile.id!);
  }

  Future<void> _performLike(
      int targetUserId,
      ContentLikeType contentType,
      String contentIdentifier,
      String? comment,
      LikeInteractionType interactionType) async {
    if (_isInteracting) return;
    setState(() => _isInteracting = true);
    final errorNotifier = ref.read(errorProvider.notifier)..clearError();
    bool success = false;
    try {
      final likeRepo = ref.read(likeRepositoryProvider);
      success = await likeRepo.likeContent(
          likedUserId: targetUserId,
          contentType: contentType,
          contentIdentifier: contentIdentifier,
          interactionType: interactionType,
          comment: comment);
      if (success) {
        _removeTopCard();
      } else {
        if (ref.read(errorProvider) == null)
          errorNotifier.setError(
              AppError.server("Could not send ${interactionType.value}."));
        if (mounted) setState(() => _isInteracting = false);
      }
    } on LikeLimitExceededException catch (e) {
      errorNotifier.setError(AppError.validation(e.message));
      _showErrorSnackbar(e.message);
      if (mounted) setState(() => _isInteracting = false);
    } on InsufficientRosesException catch (e) {
      errorNotifier.setError(AppError.validation(e.message));
      _showErrorSnackbar(e.message);
      if (mounted) setState(() => _isInteracting = false);
    } on ApiException catch (e) {
      errorNotifier.setError(AppError.server(e.message));
      if (mounted) setState(() => _isInteracting = false);
    } catch (e) {
      errorNotifier.setError(AppError.generic("An unexpected error occurred."));
      if (mounted) setState(() => _isInteracting = false);
    }
  }

  Future<void> _performSendRose(int targetUserId, String? comment) async {
    await _performLike(targetUserId, ContentLikeType.media, "0", comment,
        LikeInteractionType.rose);
  }

  Future<void> _performDislike(int targetUserId) async {
    if (_isInteracting) return;
    setState(() => _isInteracting = true);
    final errorNotifier = ref.read(errorProvider.notifier)..clearError();
    bool success = false;
    try {
      final likeRepo = ref.read(likeRepositoryProvider);
      success = await likeRepo.dislikeUser(dislikedUserId: targetUserId);
      if (success) {
        _removeTopCard();
      } else {
        if (ref.read(errorProvider) == null)
          errorNotifier.setError(AppError.server("Could not dislike profile."));
        if (mounted) setState(() => _isInteracting = false);
      }
    } on ApiException catch (e) {
      errorNotifier.setError(AppError.server(e.message));
      if (mounted) setState(() => _isInteracting = false);
    } catch (e) {
      errorNotifier.setError(AppError.generic("An unexpected error occurred."));
      if (mounted) setState(() => _isInteracting = false);
    }
  }

  // UI Helper Methods
  void _showCompleteProfileDialog() {/* ... same ... */}
  void _showErrorSnackbar(String message) {/* ... same ... */}
  void _navigateToProfile() {/* ... same ... */}
  void _navigateToLikes() {/* ... same ... */}

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(errorProvider);
    final profilesAvailable = _currentFeedType == FeedType.home
        ? _homeFeedProfiles
        : _quickFeedProfiles;
    final bool hasProfilesToShow = profilesAvailable.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white, // White screen background
      body: SafeArea(
        child: Stack(
          // Stack for overlay button
          children: [
            Column(
              children: [
                // Top Bar
                Container(
                  /* ... Top Bar ... */
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        bottom:
                            BorderSide(color: Colors.grey[200]!, width: 1.0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Peeple",
                          style: GoogleFonts.pacifico(
                              fontSize: 24,
                              color: const Color(0xFF8B5CF6),
                              fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          _buildTopBarIcon(Icons.person_outline_rounded,
                              "Profile", _navigateToProfile),
                          const SizedBox(width: 16),
                          _buildTopBarIcon(Icons.favorite_border_rounded,
                              "Likes", _navigateToLikes),
                        ],
                      ),
                    ],
                  ),
                ),

                // Feed Area - Displays only the top card
                Expanded(
                  child: _isLoadingFeed
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF8B5CF6)))
                      : error != null
                          ? _buildErrorState(error)
                          : !hasProfilesToShow
                              ? _buildEmptyState()
                              : Stack(
                                  // Stack for loading indicator
                                  children: [
                                    // Display only the first profile
                                    if (profilesAvailable.isNotEmpty)
                                      _buildProfileCardAtIndex(0),

                                    // Interaction Loader Overlay
                                    if (_isInteracting)
                                      Positioned.fill(
                                          child: Container(
                                        color: Colors.white.withOpacity(0.5),
                                        child: const Center(
                                            child: CircularProgressIndicator(
                                                color: Color(0xFF8B5CF6))),
                                      )),
                                  ],
                                ),
                ),
              ],
            ),

            // Overlay Dislike Button
            if (!_isLoadingFeed && hasProfilesToShow)
              Positioned(
                bottom: 20,
                left: 20,
                child: _buildActionButton(
                    // Dislike button
                    Icons.close,
                    Colors.red.shade400,
                    _isInteracting ? null : _handleDislikeButtonPressed),
              ),
          ],
        ),
      ),
    );
  }

  // _buildProfileCardAtIndex logic remains the same
  Widget _buildProfileCardAtIndex(int indexInList) {
    if (_currentFeedType == FeedType.quick) {
      if (indexInList >= 0 && indexInList < _quickFeedProfiles.length) {
        return QuickProfileCard(profile: _quickFeedProfiles[indexInList]);
      }
    } else {
      if (indexInList >= 0 && indexInList < _homeFeedProfiles.length) {
        final currentProfile = _homeFeedProfiles[indexInList];
        return HomeProfileCard(
          profile: currentProfile,
          onLikeContent: (type, identifier, comment) {
            if (currentProfile.id == null) return;
            _performLike(currentProfile.id!, type, identifier, comment,
                LikeInteractionType.standard);
          },
          onSendRose: (comment) {
            if (currentProfile.id == null) return;
            _performSendRose(currentProfile.id!, comment);
          },
        );
      }
    }
    return Container(
        alignment: Alignment.center,
        child: const Text("Error loading profile."));
  }

  // Helper Widgets (_buildTopBarIcon, _buildActionButton, _buildEmptyState, _buildErrorState)
  Widget _buildTopBarIcon(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF8B5CF6), size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
        splashRadius: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, Color color, VoidCallback? onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
          border: onPressed == null
              ? Border.all(color: Colors.grey.shade300, width: 1.5)
              : null,
        ),
        child: Icon(icon,
            color: onPressed == null ? Colors.grey.shade400 : color, size: 35),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            "That's everyone for now!",
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          Text(
            _currentFeedType == FeedType.quick
                ? "Complete your profile to see more!"
                : "Check back later for new profiles.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Refresh Feed"),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: _fetchFeed,
          ),
          if (_currentFeedType == FeedType.quick) ...[
            const SizedBox(height: 15),
            OutlinedButton(
              child: const Text("Complete Profile"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NameInputScreen()),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(AppError error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 60, color: Colors.redAccent[100]),
            const SizedBox(height: 20),
            Text(
              "Oops! Something went wrong",
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              error.message,
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
              onPressed: _fetchFeed,
            ),
          ],
        ),
      ),
    );
  }
}
