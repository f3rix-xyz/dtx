// File: views/profile_screens.dart
import 'dart:math'; // Needed for interleaving logic

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart'; // Keep for local player

import 'package:dtx/models/user_model.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // --- Retained State for Local Audio Player ---
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentAudioUrl;
  // --- End Retained State ---

  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    // Fetching initiated in MainNavigationScreen initState

    // --- Retained Audio Player Listeners ---
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          // Reset URL if stopped/completed unexpectedly
          if (state == PlayerState.stopped || state == PlayerState.completed) {
            _currentAudioUrl = null;
          }
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentAudioUrl = null; // Reset URL on completion
        });
      }
    });
    // --- End Retained Listeners ---
  }

  @override
  void dispose() {
    try {
      // Stop and dispose the local audio player
      if (_audioPlayer.state == PlayerState.playing ||
          _audioPlayer.state == PlayerState.paused) {
        _audioPlayer.stop();
      }
      _audioPlayer.dispose();
    } catch (e) {
      print("Error stopping/disposing audio player: $e");
    }
    _pageController.dispose();
    super.dispose();
  }

  // --- Retained Local Audio Control ---
  Future<void> _playOrPauseAudio(String audioUrl) async {
    if (!mounted) return;

    try {
      final currentState = _audioPlayer.state;

      if (currentState == PlayerState.playing && _currentAudioUrl == audioUrl) {
        await _audioPlayer.pause();
      } else if (currentState == PlayerState.paused &&
          _currentAudioUrl == audioUrl) {
        await _audioPlayer.resume();
      } else {
        // Stop any previously playing audio before starting new
        if (currentState == PlayerState.playing ||
            currentState == PlayerState.paused) {
          await _audioPlayer.stop();
        }
        // Play the new URL
        await _audioPlayer.play(UrlSource(audioUrl));
        if (mounted) {
          setState(() {
            _currentAudioUrl =
                audioUrl; // Update current URL only when playing starts
          });
        }
      }
    } catch (e) {
      print("Error playing/pausing audio: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error playing audio: ${e.toString()}')));
        setState(() {
          _isPlaying = false;
          _currentAudioUrl = null;
        });
      }
    }
  }
  // --- End Retained Local Audio Control ---

  // --- Helper Methods (some adapted from HomeProfileCard) ---

  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Widget _buildTopIconButton(
      {required IconData icon,
      required String tooltip,
      required VoidCallback onPressed}) {
    // (Keep this helper as is)
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
      ),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildEmptySection(String title, String message, IconData icon) {
    // (Keep this helper as is)
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800])),
          ),
          Icon(icon, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, {bool subtle = false}) {
    // (Keep this helper as is)
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: subtle ? Colors.transparent : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: subtle ? Colors.grey.shade400 : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: subtle ? 16 : 18,
              color: subtle ? Colors.grey.shade600 : const Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: subtle ? 13 : 14,
                    fontWeight: FontWeight.w500,
                    color: subtle ? Colors.grey.shade700 : Colors.grey[800]),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isLoading = ref.watch(userLoadingProvider);

    // --- Loading State ---
    if (isLoading && user.name == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text("Profile",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            // Keep actions visible but disabled during load
            _buildTopIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit Profile',
                onPressed: () {}),
            const SizedBox(width: 8),
            _buildTopIconButton(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onPressed: () {}),
            const SizedBox(width: 8),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    // --- Prepare Content Blocks (Logic from HomeProfileCard) ---
    final List<dynamic> contentBlocks = [];
    final mediaUrls = user.mediaUrls ?? [];
    final prompts = user.prompts;

    // 1. Header
    contentBlocks.add("header_section");

    // 2. First Photo (if available)
    if (mediaUrls.isNotEmpty) {
      contentBlocks.add(mediaUrls[0]);
    } else {
      // Add empty section if no photos
      contentBlocks.add("empty_media_section");
    }

    // 3. First Prompt (if available)
    if (prompts.isNotEmpty) {
      contentBlocks.add(prompts[0]);
    } else {
      // Add empty section if no prompts
      contentBlocks.add("empty_prompt_section");
    }

    // 4. Vitals Section
    contentBlocks.add("vitals_section");

    // 5. Interleave remaining media and prompts
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

    // 6. Add Audio Prompt (if available)
    if (user.audioPrompt != null) {
      contentBlocks.add(user.audioPrompt!);
    } else {
      contentBlocks.add("empty_audio_section");
    }
    // --- End Content Block Preparation ---

    // --- Build UI using SliverAppBar and ListView ---
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: const Color(0xFF8B5CF6),
        onRefresh: () => ref.read(userProvider.notifier).fetchProfile(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: false,
              elevation: 1,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              automaticallyImplyLeading: false,
              title: Text("Profile",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              actions: [
                _buildTopIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit Profile',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Edit Profile (Not Implemented)")));
                    // TODO: Navigate to Edit Profile Screen
                  },
                ),
                const SizedBox(width: 8),
                _buildTopIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsScreen()));
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Use SliverList with ListView.builder equivalent logic
            SliverPadding(
              padding:
                  const EdgeInsets.only(top: 8.0), // Add padding below AppBar
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = contentBlocks[index];
                    final double topPadding =
                        0; // No top padding needed per item
                    final double bottomPadding = 24.0; // Consistent spacing
                    final double horizontalPadding =
                        16.0; // Consistent horizontal padding

                    Widget contentWidget;

                    // Build content based on type
                    if (item is String && item == "header_section") {
                      contentWidget =
                          _buildHeaderBlock(user); // Use user directly
                    } else if (item is String &&
                        item == "empty_media_section") {
                      contentWidget = _buildEmptySection(
                          "Photos & Videos",
                          "Add photos and videos to show off your personality!",
                          Icons.add_photo_alternate_outlined);
                    } else if (item is String &&
                        item == "empty_prompt_section") {
                      contentWidget = _buildEmptySection(
                          "About Me",
                          "Add prompt answers to share more about yourself!",
                          Icons.chat_bubble_outline);
                    } else if (item is String &&
                        item == "empty_audio_section") {
                      contentWidget = _buildEmptySection(
                          "Voice Prompt",
                          "Record a voice prompt to let matches hear your voice!",
                          Icons.mic_none_rounded);
                    } else if (item is String && item.startsWith('http')) {
                      contentWidget =
                          _buildMediaItem(item); // Removed context/ref/index
                    } else if (item is Prompt) {
                      contentWidget =
                          _buildPromptItem(item); // Removed context/ref
                    } else if (item is AudioPromptModel) {
                      contentWidget = _buildAudioItem(
                          item); // Use THIS screen's audio builder, removed context/ref
                    } else if (item is String && item == "vitals_section") {
                      contentWidget =
                          _buildVitalsBlock(user); // Use user directly
                    } else {
                      contentWidget = const SizedBox.shrink();
                    }

                    // Wrap content with Padding
                    return Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPadding,
                          topPadding, horizontalPadding, bottomPadding),
                      child: contentWidget,
                    );
                  },
                  childCount: contentBlocks.length,
                ),
              ),
            ),
            // Add final padding at the bottom if needed
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  // --- Block Builder Widgets (Adapted for ProfileScreen) ---

  Widget _buildHeaderBlock(UserModel user) {
    // Adapted from HomeProfileCard, uses user directly
    final age = user.age;
    final capitalizedName =
        user.name != null ? capitalizeFirstLetter(user.name!) : "Your Name";
    final capitalizedLastName =
        user.lastName != null && user.lastName!.isNotEmpty
            ? capitalizeFirstLetter(user.lastName!)
            : "";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$capitalizedName $capitalizedLastName ${age != null ? "• $age" : ""}',
          style: GoogleFonts.poppins(
            fontSize: 28, // Adjusted size for profile page
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (user.gender != null ||
            (user.hometown != null && user.hometown!.isNotEmpty))
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (user.gender != null)
                _buildDetailChip(
                    Icons.person_outline_rounded, user.gender!.label,
                    subtle: true),
              if (user.hometown != null && user.hometown!.isNotEmpty)
                _buildDetailChip(Icons.location_on_outlined, user.hometown!,
                    subtle: true),
            ],
          ),
      ],
    );
  }

  Widget _buildMediaItem(String url) {
    // Adapted from HomeProfileCard - NO LIKE BUTTON
    bool isVideo = url.toLowerCase().contains('.mp4') ||
        url.toLowerCase().contains('.mov'); // Basic check
    int imageIndex = (ref.read(userProvider).mediaUrls ?? [])
        .indexOf(url); // Find index for PageView sync

    return ClipRRect(
      borderRadius: BorderRadius.circular(16), // More rounded
      child: AspectRatio(
        aspectRatio: 9 / 13, // Profile aspect ratio
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200], // Placeholder bg
            boxShadow: [
              // Subtle shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, prog) => prog == null
                    ? child
                    : Center(
                        child: CircularProgressIndicator(
                            value: prog.expectedTotalBytes != null
                                ? prog.cumulativeBytesLoaded /
                                    prog.expectedTotalBytes!
                                : null,
                            color: const Color(0xFF8B5CF6))),
                errorBuilder: (ctx, err, st) => Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.grey[400], size: 40)),
              ),
              if (isVideo) // Video indicator
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 40),
                  ),
                ),
              // NO LIKE BUTTON HERE
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptItem(Prompt prompt) {
    // Adapted from HomeProfileCard - NO LIKE BUTTON
    if (prompt.answer.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        // Use Column, no need for Row without button
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt.question.label,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B5CF6))), // Themed question
          const SizedBox(height: 10),
          Text(prompt.answer,
              style: GoogleFonts.poppins(
                  fontSize: 16, // Slightly larger answer
                  color: Colors.grey[850], // Darker answer text
                  height: 1.5)),
          // NO LIKE BUTTON HERE
        ],
      ),
    );
  }

  // THIS USES THE LOCAL AUDIO PLAYER LOGIC
  Widget _buildAudioItem(AudioPromptModel audio) {
    // Uses THIS screen's audio player state
    final bool isThisPlaying = _currentAudioUrl == audio.audioUrl && _isPlaying;
    final bool isThisPaused = _currentAudioUrl == audio.audioUrl &&
        !_isPlaying &&
        _audioPlayer.state ==
            PlayerState.paused; // Check if paused state matches URL

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0), // Add padding only above
          child: Text("Voice Prompt",
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A))),
        ),
        GestureDetector(
          // Make the whole container tappable to play/pause
          onTap: () => _playOrPauseAudio(audio.audioUrl),
          child: Container(
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
              ],
            ),
            child: Row(
              children: [
                // Play/Pause Button
                Container(
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
                  child: Icon(
                    isThisPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Prompt Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audio.prompt.label,
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // Indicate state
                        isThisPlaying
                            ? "Playing..."
                            : (isThisPaused ? "Paused" : "Tap to listen"),
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // NO LIKE BUTTON HERE
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsBlock(UserModel user) {
    // Adapted from HomeProfileCard
    final List<Widget> vitals = [];
    if (user.height != null && user.height!.isNotEmpty)
      vitals.add(_buildVitalRow(Icons.height_rounded, user.height!));
    if (user.religiousBeliefs != null)
      vitals.add(
          _buildVitalRow(Icons.church_outlined, user.religiousBeliefs!.label));
    if (user.jobTitle != null && user.jobTitle!.isNotEmpty)
      vitals.add(_buildVitalRow(Icons.work_outline_rounded, user.jobTitle!));
    if (user.education != null && user.education!.isNotEmpty)
      vitals.add(_buildVitalRow(Icons.school_outlined, user.education!));
    if (user.drinkingHabit != null)
      vitals.add(_buildVitalRow(
          Icons.local_bar_outlined, "Drinks: ${user.drinkingHabit!.label}"));
    if (user.smokingHabit != null)
      vitals.add(_buildVitalRow(
          Icons.smoking_rooms_outlined, "Smokes: ${user.smokingHabit!.label}"));

    if (vitals.isEmpty) {
      return _buildEmptySection(
          "Vitals & Habits",
          "Add more details like your height, job, habits, etc.",
          Icons.list_alt_rounded);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text("Vitals & Habits",
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A))),
        ),
        Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8), // Adjusted padding
            width: double.infinity,
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
            child: Column(
              children: List.generate(vitals.length * 2 - 1, (index) {
                if (index.isEven) {
                  return vitals[index ~/ 2];
                } else {
                  return Divider(
                      height: 20,
                      thickness: 1,
                      color: Colors.grey[200]); // Thicker divider
                }
              }),
            )),
      ],
    );
  }

  Widget _buildVitalRow(IconData icon, String label) {
    // Adapted from HomeProfileCard
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 8.0), // Consistent vertical padding
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF8B5CF6)), // Themed icon
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 15, color: Colors.grey[800]))),
        ],
      ),
    );
  }
}
