// File: lib/views/home.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/models/auth_model.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/feed_provider.dart';
import 'package:dtx/providers/filter_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/views/filter_settings_dialog.dart';
import 'package:dtx/views/name.dart';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/widgets/home_profile_card.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/repositories/like_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/models/filter_model.dart';
import 'package:dtx/utils/app_enums.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<UserModel> _feedProfiles = [];
  bool _isInteracting = false;

  // --- Unchanged Methods ---
  @override
  void initState() {
    /* ... */
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feedState = ref.read(feedProvider);
      if (!feedState.hasFetchedOnce && !feedState.isLoading) {
        print("[HomeScreen initState] Feed not fetched yet, triggering fetch.");
        _fetchFeed();
      } else {
        if (mounted) {
          setState(() {
            _feedProfiles = feedState.profiles;
          });
        }
      }
      final filterState = ref.read(filterProvider);
      final filterNotifier = ref.read(filterProvider.notifier);
      if (filterState == const FilterSettings() && !filterNotifier.isLoading) {
        print(
            "[HomeScreen initState] Filters appear default, triggering load.");
        filterNotifier.loadFilters();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchFeed({bool force = false}) async {
    /* ... */
    print("[HomeScreen _fetchFeed] Fetching home feed. Force: $force");
    ref.read(errorProvider.notifier).clearError();
    await ref.read(feedProvider.notifier).fetchFeed(forceRefresh: force);
  }

  void _showCompleteProfileDialog() {
    /* ... */
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Complete Your Profile",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text(
              "To interact with profiles, please complete your profile setup.",
              style: GoogleFonts.poppins()),
          actions: <Widget>[
            TextButton(
              child:
                  Text("Later", style: GoogleFonts.poppins(color: Colors.grey)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text("Complete Profile",
                  style: GoogleFonts.poppins(color: Color(0xFF8B5CF6))),
              onPressed: () {
                Navigator.of(dialogContext).pop();
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
    /* ... */
    print("[HomeScreen _removeTopCard] Removing top card.");
    if (!mounted) return;
    if (_feedProfiles.isNotEmpty) {
      ref.read(feedProvider.notifier).removeProfile(_feedProfiles[0].id!);
    }
    _isInteracting = false;
  }

  Future<void> _handleLikeInteraction(
      {required int targetUserId,
      required ContentLikeType contentType,
      required String contentIdentifier,
      required LikeInteractionType interactionType,
      String? comment}) async {
    /* ... */
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
    /* ... */
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
    /* ... */
    print("[HomeScreen _handleDislikeButtonPressed] Dislike button tapped.");
    if (_feedProfiles.isEmpty || _isInteracting) return;
    final targetProfile = _feedProfiles[0];
    if (targetProfile.id == null) return;
    await _performDislike(targetProfile.id!);
  }

  void _showErrorSnackbar(String message) {
    /* ... */
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins())),
    );
  }

  Future<String?> _showCommentDialog(BuildContext context,
      {bool isOptional = false}) async {
    /* ... */
    final TextEditingController commentController = TextEditingController();
    String title =
        isOptional ? "Add a Comment? (Optional)" : "Add a Comment (Required)";
    ValueNotifier<bool> sendEnabledNotifier = ValueNotifier<bool>(isOptional);

    if (!isOptional) {
      commentController.addListener(() {
        if (mounted) {
          sendEnabledNotifier.value = commentController.text.trim().isNotEmpty;
        }
      });
    }

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: isOptional,
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
                        : null,
                  );
                }),
          ],
        );
      },
    );

    try {
      if (!isOptional) commentController.removeListener(() {});
      sendEnabledNotifier.dispose();
      commentController.dispose();
    } catch (e) {
      print("Error disposing comment dialog resources: $e");
    }
    return result;
  }

  Future<void> _openFilterDialog() async {
    /* ... */
    print("[HomeScreen] Opening Filter Dialog.");
    await showDialog<bool>(
      context: context,
      builder: (context) => const FilterSettingsDialog(),
    );
  }
  // --- End Unchanged Methods ---

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final filters = ref.watch(filterProvider);

    ref.listen<HomeFeedState>(feedProvider, (_, next) {
      if (mounted) {
        setState(() {
          _feedProfiles = next.profiles;
        });
      }
    });

    final error = feedState.error ?? ref.watch(errorProvider);
    final isLoadingFeed = feedState.isLoading && !feedState.hasFetchedOnce;
    final bool hasProfilesToShow = _feedProfiles.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Discover",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0, // Flat AppBar
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF8B5CF6)),
            tooltip: "Filters",
            onPressed: _openFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: GestureDetector(
                onTap: _openFilterDialog,
                child: Container(
                  color: Colors.transparent,
                  height: 34, // Adjust height if needed
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _buildFilterChips(filters),
                    ),
                  ),
                )),
          ),
          // Removed Divider

          // Feed Area (Expanded) - Unchanged
          Expanded(
            child: Stack(
              children: [
                if (hasProfilesToShow) _buildProfileCardAtIndex(0),
                if (isLoadingFeed)
                  const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF8B5CF6))),
                if (!isLoadingFeed && error != null && !hasProfilesToShow)
                  _buildErrorState(error),
                if (!isLoadingFeed && error == null && !hasProfilesToShow)
                  _buildEmptyState(),
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

          // Bottom Action Buttons - Unchanged
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
                      Icons.favorite_rounded,
                      Colors.pink.shade300,
                      _isInteracting
                          ? null
                          : () {
                              if (_feedProfiles.isNotEmpty &&
                                  _feedProfiles[0].id != null) {
                                _handleLikeInteraction(
                                    targetUserId: _feedProfiles[0].id!,
                                    contentType: ContentLikeType.media,
                                    contentIdentifier: "0",
                                    interactionType:
                                        LikeInteractionType.standard,
                                    comment: null);
                              }
                            }),
                  _buildActionButton(
                      Icons.star_rounded,
                      Colors.purple.shade300,
                      _isInteracting
                          ? null
                          : () async {
                              if (_feedProfiles.isNotEmpty &&
                                  _feedProfiles[0].id != null) {
                                final comment = await _showCommentDialog(
                                    context,
                                    isOptional: true);
                                _handleLikeInteraction(
                                    targetUserId: _feedProfiles[0].id!,
                                    contentType: ContentLikeType.media,
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

  // Build Filter Chips dynamically - Removed isActive logic from call
  List<Widget> _buildFilterChips(FilterSettings filters) {
    List<Widget> chips = [];

    // Gender Preference Chip
    chips.add(_buildFilterChip(
        Icons.wc_rounded,
        filters.whoYouWantToSee?.value.replaceFirst(
                filters.whoYouWantToSee!.value[0],
                filters.whoYouWantToSee!.value[0].toUpperCase()) ??
            FilterSettings.defaultGenderPref.value.replaceFirst(
                FilterSettings.defaultGenderPref.value[0],
                FilterSettings.defaultGenderPref.value[0].toUpperCase())));

    // Age Range Chip
    chips.add(_buildFilterChip(Icons.cake_outlined,
        '${filters.ageMin ?? FilterSettings.defaultAgeMin}-${filters.ageMax ?? FilterSettings.defaultAgeMax}'));

    // Distance Chip
    chips.add(_buildFilterChip(Icons.social_distance_outlined,
        '${filters.radiusKm ?? FilterSettings.defaultRadius} km'));

    // Active Today Chip - Use value to determine label/icon
    bool activeTodayValue =
        filters.activeToday ?? FilterSettings.defaultActiveToday;
    chips.add(_buildFilterChip(
      activeTodayValue
          ? Icons.access_time_filled_rounded
          : Icons.access_time_rounded,
      activeTodayValue ? 'Active Today' : 'Active: Any',
    ));

    return chips;
  }

  // Helper for individual filter chip - ALWAYS use purple theme
  Widget _buildFilterChip(IconData icon, String label) {
    final Color themeColor = const Color(0xFF8B5CF6); // Purple theme
    final Color themeBgColor =
        const Color(0xFFEDE9FE); // Light purple background
    final Color themeTextColor = themeColor; // Use main theme color for text

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Chip(
        avatar: Icon(icon, size: 16, color: themeColor), // Use theme color
        label: Text(label),
        labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: themeTextColor, // Use theme text color
            fontWeight: FontWeight.w500),
        backgroundColor: themeBgColor, // Use theme background color
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: 0.0, vertical: -2),
        side: BorderSide.none, // No border
        elevation: 0.5, // Optional: small consistent elevation
        shadowColor: themeColor.withOpacity(0.2), // Optional: subtle shadow
      ),
    );
  }

  // --- Unchanged Methods ---
  Widget _buildProfileCardAtIndex(int index) {
    /* ... */
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
          final roseComment =
              await _showCommentDialog(context, isOptional: true);
          _handleLikeInteraction(
              targetUserId: currentProfile.id!,
              contentType: ContentLikeType.media,
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

  Widget _buildActionButton(
      IconData icon, Color color, VoidCallback? onPressed) {
    /* ... */
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
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
          border: onPressed == null
              ? Border.all(color: Colors.grey.shade300, width: 1)
              : null,
        ),
        child: Icon(icon,
            color: onPressed == null ? Colors.grey.shade400 : color, size: 35),
      ),
    );
  }

  Widget _buildEmptyState() {
    /* ... */
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
            "Adjust your filters or check back later.",
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
            onPressed: () => _fetchFeed(force: true),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppError error) {
    /* ... */
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
              onPressed: () => _fetchFeed(force: true),
            ),
          ],
        ),
      ),
    );
  }
  // --- End Unchanged Methods ---
} // End of _HomeScreenState
