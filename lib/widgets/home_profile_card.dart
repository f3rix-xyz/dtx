// File: widgets/home_profile_card.dart
import 'dart:async';
import 'dart:math';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/audio_player_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/providers/user_provider.dart'; // Needed for currentUserGender check in dialog
import 'package:dtx/widgets/report_reason_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Function Type Definitions
typedef PerformLikeApiCall = Future<bool> Function({
  required ContentLikeType contentType,
  required String contentIdentifier,
  required LikeInteractionType interactionType,
  String? comment,
});
typedef PerformDislikeApiCall = Future<bool> Function();
typedef InteractionCompleteCallback = void Function();
typedef PerformReportApiCall = Future<bool> Function(
    {required ReportReason reason});

const int maxCommentLength = 140;

class HomeProfileCard extends ConsumerWidget {
  final UserModel profile;
  final PerformLikeApiCall performLikeApiCall;
  final PerformDislikeApiCall performDislikeApiCall;
  final PerformReportApiCall performReportApiCall;
  final InteractionCompleteCallback onInteractionComplete;

  const HomeProfileCard({
    super.key,
    required this.profile,
    required this.performLikeApiCall,
    required this.performDislikeApiCall,
    required this.performReportApiCall,
    required this.onInteractionComplete,
  });

  // --- Interaction Dialog (Like/Rose/Comment) ---
  Future<void> _showInteractionDialog(
    BuildContext context,
    WidgetRef ref,
    ContentLikeType contentType,
    String contentIdentifier,
    String? previewImageUrl,
  ) async {
    final currentUserGender = ref.read(userProvider).gender;
    final isMale = currentUserGender == Gender.man;
    final FocusNode commentFocusNode = FocusNode();
    final TextEditingController commentController = TextEditingController();
    // Notifier tracks if the comment field allows sending (non-empty for males)
    final ValueNotifier<bool> sendLikeEnabledNotifier =
        ValueNotifier<bool>(!isMale);
    // Notifier tracks if an API call (like/rose) is in progress within the dialog
    final ValueNotifier<bool> _isDialogInteractionActive =
        ValueNotifier<bool>(false);
    VoidCallback? listenerCallback; // To hold the listener function reference

    // Add listener only if the user is male to enable/disable based on comment
    if (isMale) {
      listenerCallback = () {
        // Check if the widget is still mounted and the notifier hasn't been disposed
        if (context.mounted && commentController.hasListeners) {
          try {
            sendLikeEnabledNotifier.value =
                commentController.text.trim().isNotEmpty;
          } catch (e) {
            // Handle cases where the notifier might be disposed prematurely
            print(
                "Error accessing sendLikeEnabledNotifier in listener (might be disposed): $e");
          }
        }
      };
      commentController.addListener(listenerCallback);
    }

    // --- Handle Like/Rose Submission ---
    Future<void> _handleInteraction(LikeInteractionType interactionType) async {
      // Prevent multiple simultaneous submissions
      if (_isDialogInteractionActive.value) return;

      // Safely get comment text
      String comment = "";
      try {
        comment = commentController.text.trim();
      } catch (e) {
        print("Error reading commentController text (already disposed?): $e");
        return; // Cannot proceed if controller is disposed
      }

      // Unfocus text field
      commentFocusNode.unfocus();
      // Short delay allows keyboard to retract smoothly before showing loading
      await Future.delayed(const Duration(milliseconds: 100));

      // Set interaction active state safely
      try {
        _isDialogInteractionActive.value = true;
      } catch (e) {
        print(
            "Error setting _isDialogInteractionActive to true (notifier disposed?): $e");
        return; // Cannot proceed if notifier is disposed
      }

      bool success = false;
      try {
        // Perform the API call passed from the HomeScreen
        success = await performLikeApiCall(
          contentType: contentType,
          contentIdentifier: contentIdentifier,
          interactionType: interactionType,
          comment: comment.isNotEmpty ? comment : null,
        );

        // Close dialog and trigger card removal ONLY on success
        if (success && context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Close dialog
          onInteractionComplete(); // Trigger card removal etc. in HomeScreen
        }
        // Error snackbars/handling is managed within performLikeApiCall (in HomeScreen)
      } finally {
        // Reset interaction state safely, even if API call failed
        try {
          // Check context AND if the value is actually true before setting false
          if (context.mounted && _isDialogInteractionActive.value) {
            _isDialogInteractionActive.value = false;
          }
        } catch (e) {
          print(
              "Error setting _isDialogInteractionActive to false (notifier disposed?): $e");
        }
      }
    }
    // --- End Handle Like/Rose Submission ---

    try {
      // --- Show Dialog ---
      await showDialog<void>(
        context: context,
        barrierDismissible: true, // Allow dismissing by tapping outside
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            contentPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            content: SizedBox(
              width: MediaQuery.of(dialogContext).size.width *
                  0.8, // Constrain width
              child: SingleChildScrollView(
                // Allow scrolling if content overflows
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Fit content vertically
                  children: [
                    // Image Preview (if applicable)
                    if (previewImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: CachedNetworkImage(
                          imageUrl: previewImageUrl,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 100,
                            color: Colors.grey[200],
                            child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xAA8B5CF6))),
                          ),
                          errorWidget: (context, url, error) => Container(
                              height: 100,
                              color: Colors.grey[200],
                              child: Icon(Icons.broken_image,
                                  color: Colors.grey[400])),
                        ),
                      ),
                    // Audio Prompt Placeholder (if applicable)
                    if (previewImageUrl == null &&
                        contentType == ContentLikeType.audioPrompt)
                      Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Center(
                            child: Icon(Icons.multitrack_audio_rounded,
                                size: 40, color: Colors.grey[500])),
                      ),
                    // Text Prompt Placeholder (if applicable)
                    if (previewImageUrl == null &&
                        contentType != ContentLikeType.audioPrompt)
                      Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Center(
                            child: Icon(Icons.article_outlined,
                                size: 40, color: Colors.grey[500])),
                      ),

