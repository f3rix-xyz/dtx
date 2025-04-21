// File: lib/views/liker_profile_screen.dart
import 'dart:math'; // Import math for max function
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/liker_profile_provider.dart';
import 'package:dtx/providers/recieved_likes_provider.dart';
import 'package:dtx/repositories/like_repository.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/providers/audio_player_provider.dart'; // Import for audio player state
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/utils/app_enums.dart';

class LikerProfileScreen extends ConsumerStatefulWidget {
  final int likerUserId;

  const LikerProfileScreen({super.key, required this.likerUserId});

  @override
  ConsumerState<LikerProfileScreen> createState() => _LikerProfileScreenState();
}

class _LikerProfileScreenState extends ConsumerState<LikerProfileScreen> {
  bool _isInteracting = false; // Local state for loading indicator

  // --- Dislike Handler (Keep as is) ---
  Future<void> _handleDislike() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Dislike Profile?", style: GoogleFonts.poppins()),
        content: Text(
            "Are you sure you want to dislike this profile? They won't appear again.",
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel",
                  style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Dislike",
                  style: GoogleFonts.poppins(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isInteracting = true);
    final errorNotifier = ref.read(errorProvider.notifier)..clearError();

    try {
      final success = await ref
          .read(likeRepositoryProvider)
          .dislikeUser(dislikedUserId: widget.likerUserId);

      if (success && mounted) {
        ref.invalidate(receivedLikesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Profile disliked.", style: GoogleFonts.poppins()),
              backgroundColor: Colors.grey[700]),
        );
        Navigator.of(context).pop();
      } else if (!success && mounted) {
        if (ref.read(errorProvider) == null) {
          errorNotifier.setError(AppError.server("Failed to dislike profile."));
          _showErrorSnackbar("Failed to dislike profile.");
        }
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
  }

  // --- Like Back Handler (Keep as is) ---
  Future<void> _handleLikeBack() async {
    if (_isInteracting) return;
    if (!mounted) return;
    setState(() => _isInteracting = true);
    final errorNotifier = ref.read(errorProvider.notifier)..clearError();

    try {
      final success = await ref
          .read(likeRepositoryProvider)
          .likeBackUserProfile(likedUserId: widget.likerUserId);

      if (success && mounted) {
        ref.invalidate(receivedLikesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("It's a Match! 🎉", style: GoogleFonts.poppins()),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
        // TODO: Optionally navigate to chat screen here?
      } else if (!success && mounted) {
        if (ref.read(errorProvider) == null) {
          errorNotifier.setError(AppError.server("Failed to like back."));
          _showErrorSnackbar("Failed to like back.");
        }
      }
    } on ApiException catch (e) {
      if (mounted) errorNotifier.setError(AppError.server(e.message));
      if (e.statusCode == 409) {
        _showErrorSnackbar("You have already matched or liked this user.");
      } else {
        _showErrorSnackbar(e.message);
      }
    } catch (e) {
      if (mounted)
        errorNotifier
            .setError(AppError.generic("An unexpected error occurred."));
      _showErrorSnackbar("An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => _isInteracting = false);
    }
  }

  // --- Error Snackbar Helper (Keep as is) ---
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- Helper for FAB-style buttons (Keep as is) ---
  Widget _buildLikerActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback? onPressed,
    required String tooltip,
    double size = 60.0,
    double iconSize = 30.0,
  }) {
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton(
        heroTag: tooltip,
        onPressed: onPressed,
        backgroundColor:
            onPressed != null ? backgroundColor : Colors.grey.shade400,
        elevation: onPressed != null ? 4.0 : 0.0,
        child: Icon(
          icon,
          color: onPressed != null ? color : Colors.white70,
          size: iconSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(likerProfileProvider(widget.likerUserId));
    final profile = state.profile;
    final likeDetails = state.likeDetails;

    return Scaffold(
      backgroundColor: Colors.white,
      // --- Floating Action Buttons Row (Keep as is) ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Dislike Button (Left)
            _buildLikerActionButton(
              icon: Icons.close_rounded,
              color: Colors.red,
              backgroundColor: Colors.white,
              onPressed: _isInteracting ? null : _handleDislike,
              tooltip: "Dislike",
            ),
            // Like Back Button (Right)
            _buildLikerActionButton(
              icon: Icons.favorite_rounded,
              color: Colors.white,
              backgroundColor: const Color(0xFF8B5CF6),
              onPressed: _isInteracting ? null : _handleLikeBack,
              tooltip: "Like Back",
            ),
          ],
        ),
      ),
      body: _buildBody(context, state, profile, likeDetails, ref),
    );
  }

