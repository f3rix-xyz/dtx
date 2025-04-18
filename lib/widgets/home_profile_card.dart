// File: widgets/home_profile_card.dart
import 'dart:async'; // Import async
import 'dart:math';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/audio_player_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/providers/user_provider.dart'; // Import user provider
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// Function Type Definitions
typedef PerformLikeApiCall = Future<bool> Function({
  required ContentLikeType contentType,
  required String contentIdentifier,
  required LikeInteractionType interactionType,
  String? comment,
});

typedef InteractionCompleteCallback = void Function();

class HomeProfileCard extends ConsumerWidget {
  final UserModel profile;
  final PerformLikeApiCall performLikeApiCall;
  final InteractionCompleteCallback onInteractionComplete;

  const HomeProfileCard({
    super.key,
    required this.profile,
    required this.performLikeApiCall,
    required this.onInteractionComplete,
  });

  // --- METHOD TO SHOW INTERACTION DIALOG (REFINED) ---
  Future<void> _showInteractionDialog(
    BuildContext context,
    WidgetRef ref,
    ContentLikeType contentType,
    String contentIdentifier,
    String? previewImageUrl,
  ) async {
    // Use try-finally for resource cleanup (controllers, notifiers)
    final currentUserGender = ref.read(userProvider).gender;
    final isMale = currentUserGender == Gender.man;
    final FocusNode commentFocusNode = FocusNode();
    final TextEditingController commentController = TextEditingController();
    // Notifier to enable/disable buttons based on comment (for male users)
    final ValueNotifier<bool> sendLikeEnabledNotifier =
        ValueNotifier<bool>(!isMale);
    // Notifier to track if the dialog's interaction process is active (for disabling buttons)
    final ValueNotifier<bool> _isDialogInteractionActive =
        ValueNotifier<bool>(false);
    VoidCallback? listenerCallback;

    // Setup listener for comment field if user is male
    if (isMale) {
      listenerCallback = () {
        if (context.mounted && commentController.value.text != null) {
          try {
            sendLikeEnabledNotifier.value =
                commentController.text.trim().isNotEmpty;
          } catch (e) {
            // Handle potential error if notifier disposed unexpectedly
            print(
                "Error accessing sendLikeEnabledNotifier in listener (might be disposed): $e");
          }
        }
      };
      commentController.addListener(listenerCallback);
    }

    // Define the interaction handler
    Future<void> _handleInteraction(LikeInteractionType interactionType) async {
      // Prevent multiple taps if already interacting
      if (_isDialogInteractionActive.value) return;

      String comment = "";
      try {
        comment = commentController.text.trim();
      } catch (e) {
        print("Error reading commentController text: $e");
        return; // Exit if controller disposed
      }

      commentFocusNode.unfocus();
      // Small delay to allow keyboard dismissal animation
      await Future.delayed(const Duration(milliseconds: 100));

      // Set dialog interaction state to true (disables buttons)
      try {
        _isDialogInteractionActive.value = true;
      } catch (e) {
        print("Error setting _isDialogInteractionActive to true: $e");
        return;
      }

      bool success = false;
      try {
        // Call the function passed from HomeScreen (this triggers screen overlay)
        success = await performLikeApiCall(
          contentType: contentType,
          contentIdentifier: contentIdentifier,
          interactionType: interactionType,
          comment: comment.isNotEmpty ? comment : null,
        );

        // Pop dialog ONLY on successful API call completion
        // The HomeScreen overlay handles visual loading feedback.
        if (success && context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Close dialog
          onInteractionComplete(); // Notify HomeScreen to remove card
        }
      } finally {
        // Set dialog interaction state back to false (enables buttons)
        // Add checks for mounted status and notifier validity
        try {
          if (context.mounted && _isDialogInteractionActive.value) {
            _isDialogInteractionActive.value = false;
          }
        } catch (e) {
          print(
              "Error setting _isDialogInteractionActive to false (notifier disposed?): $e");
        }
      }
    } // End of _handleInteraction

    // Show the actual dialog
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true, // User can dismiss by tapping outside
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            contentPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            content: SizedBox(
              width: MediaQuery.of(dialogContext).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Preview Image or Placeholder (same as before)
                    if (previewImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Image.network(
                          previewImageUrl,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              height: 100,
                              color: Colors.grey[200],
                              child: Icon(Icons.broken_image,
                                  color: Colors.grey[400])),
                        ),
                      ),
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

                    // Comment Text Field (same as before)
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
                      ),
                      maxLength: 150,
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // --- ACTION BUTTONS ROW (MODIFIED - No Spinners) ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Send Rose Button
                        ValueListenableBuilder<bool>(
                          // Listens to comment validity for enabling
                          valueListenable: sendLikeEnabledNotifier,
                          builder: (context, isCommentValid, child) {
                            final bool roseButtonEnabled =
                                !isMale || isCommentValid;
                            // Listen also to interaction state for disabling
                            return ValueListenableBuilder<bool>(
                              valueListenable: _isDialogInteractionActive,
                              builder: (context, isInteractionActive, child) {
                                final bool effectiveEnabled =
                                    roseButtonEnabled && !isInteractionActive;
                                return OutlinedButton.icon(
                                  // REMOVED spinner icon logic
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

                        // Send Like Button
                        ValueListenableBuilder<bool>(
                          // Listens to comment validity for enabling
                          valueListenable: sendLikeEnabledNotifier,
                          builder: (context, isCommentValid, child) {
                            final bool likeButtonEnabled =
                                !isMale || isCommentValid;
                            // Listen also to interaction state for disabling
                            return ValueListenableBuilder<bool>(
                              valueListenable: _isDialogInteractionActive,
                              builder: (context, isInteractionActive, child) {
                                final bool effectiveEnabled =
                                    likeButtonEnabled && !isInteractionActive;
                                return ElevatedButton.icon(
                                  // REMOVED spinner icon logic
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
                                        fontSize: 13),
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
                    // --- END ACTION BUTTONS ROW ---

                    // Cancel Button (Disabled during interaction)
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
                                ? null // Disable cancel while interaction is happening
                                : () => Navigator.of(dialogContext).pop(),
                          );
                        }),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      // --- ENSURE CLEANUP ---
      // Remove listener safely
      if (listenerCallback != null) {
        try {
          commentController.removeListener(listenerCallback);
          listenerCallback = null; // Avoid potential duplicate removal
        } catch (e) {
          print(
              "Error removing commentController listener (already removed?): $e");
        }
      }
      // Dispose controllers and notifiers safely
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
      // --- END CLEANUP ---
    }
  } // End of _showInteractionDialog

  // --- build method and block builders (remain unchanged from previous version) ---
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<dynamic> contentBlocks = [];
    final mediaUrls = profile.mediaUrls ?? [];
    final prompts = profile.prompts;

    contentBlocks.add("header_section");
    if (mediaUrls.isNotEmpty) contentBlocks.add(mediaUrls[0]);
    if (prompts.isNotEmpty) contentBlocks.add(prompts[0]);
    contentBlocks.add("vitals_section");

    int mediaIndex = 1;
    int promptIndex = 1;
    int maxRemaining = max(mediaUrls.length, prompts.length);

    for (int i = 1; i < maxRemaining; i++) {
      if (mediaIndex < mediaUrls.length) {
        contentBlocks.add(mediaUrls[mediaIndex]);
        mediaIndex++;
      }
      if (promptIndex < prompts.length) {
        contentBlocks.add(prompts[promptIndex]);
        promptIndex++;
      }
    }
    if (profile.audioPrompt != null) {
      contentBlocks.add(profile.audioPrompt!);
    }

    return Container(
      color: Colors.white,
      child: ListView.builder(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: contentBlocks.length,
          itemBuilder: (context, index) {
            final item = contentBlocks[index];
            final double topPadding = (index == 0) ? 16.0 : 0;
            final double bottomPadding = 20.0;
            final double horizontalPadding = 12.0;
            Widget contentWidget;

            if (item is String && item == "header_section") {
              contentWidget = _buildHeaderBlock(profile);
            } else if (item is String && item.startsWith('http')) {
              int originalMediaIndex = (profile.mediaUrls ?? []).indexOf(item);
              if (originalMediaIndex == -1) originalMediaIndex = 0;
              contentWidget =
                  _buildMediaItem(context, ref, item, originalMediaIndex);
            } else if (item is Prompt) {
              contentWidget = _buildPromptItem(context, ref, item);
            } else if (item is AudioPromptModel) {
              contentWidget = _buildAudioItem(context, ref, item);
            } else if (item is String && item == "vitals_section") {
              contentWidget = _buildVitalsBlock(profile);
            } else {
              contentWidget = const SizedBox.shrink();
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding,
                  horizontalPadding, bottomPadding),
              child: contentWidget,
            );
          }),
    );
  }

  Widget _buildHeaderBlock(UserModel profile) {
    final age = profile.age;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                '${profile.name ?? 'Name'}${age != null ? ', $age' : ''}',
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ),
          ],
        ),
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
        ]
      ],
    );
  }

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
                offset: const Offset(0, 3),
              )
            ]),
        child: Column(
          children: List.generate(vitals.length * 2 - 1, (index) {
            if (index.isEven) {
              return vitals[index ~/ 2];
            } else {
              return Divider(height: 16, thickness: 1, color: Colors.grey[200]);
            }
          }),
        ));
  }

  Widget _buildVitalRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 15, color: Colors.grey[800]))),
        ],
      ),
    );
  }

  Widget _buildMediaItem(
      BuildContext context, WidgetRef ref, String url, int index) {
    bool isVideo = url.toLowerCase().contains('.mp4') ||
        url.toLowerCase().contains('.mov');

    return ClipRRect(
      borderRadius: BorderRadius.circular(10), // Consistent rounding
      child: AspectRatio(
        aspectRatio: 4 / 5.5, // Or your desired ratio
        child: Container(
          decoration: BoxDecoration(color: Colors.grey[200]), // Placeholder bg
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(url,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, prog) => prog == null
                      ? child
                      : Center(
                          child: CircularProgressIndicator(
                              value: prog.expectedTotalBytes != null
                                  ? prog.cumulativeBytesLoaded /
                                      prog.expectedTotalBytes!
                                  : null,
                              color: Colors.grey[400])),
                  errorBuilder: (ctx, err, st) => Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey[400], size: 40))),
              if (isVideo) // Show video indicator
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),
              Positioned(
                  bottom: 10,
                  right: 10,
                  child: _buildSmallLikeButton(() => _showInteractionDialog(
                        context,
                        ref,
                        ContentLikeType.media,
                        index.toString(), // Use index as identifier for media
                        url,
                      )))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptItem(BuildContext context, WidgetRef ref, Prompt prompt) {
    if (prompt.answer.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity, // Take full width
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, // White background
          borderRadius: BorderRadius.circular(10), // Rounded corners
          boxShadow: [
            // Subtle shadow
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align top
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prompt Question
                Text(prompt.question.label,
                    style: GoogleFonts.poppins(
                        fontSize: 14, // Slightly smaller question
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600])), // Subdued color
                const SizedBox(height: 10),
                // Prompt Answer
                Text(prompt.answer,
                    style: GoogleFonts.poppins(
                        fontSize: 20, // Larger answer text
                        color: Colors.black87,
                        height: 1.4, // Line height
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 12), // Spacing before button
          // Like Button
          _buildSmallLikeButton(() => _showInteractionDialog(
                context,
                ref,
                prompt.category.contentType, // Get type from category
                prompt.question.value, // Use question enum value as identifier
                null, // No image preview for prompts
              )),
        ],
      ),
    );
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
          borderRadius: BorderRadius.circular(16), // More rounded
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
      child: Row(
        children: [
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
                ],
              ),
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
                      size: 28,
                    ),
            ),
          ),
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
                        fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildSmallLikeButton(() => _showInteractionDialog(
                context,
                ref,
                ContentLikeType.audioPrompt,
                "0", // API requires "0" for audio prompts
                null,
              )),
        ],
      ),
    );
  }

  Widget _buildSmallLikeButton(VoidCallback onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          color: Colors.white, // White background
          shape: BoxShape.circle,
          boxShadow: [
            // Subtle shadow
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
          ]),
      child: IconButton(
        padding: EdgeInsets.zero, // Remove default padding
        icon: Icon(Icons.favorite_border_rounded,
            color: Colors.pink[200], // Soft pink color
            size: 22), // Icon size
        tooltip: 'Like this item',
        onPressed: onPressed,
      ),
    );
  }
} // End of HomeProfileCard
