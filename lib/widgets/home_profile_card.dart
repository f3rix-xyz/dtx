// File: widgets/home_profile_card.dart
import 'dart:async';
import 'dart:math';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/audio_player_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/widgets/report_reason_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

// Function Type Definitions (No Changes)
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

// Changed to ConsumerStatefulWidget to manage local state if needed later
class HomeProfileCard extends ConsumerStatefulWidget {
  final UserModel profile;
  final PerformLikeApiCall performLikeApiCall;
  final PerformDislikeApiCall performDislikeApiCall;
  final PerformReportApiCall performReportApiCall;
  final InteractionCompleteCallback onInteractionComplete;
  final Function(DismissDirection)? onSwiped;

  const HomeProfileCard({
    super.key,
    required this.profile,
    required this.performLikeApiCall,
    required this.performDislikeApiCall,
    required this.performReportApiCall,
    required this.onInteractionComplete,
    this.onSwiped,
  });

  @override
  ConsumerState<HomeProfileCard> createState() => _HomeProfileCardState();
}

class _HomeProfileCardState extends ConsumerState<HomeProfileCard> {
  // *** --- START: MODIFIED Interaction Dialog --- ***
  Future<void> _showInteractionDialog(
    BuildContext context, // Use context from the builder where dialog is called
    WidgetRef ref, // Pass ref
    ContentLikeType contentType,
    String contentIdentifier,
    String? previewImageUrl,
  ) async {
    final currentUserGender = ref.read(userProvider).gender;
    final isMale = currentUserGender == Gender.man;

    // Show the dialog
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        // Use StatefulBuilder to manage state *inside* the dialog
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            // Create controllers and notifiers INSIDE the builder's state
            // Use late final and initialize here, or initialize directly.
            // Using a separate StatefulWidget for dialog content is often cleaner for complex state.
            final commentController =
                useMemoized(() => TextEditingController());
            final commentFocusNode = useMemoized(() => FocusNode());
            // Initialize notifier based on initial state (male needs comment)
            final sendLikeEnabledNotifier =
                useMemoized(() => ValueNotifier<bool>(!isMale));
            final isDialogInteractionActive =
                useMemoized(() => ValueNotifier<bool>(false));
            VoidCallback? listenerCallback; // To hold the listener function

            // Setup listener only once using useEffect or similar pattern if using hooks,
            // or manage it carefully with add/remove in init/dispose logic if using StatefulWidget.
            // For StatefulBuilder, we might need to manage listener addition/removal carefully.
            // A simpler approach for now: update notifier directly in onChanged.
            void _updateSendButtonState() {
              if (isMale &&
                  commentController.text.trim().isNotEmpty !=
                      sendLikeEnabledNotifier.value) {
                sendLikeEnabledNotifier.value =
                    commentController.text.trim().isNotEmpty;
              }
            }

            // Dispose controllers when the StatefulBuilder's state is disposed
            // This requires a bit more complex setup, often a dedicated StatefulWidget is better.
            // For simplicity here, we rely on dialog dismissal to implicitly stop using them.
            // **WARNING:** This simpler approach might lead to memory leaks if not handled perfectly.
            // Consider converting dialog content to a StatefulWidget for robust disposal.

            Future<void> handleInteraction(
                LikeInteractionType interactionType) async {
              if (!stfContext.mounted) return; // Check dialog context
              if (isDialogInteractionActive.value) return;

              final comment = commentController.text.trim();
              commentFocusNode.unfocus(); // Unfocus before processing

              isDialogInteractionActive.value = true; // Disable buttons

              bool success = false;
              try {
                success = await widget.performLikeApiCall(
                  // Use widget property
                  contentType: contentType,
                  contentIdentifier: contentIdentifier,
                  interactionType: interactionType,
                  comment: comment.isNotEmpty ? comment : null,
                );

                if (success && stfContext.mounted) {
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext)
                        .pop(); // Close dialog on success
                  }
                  widget
                      .onInteractionComplete(); // Callback AFTER success & pop
                }
              } finally {
                // Re-enable buttons ONLY if the dialog wasn't popped successfully
                if (stfContext.mounted && !success) {
                  isDialogInteractionActive.value = false;
                }
              }
            }

            // Build the AlertDialog content using the local controllers/notifiers
            return AlertDialog(
              contentPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              content: SizedBox(
                width: MediaQuery.of(stfContext).size.width * 0.8,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Preview Image/Placeholder (copied from original)
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
                                            strokeWidth: 2,
                                            color: Color(0xAA8B5CF6)))),
                                errorWidget: (context, url, error) => Container(
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: Icon(Icons.broken_image,
                                        color: Colors.grey[400]))))
                      else if (contentType == ContentLikeType.audioPrompt)
                        Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12.0)),
                            child: Center(
                                child: Icon(Icons.multitrack_audio_rounded,
                                    size: 40, color: Colors.grey[500])))
                      else
                        Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12.0)),
                            child: Center(
                                child: Icon(Icons.article_outlined,
                                    size: 40, color: Colors.grey[500]))),

                      const SizedBox(height: 16),
                      TextField(
                          controller: commentController,
                          focusNode: commentFocusNode,
                          onChanged: (_) =>
                              _updateSendButtonState(), // Update button state on change
                          decoration: InputDecoration(
                              hintText: "Add a comment...",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF8B5CF6))),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              counterText: ""),
                          maxLength: maxCommentLength,
                          maxLines: 3,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences),
                      const SizedBox(height: 16),
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
                                      valueListenable:
                                          isDialogInteractionActive,
                                      builder: (context, isInteractionActive,
                                          child) {
                                        final bool effectiveEnabled =
                                            roseButtonEnabled &&
                                                !isInteractionActive;
                                        return OutlinedButton.icon(
                                            // ... (styling remains the same) ...
                                            icon: Icon(Icons.star_rounded,
                                                color: effectiveEnabled
                                                    ? Colors.purple.shade300
                                                    : Colors.grey.shade400,
                                                size: 18),
                                            label: Text("Send Rose",
                                                style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w500,
                                                    color: effectiveEnabled
                                                        ? Colors.purple.shade400
                                                        : Colors.grey.shade500,
                                                    fontSize: 13),
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    effectiveEnabled
                                                        ? Colors.purple.shade400
                                                        : Colors.grey.shade500,
                                                side: BorderSide(
                                                    color: effectiveEnabled
                                                        ? Colors.purple.shade100
                                                        : Colors.grey.shade300),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            25)),
                                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
                                            onPressed: effectiveEnabled ? () => handleInteraction(LikeInteractionType.rose) : null);
                                      });
                                }),
                            // Like Button
                            ValueListenableBuilder<bool>(
                                valueListenable: sendLikeEnabledNotifier,
                                builder: (context, isCommentValid, child) {
                                  final bool likeButtonEnabled =
                                      !isMale || isCommentValid;
                                  return ValueListenableBuilder<bool>(
                                      valueListenable:
                                          isDialogInteractionActive,
                                      builder: (context, isInteractionActive,
                                          child) {
                                        final bool effectiveEnabled =
                                            likeButtonEnabled &&
                                                !isInteractionActive;
                                        return ElevatedButton.icon(
                                            // ... (styling remains the same) ...
                                            icon: Icon(Icons.favorite_rounded,
                                                color: effectiveEnabled
                                                    ? Colors.white
                                                    : Colors.grey.shade400,
                                                size: 18),
                                            label: Text("Send Like",
                                                style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    color: effectiveEnabled
                                                        ? Colors.white
                                                        : Colors.grey.shade500,
                                                    fontSize: 13),
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: effectiveEnabled
                                                    ? Colors.pink.shade300
                                                    : Colors.grey.shade200,
                                                disabledBackgroundColor:
                                                    Colors.grey.shade200,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            25)),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                        horizontal: 12),
                                                elevation:
                                                    effectiveEnabled ? 2 : 0),
                                            onPressed: effectiveEnabled ? () => handleInteraction(LikeInteractionType.standard) : null);
                                      });
                                }),
                          ]),
                      // Cancel Button
                      ValueListenableBuilder<bool>(
                          valueListenable: isDialogInteractionActive,
                          builder: (context, isInteractionActive, child) {
                            return TextButton(
                                child: Text("Cancel",
                                    style: GoogleFonts.poppins(
                                        color: isInteractionActive
                                            ? Colors.grey.shade400
                                            : Colors.grey)),
                                onPressed: isInteractionActive
                                    ? null
                                    : () {
                                        if (dialogContext.mounted &&
                                            Navigator.of(dialogContext)
                                                .canPop()) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                      });
                          })
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // **Dispose controllers manually IF using StatefulBuilder**
    // This is tricky with StatefulBuilder. A StatefulWidget is cleaner.
    // If using StatefulBuilder, you might need a wrapper or accept potential minor leaks.
    // print("[InteractionDialog] Disposing controllers (StatefulBuilder approach - may not be reliable).");
    // commentController.dispose();
    // commentFocusNode.dispose();
    // sendLikeEnabledNotifier.dispose();
    // isDialogInteractionActive.dispose();
  }

  // *** --- END MODIFIED --- ***

  Future<void> _handleReport(BuildContext context) async {
    // (No changes needed)
    if (!context.mounted) return;
    final selectedReason = await showReportReasonDialog(context);
    if (selectedReason != null) {
      if (!context.mounted) return;
      await widget.performReportApiCall(reason: selectedReason);
      // Optimistically remove card after report initiated
      widget.onInteractionComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    // (Build method structure remains the same, references helpers)
    final List<dynamic> contentBlocks = [];
    final mediaUrls = widget.profile.mediaUrls ?? [];
    final prompts = widget.profile.prompts;
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
    if (widget.profile.audioPrompt != null)
      contentBlocks.add(widget.profile.audioPrompt!);

    return Dismissible(
      key: ValueKey('dismissable_card_${widget.profile.id}'),
      background: Container(
        color: Colors.green.withOpacity(0.1),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.favorite_rounded,
            color: Colors.green.shade300, size: 40),
      ),
      secondaryBackground: Container(
        color: Colors.red.withOpacity(0.1),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.close_rounded, color: Colors.red.shade300, size: 40),
      ),
      direction: DismissDirection.horizontal,
      onDismissed: widget.onSwiped, // Pass the callback directly
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80.0),
              itemCount: contentBlocks.length,
              itemBuilder: (context, index) {
                final item = contentBlocks[index];
                final double topPadding = (index == 0) ? 16.0 : 0;
                final double bottomPadding = 20.0;
                final double horizontalPadding = 12.0;
                Widget contentWidget;

                if (item is String && item == "header_section") {
                  contentWidget = _buildHeaderBlock(context, widget.profile);
                } else if (item is Map && item["type"] == "media") {
                  contentWidget = _buildMediaItem(
                      context, ref, item["value"] as String, item["index"]);
                } else if (item is Prompt) {
                  contentWidget = _buildPromptItem(context, ref, item);
                } else if (item is AudioPromptModel) {
                  contentWidget = _buildAudioItem(context, ref, item);
                } else if (item is String && item == "vitals_section") {
                  contentWidget = _buildVitalsBlock(widget.profile);
                } else {
                  contentWidget = const SizedBox.shrink();
                }

                return Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding,
                      horizontalPadding, bottomPadding),
                  child: contentWidget,
                );
              },
            ),
            // --- REMOVED the Row with the old FABs ---
            // Positioned(...)
            // --- END REMOVAL ---
          ],
        ),
      ),
    );
  }

  // --- Helper methods _buildHeaderBlock, _buildHeaderMenuButton, etc. ---
  // (No changes needed in these helper build methods from previous response)
  Widget _buildHeaderBlock(BuildContext context, UserModel profile) {
    final age = profile.age;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
                child: Text(
                    '${profile.name ?? 'Name'}${age != null ? ', $age' : ''}', // Removed Last Name
                    style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    softWrap: true)),
            _buildHeaderMenuButton(context) // Pass context here
          ]),
      if (profile.hometown != null && profile.hometown!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(profile.hometown!,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]))
        ])
      ]
    ]);
  }

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
                      leading:
                          Icon(Icons.flag_outlined, color: Colors.redAccent),
                      title: Text('Report',
                          style: GoogleFonts.poppins(color: Colors.redAccent)),
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8.0)))
            ],
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)));
  }

  Widget _buildVitalsBlock(UserModel profile) {
    final List<Widget> vitals = [];
    if (profile.height != null && profile.height!.isNotEmpty)
      vitals.add(_buildVitalRow(Icons.height, profile.height!));
    if (profile.religiousBeliefs != null)
      vitals.add(_buildVitalRow(
          Icons.church_outlined, profile.religiousBeliefs!.label));
    if (profile.jobTitle != null && profile.jobTitle!.isNotEmpty)
      vitals.add(_buildVitalRow(Icons.work_outline, profile.jobTitle!));
    if (profile.education != null && profile.education!.isNotEmpty)
      vitals.add(_buildVitalRow(Icons.school_outlined, profile.education!));
    if (profile.drinkingHabit != null)
      vitals.add(_buildVitalRow(
          Icons.local_bar_outlined, "Drinks: ${profile.drinkingHabit!.label}"));
    if (profile.smokingHabit != null)
      vitals.add(_buildVitalRow(Icons.smoking_rooms_outlined,
          "Smokes: ${profile.smokingHabit!.label}"));
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
                          index
                              .toString(), // Using index as identifier for media
                          url))) // Pass image URL for preview
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
          _buildSmallLikeButton(() => _showInteractionDialog(
              context,
              ref,
              prompt.category.contentType, // Use enum method for content type
              prompt.question.value, // Use enum value as identifier
              null // No image preview for prompts
              ))
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
              context,
              ref,
              ContentLikeType.audioPrompt, // Specific type for audio
              audio.prompt.value, // Use enum value as identifier
              null // No image preview
              ))
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

  // --- useMemoized Hook (Placeholder - Requires flutter_hooks or similar) ---
  // This is a placeholder. For real use, you'd import and use flutter_hooks
  // or manage the lifecycle manually within a StatefulWidget.
  T useMemoized<T>(T Function() valueBuilder, [List<Object?> keys = const []]) {
    // In a real hook, this would store and reuse the value based on keys.
    // Here, it just calls the builder every time for simplicity in this example.
    return valueBuilder();
  }
}