  Widget _buildBody(
      BuildContext context,
      LikerProfileState state,
      UserProfileData? profile,
      LikeInteractionDetails? likeDetails,
      WidgetRef ref) {
    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    if (state.error != null) {
      return _buildErrorState(context, state.error!, ref);
    }

    if (profile == null || likeDetails == null) {
      return _buildErrorState(
          context, AppError.generic("Profile data could not be loaded."), ref);
    }

    // --- START: Content Block Generation (Adapted from HomeProfileCard) ---
    final List<dynamic> contentBlocks = [];
    final mediaUrls = profile.mediaUrls ?? [];
    final prompts = profile.prompts;

    contentBlocks.add("header_section");
    contentBlocks.add("like_details_banner");
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
    // --- END: Content Block Generation ---

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          pinned: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: Colors.grey[700], size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // --- REMOVED title property ---
          // title: Text(
          //   profile.name ?? 'Profile',
          //   style:
          //       GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
          // ),
          // --- END REMOVED ---
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = contentBlocks[index];
                final double topPadding = (index == 0) ? 8.0 : 0;
                final double bottomPadding = 20.0;
                final double horizontalPadding = 12.0;
                Widget contentWidget;

                if (item is String && item == "header_section") {
                  contentWidget = _buildHeaderBlock(profile);
                } else if (item is String && item == "like_details_banner") {
                  if (likeDetails != null) {
                    contentWidget =
                        _buildLikeDetailsBanner(likeDetails, profile);
                  } else {
                    contentWidget = const SizedBox.shrink();
                  }
                } else if (item is String && item.startsWith('http')) {
                  int originalMediaIndex =
                      (profile.mediaUrls ?? []).indexOf(item);
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
              },
              childCount: contentBlocks.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
            child: SizedBox(height: 100)), // Ensure space for FABs
      ],
    );
  }

  // --- Error State Widget (unchanged) ---
  Widget _buildErrorState(BuildContext context, AppError error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 60, color: Colors.redAccent[100]),
            const SizedBox(height: 20),
            Text(
              "Oops!",
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700]),
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
              onPressed: () => ref
                  .read(likerProfileProvider(widget.likerUserId).notifier)
                  .fetchProfile(),
            ),
            const SizedBox(height: 10),
            TextButton(
              child: const Text("Go Back"),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
      ),
    );
  }

  // --- START: Copied & Adapted Helper Widgets from HomeProfileCard ---

  Widget _buildHeaderBlock(UserModel profile) {
    final age = profile.age;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${profile.name ?? 'Name'}${profile.lastName != null && profile.lastName!.isNotEmpty ? ' ${profile.lastName}' : ''}${age != null ? ' • $age' : ''}',
          style: GoogleFonts.poppins(
              fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
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
            border: Border.all(color: Colors.grey[200]!),
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
              if (isVideo)
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptItem(BuildContext context, WidgetRef ref, Prompt prompt) {
    if (prompt.answer.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
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
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, {bool subtle = false}) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: subtle ? 10 : 12, vertical: subtle ? 6 : 8),
      decoration: BoxDecoration(
        color: subtle ? Colors.transparent : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: subtle ? Colors.grey.shade400 : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: subtle ? 16 : 18,
            color: subtle ? Colors.grey.shade600 : const Color(0xFF8B5CF6),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: subtle ? 13 : 14,
                fontWeight: FontWeight.w500,
                color: subtle ? Colors.grey.shade700 : Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // --- END: Copied & Adapted Helper Widgets ---

  // --- Like Details Banner (Corrected Signature and Call) ---
  Widget _buildLikeDetailsBanner(
      LikeInteractionDetails likeDetails, UserProfileData? profile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color:
              likeDetails.isRose ? Colors.purple.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: likeDetails.isRose
                  ? Colors.purple.shade100
                  : Colors.blue.shade100)),
      child: Row(
        children: [
          Icon(
            likeDetails.isRose ? Icons.star_rounded : Icons.favorite_rounded,
            color: likeDetails.isRose
                ? Colors.purple.shade400
                : Colors.pink.shade300,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              likeDetails.likeComment != null &&
                      likeDetails.likeComment!.isNotEmpty
                  ? '"${likeDetails.likeComment}"'
                  : (likeDetails.isRose
                      ? '${profile?.name ?? "They"} sent you a Rose!'
                      : '${profile?.name ?? "They"} liked your profile!'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontStyle: (likeDetails.likeComment != null &&
                        likeDetails.likeComment!.isNotEmpty)
                    ? FontStyle.italic
                    : FontStyle.normal,
                color: likeDetails.isRose
                    ? Colors.purple.shade700
                    : Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
  // --- END Like Details Banner ---
} // End of State class
