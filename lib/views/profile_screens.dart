// File: lib/views/profile_screens.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/utils/app_enums.dart'; // Import if needed for helpers

// --- ADDED: Import Settings Screen ---
import 'package:dtx/views/settings_screen.dart';
// --- END ADDED ---

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentAudioUrl;
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if profile data is already loaded, maybe skip fetch if recent?
      // For simplicity, fetching every time ensures freshness.
      ref.read(userProvider.notifier).fetchProfile();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          // Optionally reset _currentAudioUrl here if needed
          // _currentAudioUrl = null;
        });
      }
    });
  }

  @override
  void dispose() {
    // --- FIX: Safely stop audio player before disposing ---
    try {
      if (_audioPlayer.state == PlayerState.playing ||
          _audioPlayer.state == PlayerState.paused) {
        _audioPlayer.stop();
      }
      _audioPlayer.dispose();
    } catch (e) {
      print("Error stopping/disposing audio player: $e");
    }
    // --- END FIX ---
    _pageController.dispose();
    super.dispose();
  }

  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _playOrPauseAudio(String audioUrl) async {
    if (!mounted) return; // Ensure widget is still mounted

    try {
      final currentState = _audioPlayer.state;

      if (currentState == PlayerState.playing && _currentAudioUrl == audioUrl) {
        await _audioPlayer.pause();
        // Listener will update _isPlaying
      } else if (currentState == PlayerState.paused &&
          _currentAudioUrl == audioUrl) {
        await _audioPlayer.resume();
        // Listener will update _isPlaying
      } else {
        // Stop previous playback if different URL or stopped state
        if (currentState == PlayerState.playing ||
            currentState == PlayerState.paused) {
          await _audioPlayer.stop();
        }
        // Start new playback
        // --- FIX: Use play() instead of setSource/resume for simplicity and reliability ---
        await _audioPlayer.play(UrlSource(audioUrl));
        // --- END FIX ---
        if (mounted) {
          setState(() {
            _currentAudioUrl = audioUrl;
            // _isPlaying will be updated by the listener
          });
        }
      }
    } catch (e) {
      print("Error playing/pausing audio: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: ${e.toString()}')),
        );
        // Reset state on error
        setState(() {
          _isPlaying = false;
          _currentAudioUrl = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isLoading = ref.watch(userLoadingProvider);

    // Show loading indicator only if fetching initially (user.name is null)
    if (isLoading && user.name == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: const Color(0xFF8B5CF6),
          ),
        ),
      );
    }

    // Use getters for age and name formatting
    final age = user.age;
    final capitalizedName =
        user.name != null ? capitalizeFirstLetter(user.name!) : null;
    final capitalizedLastName =
        user.lastName != null && user.lastName!.isNotEmpty
            ? capitalizeFirstLetter(user.lastName!)
            : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: const Color(0xFF8B5CF6),
        onRefresh: () => ref.read(userProvider.notifier).fetchProfile(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()), // Ensure refresh works
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top + 16),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Top Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button (Optional - depends on navigation flow)
                      // IconButton(
                      //   icon: Container( /* ... Back button container ... */ ),
                      //   onPressed: () => Navigator.of(context).pop(),
                      // ),

                      // Spacer if no back button
                      const Spacer(), // Pushes buttons to the right

                      // Edit Button
                      _buildTopIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit Profile',
                        onPressed: () {
                          // TODO: Navigate to Edit Profile Screen
                          print("Edit Profile Tapped");
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Edit Profile (Not Implemented)")));
                        },
                      ),

                      const SizedBox(width: 8), // Spacing between buttons

                      // --- ADDED: Settings Button ---
                      _buildTopIconButton(
                        icon: Icons.settings_outlined,
                        tooltip: 'Settings',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SettingsScreen()),
                          );
                        },
                      ),
                      // --- END ADDED ---
                    ],
                  ),

                  _buildProfileHeader(
                      capitalizedName, capitalizedLastName, age, user),
                  const SizedBox(height: 24),
                  _buildMediaGallery(user.mediaUrls ?? []),
                  const SizedBox(height: 32),

                  // --- UPDATED: Check for dating intention and call _buildInfoSection ---
                  _buildInfoSection(
                      "Looking for", user.datingIntention?.label ?? ""),
                  // --- END UPDATED ---

                  const SizedBox(height: 24),
                  _buildPromptSection(user.prompts),
                  const SizedBox(height: 32),

                  // --- UPDATED: Check for audio prompt and call _buildAudioPrompt ---
                  _buildAudioPrompt(user.audioPrompt),
                  // --- END UPDATED ---

                  const SizedBox(height: 32),
                  _buildPersonalDetailsSection(user),
                  const SizedBox(height: 40), // Bottom padding
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for top icon buttons for consistency
  Widget _buildTopIconButton(
      {required IconData icon,
      required String tooltip,
      required VoidCallback onPressed}) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF8B5CF6),
          size: 20,
        ),
      ),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildProfileHeader(
      String? name, String? lastName, int? age, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${name ?? "Your Name"} ${lastName ?? ""} ${age != null ? "• $age" : ""}', // Provide default for name
          style: GoogleFonts.poppins(
            fontSize: 32, // Adjusted font size
            fontWeight: FontWeight.w700, // Bold
            color: const Color(0xFF1A1A1A),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        // Themed divider
        Container(
          width: 50,
          height: 3,
          decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(1.5)),
        ),
        const SizedBox(height: 16),
        if (user.gender != null ||
            (user.hometown != null && user.hometown!.isNotEmpty))
          Wrap(
            spacing: 10, // Adjusted spacing
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

  Widget _buildMediaGallery(List<String> images) {
    if (images.isEmpty) {
      return _buildEmptySection(
        "Photos & Videos",
        "Add photos and videos to show off your personality!",
        Icons.add_photo_alternate_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.5, // Responsive height
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08), // Softer shadow
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    if (mounted) {
                      // Check mounted before setState
                      setState(() {
                        _currentImageIndex = index;
                      });
                    }
                  },
                  itemBuilder: (context, index) {
                    // Basic check if it's a video URL (you might need a more robust check)
                    bool isVideo =
                        images[index].toLowerCase().contains('.mp4') ||
                            images[index].toLowerCase().contains(
                                '.mov'); // Add other video extensions if needed

                    return Container(
                      color: Colors.grey[200],
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      color: Colors.grey[400], size: 48),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color: const Color(0xFF8B5CF6),
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                          ),
                          // Add play icon overlay for videos
                          if (isVideo)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 40),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                // Gradient overlay (optional, can be removed if play icon is enough)
                // Positioned( /* ... gradient ... */ ),
                // Page indicator dots
                if (images.length > 1)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _currentImageIndex == index ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _currentImageIndex == index
                                ? const Color(0xFF8B5CF6)
                                : Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, String content) {
    // --- UPDATED: Return empty section if content is empty ---
    if (content.isEmpty) {
      return _buildEmptySection(
        title, // Use the passed title
        "Add your dating intention to tell others what you're looking for.", // Customize message
        Icons.favorite_border_rounded, // Appropriate icon
      );
    }
    // --- END UPDATED ---

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: Colors.grey[200]!, width: 1), // Lighter border
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14, // Slightly smaller label
              fontWeight: FontWeight.w500,
              color: Colors.grey[600], // Grey label
            ),
          ),
          const SizedBox(height: 6), // Reduced space
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 16, // Content size
              fontWeight: FontWeight.w500, // Normal weight for content
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptSection(List<Prompt> prompts) {
    if (prompts.isEmpty) {
      return _buildEmptySection(
        "About Me",
        "Add prompt answers to share more about yourself!",
        Icons.chat_bubble_outline,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Add padding to section title
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text(
            "About Me",
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A)),
          ),
        ),
        ...prompts.map((prompt) => _buildPromptCard(prompt)).toList(),
      ],
    );
  }

  Widget _buildPromptCard(Prompt prompt) {
    if (prompt.answer.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, // White background for cards
        borderRadius: BorderRadius.circular(16), // More rounded
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt.question.label,
            style: GoogleFonts.poppins(
              fontSize: 15, // Adjusted size
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B5CF6), // Themed question color
            ),
          ),
          const SizedBox(height: 10),
          Text(
            prompt.answer,
            style: GoogleFonts.poppins(
              fontSize: 15, // Adjusted size
              color: Colors.grey[800], // Dark grey for answer
              height: 1.5, // Line height
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPrompt(AudioPromptModel? audio) {
    // Make parameter nullable
    // --- UPDATED: Return empty section if audio is null or URL is empty ---
    if (audio == null || audio.audioUrl.isEmpty) {
      return _buildEmptySection(
        "Voice Prompt",
        "Record a voice prompt to let matches hear your voice!",
        Icons.mic_none_rounded,
      );
    }
    // --- END UPDATED ---

    final bool isThisPlaying = _currentAudioUrl == audio.audioUrl && _isPlaying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Add padding to section title
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text(
            "Voice Prompt",
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A)),
          ),
        ),
        GestureDetector(
          onTap: () => _playOrPauseAudio(audio.audioUrl),
          child: Container(
            padding: const EdgeInsets.all(16), // Adjusted padding
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  // Play/Pause Button
                  width: 48, height: 48, // Slightly smaller button
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(24), // Fully rounded
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Icon(
                    isThisPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  // Prompt Text
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
                        isThisPlaying ? "Playing..." : "Tap to listen",
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Optional: Add audio wave animation when playing
                // if (isThisPlaying) ... [ /* Animation Widget */ ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalDetailsSection(UserModel user) {
    final details = <Widget>[];
    if (user.height != null && user.height!.isNotEmpty)
      details.add(_buildDetailChip(
          Icons.height_rounded, user.height!)); // Use specific icon
    if (user.religiousBeliefs != null)
      details.add(_buildDetailChip(
          Icons.church_outlined, user.religiousBeliefs!.label));
    if (user.jobTitle != null && user.jobTitle!.isNotEmpty)
      details.add(_buildDetailChip(Icons.work_outline_rounded, user.jobTitle!));
    if (user.education != null && user.education!.isNotEmpty)
      details.add(_buildDetailChip(Icons.school_outlined, user.education!));
    if (user.drinkingHabit != null)
      details.add(_buildDetailChip(Icons.local_bar_outlined,
          "Drinks: ${user.drinkingHabit!.label}")); // Add prefix
    if (user.smokingHabit != null)
      details.add(_buildDetailChip(Icons.smoking_rooms_outlined,
          "Smokes: ${user.smokingHabit!.label}")); // Add prefix

    // --- UPDATED: Return empty section if no details ---
    if (details.isEmpty) {
      return _buildEmptySection(
        "Vitals & Habits",
        "Add more details like your height, job, habits, etc.",
        Icons.list_alt_rounded,
      );
    }
    // --- END UPDATED ---

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Add padding to section title
          padding: const EdgeInsets.only(
              top: 16.0, bottom: 12.0), // Adjusted padding
          child: Text(
            "Vitals & Habits", // Changed title
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A)),
          ),
        ),
        Wrap(
          // Use Wrap for chips
          spacing: 10, // Horizontal space
          runSpacing: 10, // Vertical space
          children: details,
        ),
      ],
    );
  }

  // Updated Detail Chip
  Widget _buildDetailChip(IconData icon, String label, {bool subtle = false}) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 8), // Adjusted padding
      decoration: BoxDecoration(
        color: subtle
            ? Colors.transparent
            : Colors.grey[100], // Use grey[100] for non-subtle
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: subtle ? Colors.grey.shade400 : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Important for Wrap
        children: [
          Icon(
            icon,
            size: subtle ? 16 : 18,
            color: subtle
                ? Colors.grey.shade600
                : const Color(0xFF8B5CF6), // Use theme color
          ),
          const SizedBox(width: 8),
          Flexible(
            // Allow text to wrap if needed within the chip
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: subtle ? 13 : 14,
                fontWeight: FontWeight.w500,
                color: subtle ? Colors.grey.shade700 : Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String title, String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: 30, horizontal: 20), // More vertical padding
      margin: const EdgeInsets.symmetric(vertical: 16), // Vertical margin
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            // Add padding to section title
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800])),
          ),
          Icon(icon, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          // Optional: Add an "Add" button
          // const SizedBox(height: 16),
          // ElevatedButton.icon(
          //   onPressed: () { /* TODO: Action to add content */ },
          //   icon: Icon(Icons.add_circle_outline_rounded, size: 18),
          //   label: Text("Add Now"),
          //   style: ElevatedButton.styleFrom(
          //      foregroundColor: const Color(0xFF8B5CF6), backgroundColor: Colors.white, elevation: 0,
          //      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[300]!)),
          //   ),
          // )
        ],
      ),
    );
  }
}
