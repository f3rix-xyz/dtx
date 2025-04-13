// File: widgets/home_profile_card.dart
import 'dart:math'; // Needed for interleaving logic

import 'package:dtx/models/user_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/audio_player_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// Function Type Definitions
typedef LikeContentCallback = void Function(
    ContentLikeType type, String identifier, String? comment);
typedef SendRoseCallback = void Function(String? comment);

class HomeProfileCard extends ConsumerWidget {
  final UserModel profile;
  final LikeContentCallback onLikeContent;
  final SendRoseCallback onSendRose;

  const HomeProfileCard({
    super.key,
    required this.profile,
    required this.onLikeContent,
    required this.onSendRose,
  });

  // Helper to trigger standard like with comment dialog
  void _triggerStandardLike(BuildContext context, WidgetRef ref,
      ContentLikeType contentType, String contentIdentifier) async {
    print(
        "[HomeProfileCard] Standard Like tapped for $contentType:$contentIdentifier");

    final currentUser = ref.read(userProvider);
    final bool isMale = currentUser.gender == Gender.man;
    print(
        "[HomeProfileCard] Current user gender: ${currentUser.gender?.value ?? 'Unknown'}, IsMale: $isMale");

    String? comment;
    bool proceedWithLike = false;

    comment = await _showCommentDialog(context, isOptional: !isMale);

    if (isMale) {
      if (comment != null && comment.trim().isNotEmpty) {
        proceedWithLike = true;
        print("[HomeProfileCard] Male user provided required comment.");
      } else {
        print(
            "[HomeProfileCard] Male user cancelled or left comment empty. Like aborted.");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('A comment is required to send a like.',
                    style: GoogleFonts.poppins()),
                backgroundColor: Colors.orange[700]),
          );
        }
      }
    } else {
      proceedWithLike = true;
      print(
          "[HomeProfileCard] Non-male user like attempt. Comment: ${comment ?? 'None'}. Proceeding.");
    }

    if (proceedWithLike) {
      onLikeContent(contentType, contentIdentifier, comment);
    }
  }

  // Comment Dialog (Keep as is)
  Future<String?> _showCommentDialog(BuildContext context,
      {bool isOptional = false}) async {
    final TextEditingController commentController = TextEditingController();
    String title =
        isOptional ? "Add a Comment? (Optional)" : "Add a Comment (Required)";
    ValueNotifier<bool> sendEnabledNotifier = ValueNotifier<bool>(isOptional);

    if (!isOptional) {
      commentController.addListener(() {
        if (context.mounted) {
          sendEnabledNotifier.value = commentController.text.trim().isNotEmpty;
        }
      });
    }

    return showDialog<String>(
      context: context,
      barrierDismissible: isOptional,
      builder: (BuildContext dialogContext) {
        /* ... AlertDialog ... */ return AlertDialog(
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
              if (isOptional) {
                sendEnabledNotifier.value = true;
              } else {
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
                          color:
                              isEnabled ? const Color(0xFF8B5CF6) : Colors.grey,
                          fontWeight: FontWeight.w600)),
                  onPressed: isEnabled
                      ? () => Navigator.of(dialogContext)
                          .pop(commentController.text.trim())
                      : null,
                );
              },
            ),
          ],
        );
      },
    ).whenComplete(() {
      try {
        if (!isOptional) commentController.removeListener(() {});
      } catch (e) {}
      sendEnabledNotifier.dispose();
      commentController.dispose();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- Prepare the list of content blocks with specific ordering ---
    final List<dynamic> contentBlocks = [];
    final mediaUrls = profile.mediaUrls ?? [];
    final prompts = profile.prompts;

    // 1. Header
    contentBlocks.add("header_section");

    // 2. First Photo (if available)
    if (mediaUrls.isNotEmpty) {
      contentBlocks.add(mediaUrls[0]);
    }

    // 3. First Prompt (if available)
    if (prompts.isNotEmpty) {
      contentBlocks.add(prompts[0]);
    }

    // 4. Vitals Section
    contentBlocks.add("vitals_section");

    // 5. Interleave remaining media and prompts
    int mediaIndex = 1;
    int promptIndex = 1;
    int maxRemaining = max(mediaUrls.length, prompts.length);

    for (int i = 1; i < maxRemaining; i++) {
      // Start loop from 1 (second item)
      if (mediaIndex < mediaUrls.length) {
        contentBlocks.add(mediaUrls[mediaIndex]);
        mediaIndex++;
      }
      if (promptIndex < prompts.length) {
        contentBlocks.add(prompts[promptIndex]);
        promptIndex++;
      }
    }

    // 6. Add Audio Prompt (if available) at the end or interleaved earlier if preferred
    if (profile.audioPrompt != null) {
      contentBlocks.add(profile.audioPrompt!);
    }
    // --- End Content Block Preparation ---

    // --- Build the ListView ---
    return Container(
      // Add a container to handle background color if needed
      color: Colors.white, // Set background color for the whole scrolling area
      child: ListView.builder(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.zero, // Remove ListView padding
          itemCount: contentBlocks.length,
          itemBuilder: (context, index) {
            final item = contentBlocks[index];

            // Apply consistent horizontal padding and variable vertical padding
            final double topPadding = (index == 0) ? 16.0 : 0;
            final double bottomPadding =
                20.0; // Consistent spacing between blocks
            final double horizontalPadding = 12.0;

            Widget contentWidget;

            // Build content based on type
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

            // Wrap content with Padding
            return Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding,
                  horizontalPadding, bottomPadding),
              child: contentWidget,
            );
          }),
    );
  }

  // --- Block Builder Widgets ---

  Widget _buildHeaderBlock(UserModel profile) {
    final age = profile.age;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start, // Align top
          children: [
            // Use Flexible for text to allow wrapping and prevent overflow
            Flexible(
              child: Text(
                '${profile.name ?? 'Name'}${age != null ? ', $age' : ''}',
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                //  overflow: TextOverflow.ellipsis, // Removed ellipsis for potential wrapping
              ),
            ),
            IconButton(
              // More options button
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.more_horiz, color: Colors.grey[500]),
              onPressed: () {/* TODO: Implement report/block */},
              iconSize: 30, // Slightly larger
              splashRadius: 20,
            )
          ],
        ),
        // Add other header info like location/job if desired
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

  Widget _buildMediaItem(
      BuildContext context, WidgetRef ref, String url, int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10), // Consistent rounding
      child: AspectRatio(
        aspectRatio: 4 / 5.5,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                /* loading/error */
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
                        color: Colors.grey[400], size: 40)),
              ),
              Positioned(
                  bottom: 10,
                  right: 10,
                  child: _buildSmallLikeButton(() => _triggerStandardLike(
                      context, ref, ContentLikeType.media, index.toString())))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptItem(BuildContext context, WidgetRef ref, Prompt prompt) {
    return Container(
      padding: const EdgeInsets.all(20), // More padding
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt.question.label,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                Text(
                  prompt.answer,
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: Colors.black87,
                      height: 1.4,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ), // Larger answer font
          const SizedBox(width: 12),
          _buildSmallLikeButton(() => _triggerStandardLike(context, ref,
              prompt.category.contentType, prompt.question.value)),
        ],
      ),
    );
  }

  Widget _buildAudioItem(
      BuildContext context, WidgetRef ref, AudioPromptModel audio) {
    final audioState = ref.watch(audioPlayerControllerProvider);
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
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            audio.prompt.label,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                onTap: () {
                  /* Play/Pause Logic */ if (isThisLoading) return;
                  final playerNotifier =
                      ref.read(audioPlayerControllerProvider.notifier);
                  if (isThisPlaying)
                    playerNotifier.pause();
                  else if (isThisPaused)
                    playerNotifier.resume();
                  else
                    playerNotifier.play(audio.audioUrl);
                },
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                      color: Colors.grey[100], shape: BoxShape.circle),
                  child: isThisLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.grey))
                      : Icon(
                          isThisPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.grey[800],
                          size: 30),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 4,
                  color: Colors.grey[300],
                ),
              ), // Simple line for waveform
              const SizedBox(width: 16),
              _buildSmallLikeButton(() => _triggerStandardLike(
                  context, ref, ContentLikeType.audioPrompt, "0")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsBlock(UserModel profile) {
    final List<Widget> vitals = [];
    // Add checks and build _buildVitalRow for each available vital
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
    // Add more vitals as needed

    if (vitals.isEmpty) return const SizedBox.shrink();

    return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12), // Less vertical padding
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
        // Use Column with dividers instead of Wrap
        child: Column(
          children: List.generate(vitals.length * 2 - 1, (index) {
            if (index.isEven) {
              return vitals[index ~/ 2];
            } else {
              return Divider(
                  height: 16,
                  thickness: 1,
                  color: Colors.grey[200]); // Add dividers
            }
          }),
        ));
  }

  // New Helper for individual vital rows
  Widget _buildVitalRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0), // Spacing for rows
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
              // Allow text to wrap if needed
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 15, color: Colors.grey[800]))),
        ],
      ),
    );
  }

  // Helper for the small like buttons within blocks
  Widget _buildSmallLikeButton(VoidCallback onPressed) {
    return Container(
      width: 40, height: 40, // Smaller size
      decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
          ]),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.favorite_border_rounded,
            color: Colors.pink[200], size: 22), // Adjusted color/size
        tooltip: 'Like this item',
        onPressed: onPressed,
      ),
    );
  }
} // End of HomeProfileCard
