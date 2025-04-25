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
import 'package:dtx/widgets/report_reason_dialog.dart'; // Added
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

  // --- initState, dispose, _fetchFeed, _showCompleteProfileDialog, _removeTopCard ---
  // --- _callLikeRepository, _callDislikeRepository, _showErrorSnackbar ---
  // --- _openFilterDialog, _showMiniFilterEditor, _buildFilterChips, _buildFilterChip ---
  // --- Remain the same ---
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
  }

  void _showCompleteProfileDialog() {
    /* ... keep existing implementation ... */
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

  void _removeTopCard() {
    print("[HomeScreen _removeTopCard] Removing top card from local state.");
    if (!mounted) return;
    if (_feedProfiles.isNotEmpty) {
      final removedUserId = _feedProfiles[0].id!;
      setState(() {
        _feedProfiles.removeAt(0);
      });
      print(
          "[HomeScreen _removeTopCard] Notifying FeedProvider to remove profile ID: $removedUserId");
      ref.read(feedProvider.notifier).removeProfile(removedUserId);
    }
  }

  Future<bool> _callLikeRepository(
      {required int targetUserId,
      required ContentLikeType contentType,
      required String contentIdentifier,
      required LikeInteractionType interactionType,
      String? comment}) async {
    final authStatus = ref.read(authProvider).authStatus;
    if (authStatus == AuthStatus.onboarding2) {
      _showCompleteProfileDialog();
      return false;
    }
    if (_isInteracting) return false;
    if (mounted) setState(() => _isInteracting = true);
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
      if (!success && mounted && ref.read(errorProvider) == null) {
        errorNotifier.setError(
            AppError.server("Could not send ${interactionType.value}."));
        _showErrorSnackbar("Could not send ${interactionType.value}.");
      }
    } on LikeLimitExceededException catch (e) {
      if (mounted) errorNotifier.setError(AppError.validation(e.message));
      _showErrorSnackbar(e.message);
    } on InsufficientRosesException catch (e) {
      if (mounted) errorNotifier.setError(AppError.validation(e.message));
      _showErrorSnackbar(e.message);
    } on ApiException catch (e) {
      if (mounted) errorNotifier.setError(AppError.server(e.message));
      _showErrorSnackbar(e.message);
    } catch (e) {
      if (mounted)
        errorNotifier
            .setError(AppError.generic("An unexpected error occurred."));
      _showErrorSnackbar("An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => _isInteracting = false);
    }
    return success;
  }

  Future<bool> _callDislikeRepository(int targetUserId) async {
    final authStatus = ref.read(authProvider).authStatus;
    if (authStatus == AuthStatus.onboarding2) {
      _showCompleteProfileDialog();
      return false;
    }
    if (_isInteracting) return false;
    if (mounted) setState(() => _isInteracting = true);
    final errorNotifier = ref.read(errorProvider.notifier)..clearError();
    bool success = false;
    try {
      final likeRepo = ref.read(likeRepositoryProvider);
      success = await likeRepo.dislikeUser(dislikedUserId: targetUserId);
      if (!success && mounted && ref.read(errorProvider) == null) {
        errorNotifier.setError(AppError.server("Could not dislike user."));
        _showErrorSnackbar("Could not dislike user.");
      }
    } on ApiException catch (e) {
      if (mounted) errorNotifier.setError(AppError.server(e.message));
      _showErrorSnackbar(e.message);
    } catch (e) {
      if (mounted)
        errorNotifier
            .setError(AppError.generic("An unexpected error occurred."));
      _showErrorSnackbar("An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => _isInteracting = false);
    }
    return success;
  }

  void _showSnackbar(String message, {bool isError = false}) {
    // Added snackbar helper
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green));
  }

  void _showErrorSnackbar(String message) {
    _showSnackbar(message, isError: true);
  } // Added error snackbar helper

  Future<void> _openFilterDialog() async {
    /* ... keep existing implementation ... */
    print("[HomeScreen] Opening Full Filter Dialog.");
    await showDialog<bool>(
        context: context, builder: (context) => const FilterSettingsDialog());
  }

  Future<void> _showMiniFilterEditor(FilterField filterType) async {
    /* ... keep existing implementation ... */
    final filterNotifier = ref.read(filterProvider.notifier);
    final currentFilters = ref.read(filterProvider);
    bool changesMade = false;
    print("[HomeScreen] Opening mini-editor for: $filterType");
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
                          print(
                              "[HomeScreen] Mini-editor change confirmed for $filterType.");
                        } else {
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
      print("[HomeScreen] Mini-filter changed. Saving current state via API.");
      await Future.delayed(const Duration(milliseconds: 50));
      final bool saveSuccess = await filterNotifier.saveCurrentFilterState();
      if (!saveSuccess && mounted) {
        _showErrorSnackbar("Failed to save filter change.");
      }
    } else if (!changesMade) {
      print("[HomeScreen] No changes made in mini-filter editor, not saving.");
    }
  }

  List<Widget> _buildFilterChips(FilterSettings filters) {
    /* ... keep existing implementation ... */
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
    /* ... keep existing implementation ... */
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

  // --- ADDED: _callReportRepository ---
  Future<bool> _callReportRepository(
      int targetUserId, ReportReason reason) async {
    // Check if user needs to complete profile first
    final authStatus = ref.read(authProvider).authStatus;
    if (authStatus == AuthStatus.onboarding2) {
      _showCompleteProfileDialog();
      return false;
    }
    // Prevent multiple interactions
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
      if (mounted)
        errorNotifier
            .setError(AppError.generic("An unexpected error occurred."));
      _showErrorSnackbar("An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => _isInteracting = false);
    }
    return success;
  }
  // --- END ADDED ---

  @override
  Widget build(BuildContext context) {
    // ... (keep existing build setup) ...
    final feedState = ref.watch(feedProvider);
    final filters = ref.watch(filterProvider);
    ref.listen<HomeFeedState>(feedProvider, (_, next) {
      if (mounted && _feedProfiles != next.profiles) {
        setState(() {
          _feedProfiles = next.profiles;
          print(
              "[HomeScreen Listener] Updated local _feedProfiles. Count: ${_feedProfiles.length}");
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
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isLoadingFeed)
                  const CircularProgressIndicator(color: Color(0xFF8B5CF6))
                else if (error != null && !hasProfilesToShow)
                  _buildErrorState(error)
                else if (!hasProfilesToShow)
                  _buildEmptyState()
                else
                  _buildProfileCardAtIndex(0),
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

  // --- Modified _buildProfileCardAtIndex ---
  Widget _buildProfileCardAtIndex(int index) {
    if (index >= 0 && index < _feedProfiles.length) {
      final currentProfile = _feedProfiles[index];
      return HomeProfileCard(
        key: ValueKey(currentProfile.id),
        profile: currentProfile,
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
        performDislikeApiCall: () async {
          if (currentProfile.id == null) return false;
          return await _callDislikeRepository(currentProfile.id!);
        },
        // --- ADDED: Pass Report Callback ---
        performReportApiCall: ({required reason}) async {
          if (currentProfile.id == null) return false;
          return await _callReportRepository(currentProfile.id!, reason);
        },
        // --- END ADDED ---
        onInteractionComplete: _removeTopCard,
      );
    }
    return Container(
        alignment: Alignment.center,
        child: Text("No more profiles.", style: GoogleFonts.poppins()));
  }

  // --- _buildEmptyState, _buildErrorState (keep as is) ---
  Widget _buildEmptyState() {
    /* ... keep existing implementation ... */
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
    /* ... keep existing implementation ... */
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
