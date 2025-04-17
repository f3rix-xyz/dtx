// File: widgets/home_profile_card.dart
import 'dart:math';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/audio_player_provider.dart'; // Ensure this is imported
// Removed auth provider/model imports from here - check should be in HomeScreen
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/providers/user_provider.dart'; // Needed for gender check
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

  // --- METHOD TO SHOW INTERACTION DIALOG ---
  Future<void> _showInteractionDialog(
    BuildContext context,
    WidgetRef ref, // Keep ref for gender check etc.
    ContentLikeType contentType,
    String contentIdentifier,
    String? previewImageUrl,
  ) async {
    // --- No Auth Status Check HERE ---
    // The check is now done in HomeScreen's _callLikeRepository callback

    // --- Variables with late final and FocusNode ---
    final currentUserGender = ref.read(userProvider).gender;
    final isMale = currentUserGender == Gender.man;
    // Use late final to ensure they are initialized before use within showDialog
    // Introduce a FocusNode
    final FocusNode commentFocusNode = FocusNode();
    late final TextEditingController commentController;
    late final ValueNotifier<bool> sendLikeEnabledNotifier;
    VoidCallback? listenerCallback;

    // Initialize controllers immediately before showDialog
    commentController = TextEditingController();
    sendLikeEnabledNotifier = ValueNotifier<bool>(!isMale);

    // --- Only add listener if male ---
    if (isMale) {
      listenerCallback = () {
        // Check mounted *inside* listener to be safe
        if (context.mounted) {
          try {
            // Check if controller/notifier are still valid
            if (commentController.text.trim().isNotEmpty !=
                sendLikeEnabledNotifier.value) {
              sendLikeEnabledNotifier.value =
                  commentController.text.trim().isNotEmpty;
            }
          } catch (e) {
            // This catch block handles the case where the controller might be disposed
            // during the listener callback execution (less likely now but good practice).
            print("Error accessing controller/notifier in listener: $e");
          }
        }
      };
      // Use null assertion operator (!) as we are sure it's assigned here
      commentController.addListener(listenerCallback!);
    }
    // --- End listener addition ---

    Future<void> _handleInteraction(LikeInteractionType interactionType) async {
      String comment = "";
      try {
        comment = commentController.text.trim();
      } catch (e) {
        print("Error reading commentController text: $e");
        // Optionally return or show error if controller is already disposed
        return;
      }

      // --- FIX: Unfocus before calling API/Popping ---
      // Use the FocusNode created earlier
      commentFocusNode.unfocus();
      // Give a very brief moment for unfocus to process before proceeding
      await Future.delayed(const Duration(milliseconds: 50));
      // --- END FIX ---

      // --- Call the callback FIRST ---
      bool success = await performLikeApiCall(
        contentType: contentType,
        contentIdentifier: contentIdentifier,
        interactionType: interactionType,
        comment: comment.isNotEmpty ? comment : null,
      );

      // --- Pop the dialog ONLY if the interaction was successful ---
      if (success && context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (e) {
          print("Error popping dialog: $e");
          if (context.mounted) Navigator.of(context).pop();
        }
        onInteractionComplete();
      }
      // If !success, the dialog remains open. HomeScreen handles other dialogs/errors.
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        // Use a different context name inside builder
        return AlertDialog(
          contentPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          content: SizedBox(
            // Constrain width
            width: MediaQuery.of(dialogContext).size.width * 0.8,
            child: SingleChildScrollView(
              // Make content scrollable if needed
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Preview Image (optional)
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

                  // Comment Text Field with FocusNode
                  TextField(
                    controller: commentController,
                    focusNode: commentFocusNode, // Assign the focus node
                    decoration: InputDecoration(
                      hintText: "Add a comment...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
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

                  // Action Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Send Rose Button
                      OutlinedButton.icon(
                        icon: Icon(Icons.star_rounded,
                            color: Colors.purple.shade300),
                        label: Text(
                          "Send Rose",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: Colors.purple.shade400,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple.shade400,
                          side: BorderSide(color: Colors.purple.shade100),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                        ),
                        onPressed: () =>
                            _handleInteraction(LikeInteractionType.rose),
                      ),
                      // Send Like Button (with ValueListenableBuilder)
                      ValueListenableBuilder<bool>(
                        valueListenable: sendLikeEnabledNotifier,
                        builder: (context, isEnabled, child) {
                          return ElevatedButton.icon(
                            icon: Icon(
                              Icons.favorite_rounded,
                              color: isEnabled
                                  ? Colors.white
                                  : Colors.grey.shade400,
                              size: 18,
                            ),
                            label: Text(
                              "Send Like",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: isEnabled
                                      ? Colors.white
                                      : Colors.grey.shade500,
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEnabled
                                  ? Colors.pink.shade300
                                  : Colors.grey.shade200,
                              disabledBackgroundColor: Colors.grey.shade200,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              elevation: isEnabled ? 2 : 0,
                            ),
                            onPressed: isEnabled
                                ? () => _handleInteraction(
                                    LikeInteractionType.standard)
                                : null,
                          );
                        },
                      ),
                    ],
                  ),
                  // Cancel Button
                  TextButton(
                    child: Text("Cancel",
                        style: GoogleFonts.poppins(color: Colors.grey)),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      // --- Disposal Logic ---
      // Always try to remove listener if it was potentially added
      if (listenerCallback != null) {
        try {
          commentController.removeListener(listenerCallback!);
          listenerCallback = null;
        } catch (e) {}
      }
      // Always dispose controllers/notifiers/focus node safely
      try {
        sendLikeEnabledNotifier.dispose();
      } catch (e) {}
      try {
        commentController.dispose();
      } catch (e) {}
      try {
        commentFocusNode.dispose();
      } catch (e) {} // Dispose the focus node
    });
  }
  // --- END INTERACTION DIALOG METHOD ---

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- Content Block Preparation ---
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
    // --- End Content Block Preparation ---

    // --- Build the ListView ---
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
              contentWidget = _buildAudioItem(
                  context, ref, item); // Calls the updated builder
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

  // --- Block Builder Widgets (remain the same) ---
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
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.more_horiz, color: Colors.grey[500]),
              onPressed: () {/* TODO: Implement report/block */},
              iconSize: 30,
              splashRadius: 20,
            )
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
          Icons.local_bar_outlined, profile.drinkingHabit!.label));
    }
    if (profile.smokingHabit != null) {
      vitals.add(_buildVitalRow(
          Icons.smoking_rooms_outlined, profile.smokingHabit!.label));
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 4 / 5.5,
        child: Container(
          decoration: BoxDecoration(color: Colors.grey[200]),
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
              Positioned(
                  bottom: 10,
                  right: 10,
                  child: _buildSmallLikeButton(() => // Pass context/ref here
                      _showInteractionDialog(
                        context, // Use context from builder
                        ref, // Use ref from builder
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
    if (prompt.answer.trim().isEmpty)
      return const SizedBox.shrink(); // Check if prompt answer is empty
    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildSmallLikeButton(() => // Pass context/ref here
              _showInteractionDialog(
                context, // Use context from builder
                ref, // Use ref from builder
                prompt.category.contentType, // Use correct ContentLikeType
                prompt.question.value, // Use question value as identifier
                null,
              )),
        ],
      ),
    );
  }

  Widget _buildAudioItem(
      BuildContext context, WidgetRef ref, AudioPromptModel audio) {
    final audioState = ref.watch(audioPlayerStateProvider);
    final currentPlayerUrl = ref.watch(currentAudioUrlProvider);
    final bool isThisPlaying = currentPlayerUrl == audio.audioUrl &&
        audioState == AudioPlayerState.playing;
    final bool isThisLoading = currentPlayerUrl == audio.audioUrl &&
        audioState == AudioPlayerState.loading;
    final bool isThisPaused = currentPlayerUrl == audio.audioUrl &&
        audioState == AudioPlayerState.paused;

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
      child: Row(
        children: [
          InkWell(
            onTap: () {
              if (isThisLoading) return;
              final playerNotifier =
                  ref.read(audioPlayerControllerProvider.notifier);
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
                        size: 28)),
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
          _buildSmallLikeButton(() => // Pass context/ref here
              _showInteractionDialog(
                context, // Use context from builder
                ref, // Use ref from builder
                ContentLikeType.audioPrompt,
                audio.prompt.value,
                null,
              )),
        ],
      ),
    );
  }

  // --- Like Button Helper ---
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
        onPressed: onPressed,
      ),
    );
  }
} // End of HomeProfileCard
