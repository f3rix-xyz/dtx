import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/auth_provider.dart'; // Import AuthProvider
import 'package:dtx/models/auth_model.dart'; // Import AuthStatus
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/feed_provider.dart'; // Import FeedProvider
import 'package:dtx/providers/filter_provider.dart'; // Import FilterProvider
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/services/api_service.dart';
// Removed FeedType import
import 'package:dtx/views/filter_settings_dialog.dart'; // Import Filter Dialog
import 'package:dtx/views/name.dart'; // Keep NameInputScreen for profile completion
// Removed ProfileScreen import (handled by bottom nav)
// Removed WhoLikedYouScreen import (handled by bottom nav)
import 'package:dtx/models/user_model.dart';
// Removed FeedModels import (using UserModel directly)
// Removed QuickProfileCard import
import 'package:dtx/widgets/home_profile_card.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/repositories/like_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/models/filter_model.dart'; // Import FilterModel

class HomeScreen extends ConsumerStatefulWidget {
  // Removed initialFeedType parameter
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Removed _currentFeedType, _quickFeedProfiles
  List<UserModel> _feedProfiles = []; // Now always UserModel
  bool _isInteracting = false;
  // Removed PageController

  @override
  void initState() {
    super.initState();
    // Fetching is now initiated earlier (Splash/Auth/Gender screens)
    // We might still want to fetch here if the feed provider state is empty initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feedState = ref.read(feedProvider);
      if (!feedState.hasFetchedOnce && !feedState.isLoading) {
        print("[HomeScreen initState] Feed not fetched yet, triggering fetch.");
        _fetchFeed();
      } else {
        // If already fetched, update local state from provider
        setState(() {
          _feedProfiles = feedState.profiles;
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchFeed({bool force = false}) async {
    print("[HomeScreen _fetchFeed] Fetching home feed. Force: $force");
    // No need to set loading here, provider handles it
    // setState(() { _isInteracting = false; }); // Reset interaction lock on fetch
    ref.read(errorProvider.notifier).clearError();
    await ref.read(feedProvider.notifier).fetchFeed(forceRefresh: force);
    // Update local state after fetch completes (listener below handles this better)
  }

  // Show dialog prompting user to complete profile
  void _showCompleteProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must choose an action
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Complete Your Profile",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text(
            "To interact with profiles, please complete your profile setup.",
            style: GoogleFonts.poppins(),
          ),
          actions: <Widget>[
            TextButton(
              child:
                  Text("Later", style: GoogleFonts.poppins(color: Colors.grey)),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Just close dialog
              },
            ),
            TextButton(
              child: Text("Complete Profile",
                  style: GoogleFonts.poppins(color: Color(0xFF8B5CF6))),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
                // Navigate to the first onboarding screen (e.g., Name)
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NameInputScreen()));
              },
            ),
          ],
        );
      },
    );
  }

  void _removeTopCard() {
    print("[HomeScreen _removeTopCard] Removing top card.");
    if (!mounted) return;
    // Use the feed provider's remove method
    if (_feedProfiles.isNotEmpty) {
      ref.read(feedProvider.notifier).removeProfile(_feedProfiles[0].id!);
    }
    // No need for setState here, UI will rebuild via provider watch
    _isInteracting = false; // Reset interaction lock
    // Check and fetch is now handled within the provider's removeProfile method
  }

  Future<void> _handleLikeInteraction(
      {required int targetUserId,
      required ContentLikeType contentType,
      required String contentIdentifier,
      required LikeInteractionType interactionType,
      String? comment}) async {
    // Check auth status before proceeding
    final authStatus = ref.read(authProvider).authStatus;
    if (authStatus == AuthStatus.onboarding2) {
      print(
          "[HomeScreen] Interaction blocked: Profile incomplete (onboarding2).");
      _showCompleteProfileDialog();
      return;
    }

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

  Future<void> _performDislike(int targetUserId) async {
    // Check auth status before proceeding
    final authStatus = ref.read(authProvider).authStatus;
    if (authStatus == AuthStatus.onboarding2) {
      print(
          "[HomeScreen] Interaction blocked: Profile incomplete (onboarding2).");
      _showCompleteProfileDialog();
      return;
    }

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

  Future<void> _handleDislikeButtonPressed() async {
    print("[HomeScreen _handleDislikeButtonPressed] Dislike button tapped.");
    // Quick feed check removed
    if (_feedProfiles.isEmpty || _isInteracting) {
      return;
    }
    final targetProfile = _feedProfiles[0];
    if (targetProfile.id == null) {
      return;
    }
    await _performDislike(targetProfile.id!);
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins())),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the feed provider state
    final feedState = ref.watch(feedProvider);
    final filters = ref.watch(filterProvider); // Watch filters for display

    // Update local state when provider changes
    _feedProfiles = feedState.profiles;

    final error = feedState.error ??
        ref.watch(errorProvider); // Combine feed error and global error
    final isLoadingFeed = feedState.isLoading &&
        !feedState.hasFetchedOnce; // Only show initial load indicator
    final bool hasProfilesToShow = _feedProfiles.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50], // Lighter background for feed area
      appBar: AppBar(
        title: Text("Discover",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        automaticallyImplyLeading: false, // Remove back button if it appears
        actions: [
          // Filter Button
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF8B5CF6)),
            tooltip: "Filters",
            onPressed: () async {
              final filtersChanged = await showDialog<bool>(
                context: context,
                builder: (context) => const FilterSettingsDialog(),
              );
              // If dialog indicated filters were applied, refresh feed (already handled in dialog)
              // if (filtersChanged == true) {
              //   _fetchFeed(force: true);
              // }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            color: Colors.white, // Match AppBar background
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildFilterChips(filters),
              ),
            ),
          ),

          // Feed Area
          Expanded(
            child: Stack(
              // Stack for loading/empty/error states over content
              children: [
                // Main content area (profile card)
                if (hasProfilesToShow)
                  _buildProfileCardAtIndex(0), // Always show the first profile

                // Loading Indicator (Initial Load)
                if (isLoadingFeed)
                  const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF8B5CF6))),

                // Error State
                if (!isLoadingFeed &&
                    error != null &&
                    !hasProfilesToShow) // Show error only if no profiles
                  _buildErrorState(error),

                // Empty State
                if (!isLoadingFeed && error == null && !hasProfilesToShow)
                  _buildEmptyState(),

                // Interaction Loader Overlay (when liking/disliking)
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

          // Bottom Action Buttons (Dislike/Like) - Only show if profiles exist and not loading initially
          if (!isLoadingFeed && hasProfilesToShow)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.close_rounded, Colors.red.shade400,
                      _isInteracting ? null : _handleDislikeButtonPressed),
                  _buildActionButton(
                      Icons.favorite_rounded, // Use filled heart for like
                      Colors.pink.shade300, // Pink color for like
                      _isInteracting
                          ? null
                          : () {
                              if (_feedProfiles.isNotEmpty &&
                                  _feedProfiles[0].id != null) {
                                // Trigger standard like for the whole profile (media index 0 as default)
                                _handleLikeInteraction(
                                    targetUserId: _feedProfiles[0].id!,
                                    contentType: ContentLikeType.media,
                                    contentIdentifier:
                                        "0", // Default identifier for profile like
                                    interactionType:
                                        LikeInteractionType.standard,
                                    comment:
                                        null // Comment will be asked if needed
                                    );
                              }
                            }),
                  _buildActionButton(
                      Icons.star_rounded, // Rose icon
                      Colors.purple.shade300, // Purple/Gold color for rose
                      _isInteracting
                          ? null
                          : () async {
                              if (_feedProfiles.isNotEmpty &&
                                  _feedProfiles[0].id != null) {
                                // Ask for optional comment for Rose
                                final comment = await _showCommentDialog(
                                    context,
                                    isOptional: true);
                                // Send rose (comment can be null)
                                _handleLikeInteraction(
                                    targetUserId: _feedProfiles[0].id!,
                                    contentType: ContentLikeType
                                        .media, // Rose is general, tie to media[0]?
                                    contentIdentifier: "0",
                                    interactionType: LikeInteractionType.rose,
                                    comment: comment);
                              }
                            }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Build Filter Chips dynamically
  List<Widget> _buildFilterChips(FilterSettings filters) {
    List<Widget> chips = [];

    // Gender Preference
    chips.add(_buildFilterChip(
        Icons.wc_rounded, filters.whoYouWantToSee?.value ?? 'Any'));

    // Age Range
    chips.add(_buildFilterChip(
        Icons.cake_outlined, '${filters.ageMin}-${filters.ageMax}'));

    // Distance
    chips.add(_buildFilterChip(
        Icons.social_distance_outlined, '${filters.radiusKm} km'));

    // Active Today
    if (filters.activeToday == true) {
      chips.add(
          _buildFilterChip(Icons.access_time_filled_rounded, 'Active Today'));
    }

    // Add 'More Filters' Button if needed or just rely on top button
    // chips.add(ActionChip(...) );

    return chips;
  }

  // Helper for individual filter chip
  Widget _buildFilterChip(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Chip(
        avatar: Icon(icon, size: 16, color: Colors.grey[700]),
        label: Text(label),
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[800]),
        backgroundColor: Colors.grey[200],
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildProfileCardAtIndex(int index) {
    // Only HomeProfileCard is needed now
    if (index >= 0 && index < _feedProfiles.length) {
      final currentProfile = _feedProfiles[index];
      return HomeProfileCard(
        profile: currentProfile,
        onLikeContent: (type, identifier, comment) {
          if (currentProfile.id == null) return;
          _handleLikeInteraction(
              targetUserId: currentProfile.id!,
              contentType: type,
              contentIdentifier: identifier,
              interactionType: LikeInteractionType.standard,
              comment: comment);
        },
        onSendRose: (comment) async {
          if (currentProfile.id == null) return;
          // Ask for optional comment for Rose
          final roseComment =
              await _showCommentDialog(context, isOptional: true);
          _handleLikeInteraction(
              targetUserId: currentProfile.id!,
              contentType:
                  ContentLikeType.media, // Rose is general, tie to media[0]?
              contentIdentifier: "0",
              interactionType: LikeInteractionType.rose,
              comment: roseComment);
        },
      );
    }
    return Container(
        alignment: Alignment.center,
        child: const Text("Error loading profile."));
  }

  // Removed _buildTopBarIcon
  // _buildActionButton remains similar (but check icon/colors)
  Widget _buildActionButton(
      IconData icon, Color color, VoidCallback? onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70, // Keep size consistent
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08), // Slightly softer shadow
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
          // Add border if disabled
          border: onPressed == null
              ? Border.all(color: Colors.grey.shade300, width: 1)
              : null,
        ),
        child: Icon(icon,
            color: onPressed == null ? Colors.grey.shade400 : color,
            size: 35), // Size can be adjusted
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
            "Adjust your filters or check back later.", // Updated message
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
            onPressed: () =>
                _fetchFeed(force: true), // Force refresh on button press
          ),
          // Removed "Complete Profile" button - handled by interaction gate
        ],
      ),
    );
  }

  Widget _buildErrorState(AppError error) {
    // _buildErrorState implementation remains largely the same
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
              onPressed: () =>
                  _fetchFeed(force: true), // Force refresh on retry
            ),
          ],
        ),
      ),
    );
  }

  // Keep _showCommentDialog as is
  Future<String?> _showCommentDialog(BuildContext context,
      {bool isOptional = false}) async {
    final TextEditingController commentController = TextEditingController();
    String title =
        isOptional ? "Add a Comment? (Optional)" : "Add a Comment (Required)";
    ValueNotifier<bool> sendEnabledNotifier = ValueNotifier<bool>(isOptional);

    if (!isOptional) {
      commentController.addListener(() {
        // Check mounted before accessing context potentially
        if (mounted) {
          sendEnabledNotifier.value = commentController.text.trim().isNotEmpty;
        }
      });
    }

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: isOptional, // Allow dismissing if optional
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(title,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: TextField(
            controller: commentController,
            decoration: InputDecoration(
              hintText: "Your comment...",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              counterText: "",
            ),
            maxLength: 140,
            maxLines: 3,
            minLines: 1,
            autofocus: true,
            onChanged: (text) {
              // No need for listener if optional, always enable send
              if (!isOptional) {
                sendEnabledNotifier.value = text.trim().isNotEmpty;
              }
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel",
                  style: GoogleFonts.poppins(color: Colors.grey)),
              onPressed: () => Navigator.of(dialogContext).pop(null),
            ),
            ValueListenableBuilder<bool>(
                valueListenable: sendEnabledNotifier,
                builder: (context, isEnabled, child) {
                  return TextButton(
                    child: Text("Send",
                        style: GoogleFonts.poppins(
                            color: isEnabled
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey,
                            fontWeight: FontWeight.w600)),
                    onPressed: isEnabled
                        ? () => Navigator.of(dialogContext)
                            .pop(commentController.text.trim())
                        : null, // Disable if not enabled
                  );
                }),
          ],
        );
      },
    );

    // Clean up listeners and controllers
    try {
      if (!isOptional) commentController.removeListener(() {});
      sendEnabledNotifier.dispose();
      commentController.dispose();
    } catch (e) {
      print("Error disposing comment dialog resources: $e");
    }

    return result; // Return the comment or null
  }
}
