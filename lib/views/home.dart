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
  bool _isInteracting = false; // To show overlay during API call

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feedState = ref.read(feedProvider);
      if (!feedState.hasFetchedOnce && !feedState.isLoading) {
        print("[HomeScreen initState] Feed not fetched yet, triggering fetch.");
        _fetchFeed();
      } else {
        if (mounted) {
          // Initialize local state from provider if already fetched
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
    print("[HomeScreen _fetchFeed] Fetching home feed. Force: $force");
    ref.read(errorProvider.notifier).clearError();
    await ref.read(feedProvider.notifier).fetchFeed(forceRefresh: force);
    // State update is handled by the ref.listen below
  }

  // Dialog shown if user tries to interact before completing onboarding step 2
  void _showCompleteProfileDialog() {
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
                // Navigate to the first screen of the remaining onboarding flow
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NameInputScreen()));
              },
            ),
          ],
        );
      },
    );
  }

  // Called by HomeProfileCard after a successful interaction (like OR dislike)
  void _removeTopCard() {
    print("[HomeScreen _removeTopCard] Removing top card from local state.");
    if (!mounted) return;
    if (_feedProfiles.isNotEmpty) {
      final removedUserId = _feedProfiles[0].id!;
      // Update local state FIRST for immediate UI reflection
      setState(() {
        _feedProfiles.removeAt(0);
      });
      // Then notify the provider
      print(
          "[HomeScreen _removeTopCard] Notifying FeedProvider to remove profile ID: $removedUserId");
      ref.read(feedProvider.notifier).removeProfile(removedUserId);
    }
  }

  // API call handler for LIKES (passed to card)
  Future<bool> _callLikeRepository({
    required int targetUserId,
    required ContentLikeType contentType,
    required String contentIdentifier,
    required LikeInteractionType interactionType,
    String? comment,
  }) async {
    // Check if profile is complete before allowing interaction
    final authStatus = ref.read(authProvider).authStatus;
    if (authStatus == AuthStatus.onboarding2) {
      print(
          "[HomeScreen _callLikeRepository] Interaction blocked: Profile incomplete (onboarding2).");
      _showCompleteProfileDialog();
      return false; // Indicate failure
    }

    if (_isInteracting) return false; // Prevent double taps during API call
    if (mounted) setState(() => _isInteracting = true); // Show overlay

    final errorNotifier = ref.read(errorProvider.notifier)..clearError();
    bool success = false;
    try {
      final likeRepo = ref.read(likeRepositoryProvider);
      print(
          "[HomeScreen _callLikeRepository] Calling API: Target $targetUserId, Type: $contentType, ID: $contentIdentifier, Interaction: $interactionType, Comment: ${comment != null}");
      success = await likeRepo.likeContent(
          likedUserId: targetUserId,
          contentType: contentType,
          contentIdentifier: contentIdentifier,
          interactionType: interactionType,
          comment: comment);

      if (!success) {
        // If API returns false, check if an error was already set by repo/service
        if (mounted && ref.read(errorProvider) == null) {
          print(
              "[HomeScreen _callLikeRepository] API returned false, setting generic error.");
          errorNotifier.setError(
              AppError.server("Could not send ${interactionType.value}."));
          _showErrorSnackbar(
              "Could not send ${interactionType.value}."); // Show feedback
        }
      } else {
        print("[HomeScreen _callLikeRepository] API call successful.");
      }
    } on LikeLimitExceededException catch (e) {
      print("[HomeScreen _callLikeRepository] Like Limit Error: ${e.message}");
      if (mounted) errorNotifier.setError(AppError.validation(e.message));
      _showErrorSnackbar(e.message); // Show specific feedback
    } on InsufficientRosesException catch (e) {
      print(
          "[HomeScreen _callLikeRepository] Insufficient Roses: ${e.message}");
      if (mounted) errorNotifier.setError(AppError.validation(e.message));
      _showErrorSnackbar(e.message); // Show specific feedback
    } on ApiException catch (e) {
      print("[HomeScreen _callLikeRepository] API Exception: ${e.message}");
      if (mounted) errorNotifier.setError(AppError.server(e.message));
      _showErrorSnackbar(e.message); // Show API error message
    } catch (e) {
      print(
          "[HomeScreen _callLikeRepository] Unexpected Error: ${e.toString()}");
      if (mounted)
        errorNotifier
            .setError(AppError.generic("An unexpected error occurred."));
      _showErrorSnackbar("An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => _isInteracting = false); // Hide overlay
    }
    print("[HomeScreen _callLikeRepository] Returning success: $success");
    return success; // Return the outcome
  }

  // --- ADDED: API call handler for DISLIKES (passed to card) ---
  Future<bool> _callDislikeRepository(int targetUserId) async {
    // Check if profile is complete before allowing interaction
    final authStatus = ref.read(authProvider).authStatus;
    if (authStatus == AuthStatus.onboarding2) {
      print(
          "[HomeScreen _callDislikeRepository] Interaction blocked: Profile incomplete (onboarding2).");
      _showCompleteProfileDialog();
      return false;
    }

    if (_isInteracting) return false;
    if (mounted) setState(() => _isInteracting = true);

    final errorNotifier = ref.read(errorProvider.notifier)..clearError();
    bool success = false;
    try {
      final likeRepo = ref.read(likeRepositoryProvider);
      print(
          "[HomeScreen _callDislikeRepository] Calling dislike API for Target $targetUserId");
      success = await likeRepo.dislikeUser(dislikedUserId: targetUserId);

      if (!success) {
        if (mounted && ref.read(errorProvider) == null) {
          print(
              "[HomeScreen _callDislikeRepository] API returned false, setting generic error.");
          errorNotifier.setError(AppError.server("Could not dislike user."));
          _showErrorSnackbar("Could not dislike user.");
        }
      } else {
        print("[HomeScreen _callDislikeRepository] API call successful.");
      }
    } on ApiException catch (e) {
      print("[HomeScreen _callDislikeRepository] API Exception: ${e.message}");
      if (mounted) errorNotifier.setError(AppError.server(e.message));
      _showErrorSnackbar(e.message);
    } catch (e) {
      print(
          "[HomeScreen _callDislikeRepository] Unexpected Error: ${e.toString()}");
      if (mounted)
        errorNotifier
            .setError(AppError.generic("An unexpected error occurred."));
      _showErrorSnackbar("An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => _isInteracting = false);
    }
    print("[HomeScreen _callDislikeRepository] Returning success: $success");
    return success;
  }
  // --- END ADDED ---

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent), // Use red for errors
    );
  }

  Future<void> _openFilterDialog() async {
    print("[HomeScreen] Opening Filter Dialog.");
    await showDialog<bool>(
      context: context,
      builder: (context) => const FilterSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final filters = ref.watch(filterProvider);

    // Update local profile list when provider changes
    ref.listen<HomeFeedState>(feedProvider, (_, next) {
      if (mounted && _feedProfiles != next.profiles) {
        // Only update if different
        setState(() {
          _feedProfiles = next.profiles;
          print(
              "[HomeScreen Listener] Updated local _feedProfiles. Count: ${_feedProfiles.length}");
        });
      }
    });

    final error = feedState.error ?? ref.watch(errorProvider);
    final isLoadingFeed = feedState.isLoading && !feedState.hasFetchedOnce;
    final bool hasProfilesToShow =
        _feedProfiles.isNotEmpty; // Use local state list

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Discover",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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
          // Filter Chips Row (remains the same)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: GestureDetector(
                onTap: _openFilterDialog,
                child: Container(
                  color: Colors.transparent,
                  height: 34,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _buildFilterChips(filters),
                    ),
                  ),
                )),
          ),

          // Feed Area (Expanded)
          Expanded(
            child: Stack(
              alignment: Alignment.center, // Center children like indicators
              children: [
                if (isLoadingFeed)
                  const CircularProgressIndicator(color: Color(0xFF8B5CF6))
                // Show loading only if initial fetch AND no profiles loaded yet
                else if (error != null && !hasProfilesToShow)
                  _buildErrorState(error) // Show error only if no profiles
                else if (!hasProfilesToShow)
                  _buildEmptyState() // Show empty state if no profiles and no error
                else // Only build the card if there are profiles
                  // --- Pass Dislike Callback ---
                  _buildProfileCardAtIndex(
                      0), // Build using local _feedProfiles

                // General interaction loading overlay (covers everything)
                if (_isInteracting)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withOpacity(0.5),
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF8B5CF6))),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // _buildFilterChips, _buildFilterChip, _buildEmptyState, _buildErrorState remain the same
  List<Widget> _buildFilterChips(FilterSettings filters) {
    List<Widget> chips = [];
    chips.add(_buildFilterChip(
        Icons.wc_rounded,
        filters.whoYouWantToSee?.value.replaceFirst(
                filters.whoYouWantToSee!.value[0],
                filters.whoYouWantToSee!.value[0].toUpperCase()) ??
            FilterSettings.defaultGenderPref.value.replaceFirst(
                FilterSettings.defaultGenderPref.value[0],
                FilterSettings.defaultGenderPref.value[0].toUpperCase())));
    chips.add(_buildFilterChip(Icons.cake_outlined,
        '${filters.ageMin ?? FilterSettings.defaultAgeMin}-${filters.ageMax ?? FilterSettings.defaultAgeMax}'));
    chips.add(_buildFilterChip(Icons.social_distance_outlined,
        '${filters.radiusKm ?? FilterSettings.defaultRadius} km'));
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

  Widget _buildFilterChip(IconData icon, String label) {
    const Color themeColor = Color(0xFF8B5CF6);
    const Color themeBgColor = Color(0xFFEDE9FE);
    const Color themeTextColor = themeColor;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Chip(
        avatar: Icon(icon, size: 16, color: themeColor),
        label: Text(label),
        labelStyle: GoogleFonts.poppins(
            fontSize: 12, color: themeTextColor, fontWeight: FontWeight.w500),
        backgroundColor: themeBgColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: 0.0, vertical: -2),
        side: BorderSide.none,
        elevation: 0.5,
        shadowColor: themeColor.withOpacity(0.2),
      ),
    );
  }

  // --- MODIFIED: Build card using local state ---
  Widget _buildProfileCardAtIndex(int index) {
    if (index >= 0 && index < _feedProfiles.length) {
      final currentProfile = _feedProfiles[index];
      return HomeProfileCard(
        // Use unique key based on profile ID to help Flutter optimize
        key: ValueKey(currentProfile.id),
        profile: currentProfile,
        // Pass the callback function to handle the LIKE API call
        performLikeApiCall: (
            {required contentType,
            required contentIdentifier,
            required interactionType,
            comment}) async {
          if (currentProfile.id == null) return false;
          return await _callLikeRepository(
              targetUserId: currentProfile.id!,
              contentType: contentType,
              contentIdentifier: contentIdentifier,
              interactionType: interactionType,
              comment: comment);
        },
        // --- Pass DISLIKE callback ---
        performDislikeApiCall: () async {
          if (currentProfile.id == null) return false;
          return await _callDislikeRepository(currentProfile.id!);
        },
        // Callback to remove the card after success (like OR dislike)
        onInteractionComplete: _removeTopCard,
      );
    }
    // Should ideally not happen if hasProfilesToShow is checked correctly
    return Container(
        alignment: Alignment.center,
        child: Text("No more profiles.", style: GoogleFonts.poppins()));
  }
  // --- END MODIFICATION ---

  Widget _buildEmptyState() {
    // Wrap in LayoutBuilder to ensure scroll physics work for refresh
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline_rounded,
                    size: 80, color: Colors.grey[400]),
                const SizedBox(height: 20),
                Text(
                  "That's everyone for now!",
                  style: GoogleFonts.poppins(
                      fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                Text(
                  "Adjust your filters or check back later.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey[500]),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed: () => _fetchFeed(force: true),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildErrorState(AppError error) {
    // Wrap in LayoutBuilder to ensure scroll physics work for refresh
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
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
                    onPressed: () => _fetchFeed(force: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