                    const SizedBox(height: 16),

                    // Comment TextField
                    TextField(
                      controller: commentController,
                      focusNode: commentFocusNode,
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide:
                              const BorderSide(color: Color(0xFF8B5CF6)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        counterText: "", // Hide default counter
                      ),
                      maxLength: maxCommentLength, // Use constant
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons (Rose/Like)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Rose Button
                        ValueListenableBuilder<bool>(
                          valueListenable: sendLikeEnabledNotifier,
                          builder: (context, isCommentValid, child) {
                            final bool roseButtonEnabled =
                                !isMale || isCommentValid;
                            return ValueListenableBuilder<bool>(
                              valueListenable: _isDialogInteractionActive,
                              builder: (context, isInteractionActive, child) {
                                final bool effectiveEnabled =
                                    roseButtonEnabled && !isInteractionActive;
                                return OutlinedButton.icon(
                                  icon: Icon(
                                    Icons.star_rounded,
                                    color: effectiveEnabled
                                        ? Colors.purple.shade300
                                        : Colors.grey.shade400,
                                    size: 18,
                                  ),
                                  label: Text(
                                    "Send Rose",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color: effectiveEnabled
                                          ? Colors.purple.shade400
                                          : Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: effectiveEnabled
                                        ? Colors.purple.shade400
                                        : Colors.grey.shade500,
                                    side: BorderSide(
                                      color: effectiveEnabled
                                          ? Colors.purple.shade100
                                          : Colors.grey.shade300,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 12),
                                  ),
                                  onPressed: effectiveEnabled
                                      ? () => _handleInteraction(
                                          LikeInteractionType.rose)
                                      : null,
                                );
                              },
                            );
                          },
                        ),
                        // Like Button
                        ValueListenableBuilder<bool>(
                          valueListenable: sendLikeEnabledNotifier,
                          builder: (context, isCommentValid, child) {
                            final bool likeButtonEnabled =
                                !isMale || isCommentValid;
                            return ValueListenableBuilder<bool>(
                              valueListenable: _isDialogInteractionActive,
                              builder: (context, isInteractionActive, child) {
                                final bool effectiveEnabled =
                                    likeButtonEnabled && !isInteractionActive;
                                return ElevatedButton.icon(
                                  icon: Icon(
                                    Icons.favorite_rounded,
                                    color: effectiveEnabled
                                        ? Colors.white
                                        : Colors.grey.shade400,
                                    size: 18,
                                  ),
                                  label: Text(
                                    "Send Like",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: effectiveEnabled
                                          ? Colors.white
                                          : Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: effectiveEnabled
                                        ? Colors.pink.shade300
                                        : Colors.grey.shade200,
                                    disabledBackgroundColor:
                                        Colors.grey.shade200,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 12),
                                    elevation: effectiveEnabled ? 2 : 0,
                                  ),
                                  onPressed: effectiveEnabled
                                      ? () => _handleInteraction(
                                          LikeInteractionType.standard)
                                      : null,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),

                    // Cancel Button
                    ValueListenableBuilder<bool>(
                      valueListenable: _isDialogInteractionActive,
                      builder: (context, isInteractionActive, child) {
                        return TextButton(
                          child: Text("Cancel",
                              style: GoogleFonts.poppins(
                                  color: isInteractionActive
                                      ? Colors.grey.shade400
                                      : Colors.grey)),
                          onPressed: isInteractionActive
                              ? null // Disable cancel if interaction is active
                              : () => Navigator.of(dialogContext).pop(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      // --- End Show Dialog ---
    } finally {
      // Safely clean up listeners and controllers
      if (listenerCallback != null) {
        try {
          commentController.removeListener(listenerCallback);
          listenerCallback = null; // Help GC
        } catch (e) {
          print(
              "Error removing commentController listener (already removed?): $e");
        }
      }
      try {
        sendLikeEnabledNotifier.dispose();
      } catch (e) {
        print("Error disposing sendLikeEnabledNotifier: $e");
      }
      try {
        commentController.dispose();
      } catch (e) {
        print("Error disposing commentController: $e");
      }
      try {
        commentFocusNode.dispose();
      } catch (e) {
        print("Error disposing commentFocusNode: $e");
      }
      try {
        _isDialogInteractionActive.dispose();
      } catch (e) {
        print("Error disposing _isDialogInteractionActive: $e");
      }
    }
  }

  // --- Handle Report Action (Shows Reason Dialog) ---
  Future<void> _handleReport(BuildContext context) async {
    // Show the dialog to get the reason
    final selectedReason = await showReportReasonDialog(context);
    if (selectedReason != null) {
      // Call the report API function passed from HomeScreen
      // API call result/error handling is done in HomeScreen
      await performReportApiCall(reason: selectedReason);
      // Card removal is handled by the callback in HomeScreen if report succeeds
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- Content Block Generation (No Change) ---
    final List<dynamic> contentBlocks = [];
    final mediaUrls = profile.mediaUrls ?? [];
    final prompts = profile.prompts;
    contentBlocks.add("header_section");
    if (mediaUrls.isNotEmpty)
      contentBlocks.add({"type": "media", "value": mediaUrls[0], "index": 0});
    if (prompts.isNotEmpty) contentBlocks.add(prompts[0]);
    contentBlocks.add("vitals_section");
    int mediaIndex = 1;
    int promptIndex = 1;
    int maxRemaining = max(mediaUrls.length, prompts.length);
    for (int i = 1; i < maxRemaining; i++) {
      if (mediaIndex < mediaUrls.length) {
        contentBlocks
            .add({"type": "media", "value": mediaUrls[mediaIndex], "index": i});
        mediaIndex++;
      }
      if (promptIndex < prompts.length) {
        contentBlocks.add(prompts[promptIndex]);
        promptIndex++;
      }
    }
    if (profile.audioPrompt != null) contentBlocks.add(profile.audioPrompt!);
    // --- End Content Block Generation ---

    return Container(
      color: Colors.white, // Background for the entire card area
      child: Stack(
        // Use Stack to overlay buttons
        children: [
          // Main Scrollable Content
          ListView.builder(
            physics: const ClampingScrollPhysics(), // Prevents overscroll glow
            padding: const EdgeInsets.only(bottom: 80.0), // Space for buttons
            itemCount: contentBlocks.length,
            itemBuilder: (context, index) {
              final item = contentBlocks[index];
              final double topPadding = (index == 0) ? 16.0 : 0;
              final double bottomPadding = 20.0;
              final double horizontalPadding = 12.0;
              Widget contentWidget;

              // Build content blocks based on type
              if (item is String && item == "header_section") {
                contentWidget = _buildHeaderBlock(context, profile);
              } else if (item is Map && item["type"] == "media") {
                contentWidget = _buildMediaItem(
                    context, ref, item["value"] as String, item["index"]);
              } else if (item is Prompt) {
                contentWidget = _buildPromptItem(context, ref, item);
              } else if (item is AudioPromptModel) {
                contentWidget = _buildAudioItem(context, ref, item);
              } else if (item is String && item == "vitals_section") {
                contentWidget = _buildVitalsBlock(profile);
              } else {
                contentWidget = const SizedBox.shrink();
              }

              // Add padding around each block
              return Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding,
                    horizontalPadding, bottomPadding),
                child: contentWidget,
              );
            },
          ),

          // Action Buttons Row (Dislike Only Now)
          Positioned(
            bottom: 15, // Adjust position as needed
            left: 30,
            right: 30, // Ensure it takes full width for spaceBetween
            child: Row(
              // *** MODIFIED: Use spaceBetween and added Dislike Button back ***
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              // *** END MODIFICATION ***
              children: [
                // Dislike Button (Restored)
                _buildActionButton(
                  icon: Icons.close_rounded,
                  color: Colors.redAccent.shade100,
                  onPressed: () async {
                    // Call the dislike API function passed from HomeScreen
                    bool success = await performDislikeApiCall();
                    if (success) {
                      onInteractionComplete(); // Trigger card removal in HomeScreen
                    }
                  },
                  tooltip: "Dislike",
                  size: 55, // Smaller action buttons
                ),
                // Add other buttons here if needed in the future, using spaceBetween
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Header Block Builder ---
  Widget _buildHeaderBlock(BuildContext context, UserModel profile) {
    final age = profile.age;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and Age (Takes available space)
            Flexible(
              child: Text(
                '${profile.name ?? 'Name'}${age != null ? ', $age' : ''}',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                softWrap: true,
              ),
            ),
            // More Options Menu Button
            _buildHeaderMenuButton(context), // Use the helper
          ],
        ),
        // Location (remains below the Name/Age/Menu row)
        if (profile.hometown != null && profile.hometown!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                profile.hometown!,
                style:
                    GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // --- Header Menu Button Helper ---
  Widget _buildHeaderMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: "More options",
      icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onSelected: (String result) {
        if (result == 'report') {
          _handleReport(context);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'report',
          child: ListTile(
            leading: Icon(Icons.flag_outlined, color: Colors.redAccent),
            // *** MODIFIED: Simplified Text ***
            title: Text('Report',
                style: GoogleFonts.poppins(color: Colors.redAccent)),
            // *** END MODIFICATION ***
            dense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
    );
  }

  // --- Other Helper Methods (_buildVitalsBlock, etc. remain unchanged) ---
  Widget _buildVitalsBlock(UserModel profile) {
    final List<Widget> vitals = [];
    if (profile.height != null && profile.height!.isNotEmpty) {
      vitals.add(_buildVitalRow(Icons.height, profile.height!));
    }
    if (profile.religiousBeliefs != null) {
      vitals.add(_buildVitalRow(
          Icons.church_outlined, profile.religiousBeliefs!.label));
    }
    if (profile.jobTitle != null && profile.jobTitle!.isNotEmpty) {
      vitals.add(_buildVitalRow(Icons.work_outline, profile.jobTitle!));
    }
    if (profile.education != null && profile.education!.isNotEmpty) {
      vitals.add(_buildVitalRow(Icons.school_outlined, profile.education!));
    }
    if (profile.drinkingHabit != null) {
      vitals.add(_buildVitalRow(
          Icons.local_bar_outlined, "Drinks: ${profile.drinkingHabit!.label}"));
    }
    if (profile.smokingHabit != null) {
      vitals.add(_buildVitalRow(Icons.smoking_rooms_outlined,
          "Smokes: ${profile.smokingHabit!.label}"));
    }
    if (vitals.isEmpty) return const SizedBox.shrink();
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ]),
        child: Column(
            children: List.generate(vitals.length * 2 - 1, (index) {
          if (index.isEven) {
            return vitals[index ~/ 2];
          } else {
            return Divider(height: 16, thickness: 1, color: Colors.grey[200]);
          }
        })));
  }

  Widget _buildVitalRow(IconData icon, String label) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 15, color: Colors.grey[800]),
                  overflow: TextOverflow.ellipsis))
        ]));
  }

  Widget _buildMediaItem(
      BuildContext context, WidgetRef ref, String url, int index) {
    bool isVideo = url.toLowerCase().contains('.mp4') ||
        url.toLowerCase().contains('.mov') ||
        url.toLowerCase().contains('.avi') ||
        url.toLowerCase().contains('.webm');
    return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
            aspectRatio: 4 / 5.5,
            child: Container(
                decoration: BoxDecoration(color: Colors.grey[200]),
                child: Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2.0, color: Color(0xAA8B5CF6))),
                      errorWidget: (context, url, error) => Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.grey[400], size: 40))),
                  if (isVideo)
                    Center(
                        child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 30))),
                  Positioned(
                      bottom: 10,
                      right: 10,
                      child: _buildSmallLikeButton(() => _showInteractionDialog(
                          context,
                          ref,
                          ContentLikeType.media,
                          index.toString(),
                          url)))
                ]))));
  }

  Widget _buildPromptItem(BuildContext context, WidgetRef ref, Prompt prompt) {
    if (prompt.answer.trim().isEmpty) return const SizedBox.shrink();
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(prompt.question.label,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600])),
                const SizedBox(height: 10),
                Text(prompt.answer,
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        color: Colors.black87,
                        height: 1.4,
                        fontWeight: FontWeight.w500))
              ])),
          const SizedBox(width: 12),
          _buildSmallLikeButton(() => _showInteractionDialog(context, ref,
              prompt.category.contentType, prompt.question.value, null))
        ]));
  }

  Widget _buildAudioItem(
      BuildContext context, WidgetRef ref, AudioPromptModel audio) {
    final audioPlayerState = ref.watch(audioPlayerStateProvider);
    final currentPlayingUrl = ref.watch(currentAudioUrlProvider);
    final playerNotifier = ref.read(audioPlayerControllerProvider.notifier);
    final bool isThisPlaying = currentPlayingUrl == audio.audioUrl &&
        audioPlayerState == AudioPlayerState.playing;
    final bool isThisLoading = currentPlayingUrl == audio.audioUrl &&
        audioPlayerState == AudioPlayerState.loading;
    final bool isThisPaused = currentPlayingUrl == audio.audioUrl &&
        audioPlayerState == AudioPlayerState.paused;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ]),
        child: Row(children: [
          InkWell(
              onTap: () {
                if (isThisLoading) return;
                if (isThisPlaying) {
                  playerNotifier.pause();
                } else if (isThisPaused) {
                  playerNotifier.resume();
                } else {
                  playerNotifier.play(audio.audioUrl);
                }
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ]),
                  child: isThisLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(
                          isThisPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28))),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(audio.prompt.label,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                Text(
                    isThisLoading
                        ? "Loading..."
                        : isThisPlaying
                            ? "Playing..."
                            : isThisPaused
                                ? "Paused"
                                : "Tap to listen",
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[600]))
              ])),
          const SizedBox(width: 16),
          _buildSmallLikeButton(() => _showInteractionDialog(
              context, ref, ContentLikeType.audioPrompt, "0", null))
        ]));
  }

  Widget _buildSmallLikeButton(VoidCallback onPressed) {
    return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
            ]),
        child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.favorite_border_rounded,
                color: Colors.pink[200], size: 22),
            tooltip: 'Like this item',
            onPressed: onPressed));
  }

  Widget _buildActionButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onPressed,
      required String tooltip,
      double size = 60.0,
      double iconSize = 30.0}) {
    return Tooltip(
        message: tooltip,
        child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 3.0,
            shadowColor: Colors.black.withOpacity(0.2),
            child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.grey.shade200, width: 1.0)),
                    child: Icon(icon, color: color, size: iconSize)))));
  }
} // End of HomeProfileCard
