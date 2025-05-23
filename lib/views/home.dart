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
import 'package:dtx/views/name.dart'; // Keep for profile completion dialog
import 'package:dtx/models/user_model.dart';
import 'package:dtx/widgets/home_profile_card.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/repositories/like_repository.dart';
import 'package:dtx/widgets/report_reason_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/models/filter_model.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Use local state to manage the currently displayed list
  // Initialize from the provider, but allow local removal for optimism
  List<UserModel> _feedProfiles = [];
  bool _isInteracting = false; // Track interaction state locally

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feedState = ref.read(feedProvider);
      // Initialize local state from provider if it has data
      if (feedState.profiles.isNotEmpty) {
        setState(() {
          _feedProfiles = List.from(feedState.profiles);
          if (kDebugMode)
            print(
                "[HomeScreen initState] Initialized local _feedProfiles from provider. Count: ${_feedProfiles.length}");
        });
      } else if (!feedState.hasFetchedOnce && !feedState.isLoading) {
        // Fetch only if provider hasn't fetched yet and isn't loading
        if (kDebugMode)
          print(
              "[HomeScreen initState] Feed not fetched yet, triggering fetch.");
        _fetchFeed();
      }
      // Fetch filters if they seem default
      final filterState = ref.read(filterProvider);
      final filterNotifier = ref.read(filterProvider.notifier);
      if (filterState == const FilterSettings() && !filterNotifier.isLoading) {
        if (kDebugMode)
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
    if (kDebugMode)
      print("[HomeScreen _fetchFeed] Fetching home feed. Force: $force");
    ref.read(errorProvider.notifier).clearError();
    await ref.read(feedProvider.notifier).fetchFeed(forceRefresh: force);
    // Listener below will update _feedProfiles
  }

  void _showCompleteProfileDialog() {
    // (No changes needed)
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
                    child: Text("Later",
                        style: GoogleFonts.poppins(color: Colors.grey)),
                    onPressed: () => Navigator.of(dialogContext).pop()),
                TextButton(
                    child: Text("Complete Profile",
                        style: GoogleFonts.poppins(
                            color: const Color(0xFF8B5CF6))),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NameInputScreen()));
                    })
              ]);
        });
  }

  // --- OPTIMISTIC: Remove card locally AND notify provider ---
  void _removeTopCard() {
    if (kDebugMode)
      print(
          "[HomeScreen _removeTopCard] Removing top card from local state and notifying provider.");
    if (!mounted) {
      if (kDebugMode)
        print(
            "[HomeScreen _removeTopCard] Widget not mounted, skipping removal.");
      return;
    }
    if (_feedProfiles.isNotEmpty) {
      final removedUserId = _feedProfiles[0].id; // Get ID before removing
      setState(() {
        _feedProfiles
            .removeAt(0); // Remove from local list for immediate UI update
        if (kDebugMode)
          print(
              "[HomeScreen _removeTopCard] Local _feedProfiles count after removal: ${_feedProfiles.length}");
      });
      if (removedUserId != null) {
        // Notify provider to remove from its source list
        if (kDebugMode)
          print(
              "[HomeScreen _removeTopCard] Notifying FeedProvider to remove profile ID: $removedUserId");
        ref.read(feedProvider.notifier).removeProfile(removedUserId);
      } else {
        if (kDebugMode)
          print(
              "[HomeScreen _removeTopCard] Warning: Removed card had null ID.");
      }
    } else {
      if (kDebugMode)
        print(
            "[HomeScreen _removeTopCard] Warning: Attempted to remove card but local list is empty.");
    }
  }
  // --- END OPTIMISTIC CHANGE ---

  // --- START: Optimistic Swipe Handlers ---
  void _handleSwipeLeft() {
    if (kDebugMode)
      print("[HomeScreen _handleSwipeLeft] Swiped Left (Dislike)");
    if (_feedProfiles.isEmpty) return;
    final profileToDislike = _feedProfiles[0];
    if (profileToDislike.id == null) {
      if (kDebugMode)
        print(
            "[HomeScreen _handleSwipeLeft] Cannot dislike, top profile has null ID.");
      return;
    }

    // 1. Optimistic UI Update
    _removeTopCard();

    // 2. Background API Call
    _callDislikeRepository(profileToDislike.id!);
  }

  void _handleSwipeRight() {
    if (kDebugMode) print("[HomeScreen _handleSwipeRight] Swiped Right (Like)");
    if (_feedProfiles.isEmpty) return;
    final profileToLike = _feedProfiles[0];
    if (profileToLike.id == null) {
      if (kDebugMode)
        print(
            "[HomeScreen _handleSwipeRight] Cannot like, top profile has null ID.");
      return;
    }

    // 1. Optimistic UI Update
    _removeTopCard();

    // 2. Background API Call (Default profile like)
    _callLikeRepository(
      targetUserId: profileToLike.id!,
      contentType: ContentLikeType.profile, // Standard profile like on swipe
      contentIdentifier: 'profile', // Standard profile like on swipe
      interactionType: LikeInteractionType.standard,
      comment: null, // No comment on swipe like
    );
  }
  // --- END: Optimistic Swipe Handlers ---

  // --- MODIFIED: API Call Handlers (Now fire-and-forget for background) ---
  Future<void> _callLikeRepository({
    required int targetUserId,
    required ContentLikeType contentType,
    required String contentIdentifier,
    required LikeInteractionType interactionType,
    String? comment,
  }) async {
    // Check profile completion status
    final authStatus = ref.read(authProvider).authStatus;
    if (authStatus == AuthStatus.onboarding2) {
      _showCompleteProfileDialog();
      return; // Don't proceed if profile incomplete
    }

    if (kDebugMode)
      print(
          "[HomeScreen _callLikeRepository BG] Firing API call for UserID: $targetUserId, Type: $contentType, ID: $contentIdentifier, Interaction: $interactionType");

    final errorNotifier = ref.read(errorProvider.notifier)..clearError();

    try {
      final likeRepo = ref.read(likeRepositoryProvider);
      // Call API but don't block UI
      final success = await likeRepo.likeContent(
        likedUserId: targetUserId,
        contentType: contentType,
        contentIdentifier: contentIdentifier,
        interactionType: interactionType,
        comment: comment,
      );

      if (!success && mounted) {
        // If the background call fails, show an error snackbar
        final defaultError = "Could not send ${interactionType.value}.";
        final currentError = ref.read(errorProvider);
        // Use the error set by the repo if available, else use default
        _showErrorSnackbar(currentError?.message ?? defaultError);
      } else if (success) {
        if (kDebugMode)
          print(
              "[HomeScreen _callLikeRepository BG] Background API call successful for UserID: $targetUserId");
      }
    } on LikeLimitExceededException catch (e) {
      if (mounted) {
        errorNotifier.setError(AppError.validation(e.message));
        _showErrorSnackbar(e.message);
      }
    } on InsufficientRosesException catch (e) {
      if (mounted) {
        errorNotifier.setError(AppError.validation(e.message));
        _showErrorSnackbar(e.message);
      }
    } on ApiException catch (e) {
      if (mounted) {
        errorNotifier.setError(AppError.server(e.message));
        _showErrorSnackbar(e.message);
      }
    } catch (e) {
      if (kDebugMode) print("[HomeScreen _callLikeRepository BG] Error: $e");
      if (mounted) {
        errorNotifier
            .setError(AppError.generic("An unexpected error occurred."));
        _showErrorSnackbar("An unexpected error occurred.");
      }
    }
  }

  Future<void> _callDislikeRepository(int targetUserId) async {
    // Check profile completion status
    final authStatus = ref.read(authProvider).authStatus;
    if (authStatus == AuthStatus.onboarding2) {
      _showCompleteProfileDialog();
      return; // Don't proceed if profile incomplete
    }

    if (kDebugMode)
      print(
          "[HomeScreen _callDislikeRepository BG] Firing API call for UserID: $targetUserId");

    final errorNotifier = ref.read(errorProvider.notifier)..clearError();

    try {
      final likeRepo = ref.read(likeRepositoryProvider);
      final success = await likeRepo.dislikeUser(dislikedUserId: targetUserId);

      if (!success && mounted) {
        final defaultError = "Could not dislike user.";
        final currentError = ref.read(errorProvider);
        _showErrorSnackbar(currentError?.message ?? defaultError);
      } else if (success) {
        if (kDebugMode)
          print(
              "[HomeScreen _callDislikeRepository BG] Background API call successful for UserID: $targetUserId");
      }
    } on ApiException catch (e) {
      if (mounted) {
        errorNotifier.setError(AppError.server(e.message));
        _showErrorSnackbar(e.message);
      }
    } catch (e) {
      if (kDebugMode) print("[HomeScreen _callDislikeRepository BG] Error: $e");
      if (mounted) {
        errorNotifier
            .setError(AppError.generic("An unexpected error occurred."));
        _showErrorSnackbar("An unexpected error occurred.");
      }
    }
  }
  // --- END MODIFIED API Call Handlers ---

  void _showSnackbar(String message, {bool isError = false}) {
    // Added snackbar helper
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green));
  }

  void _showErrorSnackbar(String message,
      [String defaultMsg = "An error occurred."]) {
    _showSnackbar(message.isNotEmpty ? message : defaultMsg, isError: true);
  }

  Future<void> _openFilterDialog() async {
    // (No changes needed)
    if (kDebugMode) print("[HomeScreen] Opening Full Filter Dialog.");
    await showDialog<bool>(
        context: context, builder: (context) => const FilterSettingsDialog());
  }

  Future<void> _showMiniFilterEditor(FilterField filterType) async {
    // (No changes needed)
    final filterNotifier = ref.read(filterProvider.notifier);
    final currentFilters = ref.read(filterProvider);
    bool changesMade = false;
    if (kDebugMode) print("[HomeScreen] Opening mini-editor for: $filterType");
    final initialGender = currentFilters.whoYouWantToSee;
    final initialAgeRange = RangeValues(
        currentFilters.ageMin?.toDouble() ??
            FilterSettings.defaultAgeMin.toDouble(),
        currentFilters.ageMax?.toDouble() ??
            FilterSettings.defaultAgeMax.toDouble());
    final initialRadius = currentFilters.radiusKm?.toDouble() ??
        FilterSettings.defaultRadius.toDouble();
    final initialActive =
        currentFilters.activeToday ?? FilterSettings.defaultActiveToday;
    await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          FilterGenderPref? tempGender = initialGender;
          RangeValues tempAgeRange = initialAgeRange;
          double tempRadius = initialRadius;
          bool tempActive = initialActive;
          return StatefulBuilder(builder: (stfContext, stfSetState) {
            Widget editorContent;
            String title = "Edit Filter";
            switch (filterType) {
              case FilterField.whoYouWantToSee:
                title = "Show Me";
                editorContent = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: FilterGenderPref.values.map((gender) {
                      return RadioListTile<FilterGenderPref>(
                          title: Text(
                              gender.value[0].toUpperCase() +
                                  gender.value.substring(1),
                              style: GoogleFonts.poppins()),
                          value: gender,
                          groupValue: tempGender,
                          onChanged: (FilterGenderPref? value) {
                            if (value != null) {
                              stfSetState(() {
                                if (kDebugMode)
                                  print(
                                      "[MiniDialog stfSetState] Updating tempGender from $tempGender to $value");
                                tempGender = value;
                              });
                            }
                          },
                          activeColor: const Color(0xFF8B5CF6),
                          contentPadding: EdgeInsets.zero);
                    }).toList());
                break;
              case FilterField.ageMin:
              case FilterField.ageMax:
                title = "Age Range";
                editorContent =
                    Column(mainAxisSize: MainAxisSize.min, children: [
                  RangeSlider(
                      values: tempAgeRange,
                      min: 18,
                      max: 70,
                      divisions: 52,
                      labels: RangeLabels(tempAgeRange.start.round().toString(),
                          tempAgeRange.end.round().toString()),
                      activeColor: const Color(0xFF8B5CF6),
                      inactiveColor: const Color(0xFF8B5CF6).withOpacity(0.3),
                      onChanged: (RangeValues values) {
                        stfSetState(() {
                          if (values.start <= values.end) {
                            if (kDebugMode)
                              print(
                                  "[MiniDialog stfSetState] Updating tempAgeRange from $tempAgeRange to $values");
                            tempAgeRange = values;
                          }
                        });
                      }),
                  Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                          "${tempAgeRange.start.round()} - ${tempAgeRange.end.round()} years",
                          style: GoogleFonts.poppins(
                              color: Colors.grey[600], fontSize: 14)))
                ]);
                break;
              case FilterField.radiusKm:
                title = "Distance Radius";
                editorContent =
                    Column(mainAxisSize: MainAxisSize.min, children: [
                  Slider(
                      value: tempRadius,
                      min: 1,
                      max: 500,
                      divisions: 499,
                      label: "${tempRadius.round()} km",
                      activeColor: const Color(0xFF8B5CF6),
                      inactiveColor: const Color(0xFF8B5CF6).withOpacity(0.3),
                      onChanged: (double value) {
                        stfSetState(() {
                          if (kDebugMode)
                            print(
                                "[MiniDialog stfSetState] Updating tempRadius from $tempRadius to $value");
                          tempRadius = value;
                        });
                      }),
                  Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text("${tempRadius.round()} km",
                          style: GoogleFonts.poppins(
                              color: Colors.grey[600], fontSize: 14)))
                ]);
                break;
              case FilterField.activeToday:
                title = "Activity";
                editorContent = SwitchListTile(
                    title:
                        Text("Active Today Only", style: GoogleFonts.poppins()),
                    value: tempActive,
                    activeColor: const Color(0xFF8B5CF6),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool value) {
                      stfSetState(() {
                        if (kDebugMode)
                          print(
                              "[MiniDialog stfSetState] Updating tempActive from $tempActive to $value");
                        tempActive = value;
                      });
                    });
                break;
            }
            return AlertDialog(
                title: Text(title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                content: editorContent,
                actions: <Widget>[
                  TextButton(
                      child: Text('Cancel',
                          style: GoogleFonts.poppins(color: Colors.grey)),
                      onPressed: () => Navigator.of(dialogContext).pop()),
                  TextButton(
                      child: Text('Apply',
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF8B5CF6),
                              fontWeight: FontWeight.w600)),
                      onPressed: () async {
                        bool valueChanged = false;
                        switch (filterType) {
                          case FilterField.whoYouWantToSee:
                            valueChanged = (initialGender != tempGender);
                            if (valueChanged)
                              filterNotifier.updateSingleFilter(
                                  tempGender, filterType);
                            break;
                          case FilterField.ageMin:
                          case FilterField.ageMax:
                            valueChanged = (initialAgeRange.start.round() !=
                                    tempAgeRange.start.round() ||
                                initialAgeRange.end.round() !=
                                    tempAgeRange.end.round());
                            if (valueChanged) {
                              filterNotifier.updateSingleFilter(
                                  tempAgeRange.start.round(),
                                  FilterField.ageMin);
                              filterNotifier.updateSingleFilter(
                                  tempAgeRange.end.round(), FilterField.ageMax);
                            }
                            break;
                          case FilterField.radiusKm:
                            valueChanged =
                                (initialRadius.round() != tempRadius.round());
                            if (valueChanged)
                              filterNotifier.updateSingleFilter(
                                  tempRadius.round(), filterType);
                            break;
                          case FilterField.activeToday:
                            valueChanged = (initialActive != tempActive);
                            if (valueChanged)
                              filterNotifier.updateSingleFilter(
                                  tempActive, filterType);
                            break;
                        }
                        if (valueChanged) {
                          changesMade = true;
                          if (kDebugMode)
                            print(
                                "[HomeScreen] Mini-editor change confirmed for $filterType.");
                        } else {
                          if (kDebugMode)
                            print(
                                "[HomeScreen] Mini-editor no change detected for $filterType.");
                        }
                        Navigator.of(dialogContext).pop();
                      })
                ],
                actionsPadding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10));
          });
        });
    if (changesMade && mounted) {
      if (kDebugMode)
        print(
            "[HomeScreen] Mini-filter changed. Saving current state via API.");
      await Future.delayed(const Duration(milliseconds: 50));
      final bool saveSuccess = await filterNotifier.saveCurrentFilterState();
      if (!saveSuccess && mounted) {
        _showErrorSnackbar("Failed to save filter change.");
      }
    } else if (!changesMade) {
      if (kDebugMode)
        print(
            "[HomeScreen] No changes made in mini-filter editor, not saving.");
    }
  }

  List<Widget> _buildFilterChips(FilterSettings filters) {
    // (No changes needed)
    List<Widget> chips = [];
    chips.add(_buildFilterChip(
        Icons.wc_rounded,
        filters.whoYouWantToSee?.value.replaceFirst(
                filters.whoYouWantToSee!.value[0],
                filters.whoYouWantToSee!.value[0].toUpperCase()) ??
            FilterSettings.defaultGenderPref.value.replaceFirst(
                FilterSettings.defaultGenderPref.value[0],
                FilterSettings.defaultGenderPref.value[0].toUpperCase()),
        FilterField.whoYouWantToSee,
        () => _showMiniFilterEditor(FilterField.whoYouWantToSee)));
    chips.add(_buildFilterChip(
        Icons.cake_outlined,
        '${filters.ageMin ?? FilterSettings.defaultAgeMin}-${filters.ageMax ?? FilterSettings.defaultAgeMax}',
        FilterField.ageMin,
        () => _showMiniFilterEditor(FilterField.ageMin)));
    chips.add(_buildFilterChip(
        Icons.social_distance_outlined,
        '${filters.radiusKm ?? FilterSettings.defaultRadius} km',
        FilterField.radiusKm,
        () => _showMiniFilterEditor(FilterField.radiusKm)));
    bool activeTodayValue =
        filters.activeToday ?? FilterSettings.defaultActiveToday;
    chips.add(_buildFilterChip(
        activeTodayValue
            ? Icons.access_time_filled_rounded
            : Icons.access_time_rounded,
        activeTodayValue ? 'Active Today' : 'Active: Any',
        FilterField.activeToday,
        () => _showMiniFilterEditor(FilterField.activeToday)));
    return chips;
  }

  Widget _buildFilterChip(
      IconData icon, String label, FilterField type, VoidCallback onTap) {
    // (No changes needed)
    const Color themeColor = Color(0xFF8B5CF6);
    const Color themeBgColor = Color(0xFFEDE9FE);
    const Color themeTextColor = themeColor;
    return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: GestureDetector(
            onTap: onTap,
            child: Chip(
                avatar: Icon(icon, size: 16, color: themeColor),
                label: Text(label),
                labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: themeTextColor,
                    fontWeight: FontWeight.w500),
                backgroundColor: themeBgColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity:
                    const VisualDensity(horizontal: 0.0, vertical: -2),
                side: BorderSide.none,
                elevation: 0.5,
                shadowColor: themeColor.withOpacity(0.2))));
  }

  Future<bool> _callReportRepository(
      int targetUserId, ReportReason reason) async {
    // (No changes needed, but now returns bool for consistency, though not used)
    final authStatus = ref.read(authProvider).authStatus;
    if (authStatus == AuthStatus.onboarding2) {
      _showCompleteProfileDialog();
      return false;
    }
    if (_isInteracting) return false;
    setState(() => _isInteracting = true);
    final errorNotifier = ref.read(errorProvider.notifier)..clearError();
    bool success = false;
    try {
      success = await ref.read(likeRepositoryProvider).reportUser(
            targetUserId: targetUserId,
            reason: reason,
          );
      if (success && mounted) {
        _showSnackbar("Report submitted successfully.", isError: false);
        _removeTopCard(); // Remove the card after reporting
      } else if (!success && mounted && ref.read(errorProvider) == null) {
        errorNotifier.setError(AppError.server("Failed to submit report."));
        _showErrorSnackbar("Failed to submit report.");
      }
    } on ApiException catch (e) {
      if (mounted) errorNotifier.setError(AppError.server(e.message));
      _showErrorSnackbar(e.message);
    } catch (e) {
      if (kDebugMode) print("[HomeScreen _callReportRepository] Error: $e");
      if (mounted)
        errorNotifier
            .setError(AppError.generic("An unexpected error occurred."));
      _showErrorSnackbar("An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => _isInteracting = false);
    }
    return success;
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final filters = ref.watch(filterProvider);
    // Listen to provider changes to update local state
    ref.listen<HomeFeedState>(feedProvider, (_, next) {
      if (mounted && _feedProfiles != next.profiles) {
        // Check if the list reference is actually different
        setState(() {
          _feedProfiles = List.from(
              next.profiles); // Update local copy when provider changes
          if (kDebugMode)
            print(
                "[HomeScreen Listener] Updated local _feedProfiles from provider. New Count: ${_feedProfiles.length}");
        });
      }
    });
    final error = feedState.error ?? ref.watch(errorProvider);
    final isLoadingFeed = feedState.isLoading && !feedState.hasFetchedOnce;
    // Use local list for UI building
    final bool hasProfilesToShow = _feedProfiles.isNotEmpty;

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
              onPressed: _openFilterDialog)
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row (No changes needed)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Container(
                color: Colors.transparent,
                height: 34,
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(children: _buildFilterChips(filters)))),
          ),
          // Main Content Area
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isLoadingFeed)
                  const CircularProgressIndicator(color: Color(0xFF8B5CF6))
                // --- Build based on local _feedProfiles ---
                else if (error != null && !hasProfilesToShow)
                  _buildErrorState(error)
                else if (!hasProfilesToShow)
                  _buildEmptyState()
                else
                  _buildProfileCardAtIndex(0), // Only build the top card
                // --- End Local List Build ---

                // Interaction overlay remains the same BUT is now less used visually
                if (_isInteracting)
                  Positioned.fill(
                      child: Container(
                          color: Colors.white.withOpacity(0.5),
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF8B5CF6))))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Modified to pass Optimistic Swipe Handlers ---
  Widget _buildProfileCardAtIndex(int index) {
    if (index >= 0 && index < _feedProfiles.length) {
      final currentProfile = _feedProfiles[index];
      return HomeProfileCard(
        key: ValueKey(currentProfile.id), // Use profile ID as key
        profile: currentProfile,
        // Pass background API handlers
        performLikeApiCall: (
            {required contentType,
            required contentIdentifier,
            required interactionType,
            comment}) async {
          // Call background API call, return true optimistically
          _callLikeRepository(
              targetUserId: currentProfile.id!,
              contentType: contentType,
              contentIdentifier: contentIdentifier,
              interactionType: interactionType,
              comment: comment);
          return true;
        },
        performDislikeApiCall: () async {
          // Call background API call, return true optimistically
          _callDislikeRepository(currentProfile.id!);
          return true;
        },
        performReportApiCall: ({required reason}) async {
          // Keep reporting synchronous for now? Or make optimistic too?
          // Let's make it optimistic for consistency.
          _callReportRepository(currentProfile.id!, reason);
          return true;
        },
        onInteractionComplete: _removeTopCard, // Optimistic UI removal
        // *** Pass SWIPE Handlers ***
        onSwiped: (direction) {
          if (direction == DismissDirection.endToStart) {
            _handleSwipeLeft(); // Dislike
          } else if (direction == DismissDirection.startToEnd) {
            _handleSwipeRight(); // Like
          }
        },
        // *** END SWIPE Handlers ***
      );
    }
    // Show empty state if local list is empty AFTER loading/error checks
    return _buildEmptyState();
  }
  // --- End Modification ---

  // --- Helper methods (_buildEmptyState, _buildErrorState, etc.) remain unchanged ---
  Widget _buildEmptyState() {
    // (No changes needed)
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
                    Text("That's everyone for now!",
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.grey[600])),
                    const SizedBox(height: 10),
                    Text("Adjust your filters or check back later.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.grey[500])),
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
                                horizontal: 20, vertical: 10)),
                        onPressed: () => _fetchFeed(force: true))
                  ]))));
    });
  }

  Widget _buildErrorState(AppError error) {
    // (No changes needed)
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
                            Text("Oops! Something went wrong",
                                style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700]),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            Text(error.message,
                                style: GoogleFonts.poppins(
                                    fontSize: 14, color: Colors.grey[600]),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text("Retry"),
                                style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: const Color(0xFF8B5CF6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 30, vertical: 12)),
                                onPressed: () => _fetchFeed(force: true))
                          ])))));
    });
  }
} // End of _HomeScreenState
