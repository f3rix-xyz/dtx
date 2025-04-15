import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/utils/app_enums.dart'; // Import for enums if used in helpers
import 'package:dtx/views/settings_screen.dart';

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
    // Fetching is now initiated in MainNavigationScreen initState
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (ref.read(userProvider).name == null && !ref.read(userLoadingProvider)) {
    //      ref.read(userProvider.notifier).fetchProfile();
    //   }
    // });

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
          _currentAudioUrl = null; // Reset URL on completion
        });
      }
    });
  }

  @override
  void dispose() {
    try {
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

  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

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
        if (currentState == PlayerState.playing ||
            currentState == PlayerState.paused) {
          await _audioPlayer.stop();
        }
        await _audioPlayer.play(UrlSource(audioUrl));
        if (mounted) {
          setState(() {
            _currentAudioUrl = audioUrl;
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isLoading = ref.watch(userLoadingProvider);

    // Show loading indicator only if fetching initially (user.name is null)
    // Loading state now handled by checking provider state directly
    if (isLoading && user.name == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        // Add AppBar here for consistency during loading
        appBar: AppBar(
          title: Text("Profile",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0, // No shadow when loading
          automaticallyImplyLeading: false,
          actions: [
            _buildTopIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit Profile',
                onPressed: () {}), // Placeholder actions
            const SizedBox(width: 8),
            _buildTopIconButton(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onPressed: () {}),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    final age = user.age;
    final capitalizedName =
        user.name != null ? capitalizeFirstLetter(user.name!) : null;
    final capitalizedLastName =
        user.lastName != null && user.lastName!.isNotEmpty
            ? capitalizeFirstLetter(user.lastName!)
            : null;

    return Scaffold(
      backgroundColor: Colors.white,
      // Use SliverAppBar for integrated scrolling behavior
      body: RefreshIndicator(
        color: const Color(0xFF8B5CF6),
        onRefresh: () => ref.read(userProvider.notifier).fetchProfile(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true, // Keep visible while scrolling down
              floating: false, // Don't reappear immediately on scroll up
              elevation: 1, // Subtle shadow
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              automaticallyImplyLeading: false, // No back button in tab screen
              title: Text("Profile",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              actions: [
                _buildTopIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit Profile',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Edit Profile (Not Implemented)")));
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
                const SizedBox(width: 8), // Add padding to the right edge
              ],
            ),

            // Add some padding below the AppBar
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Removed Row for buttons, handled by SliverAppBar actions
                  _buildProfileHeader(
                      capitalizedName, capitalizedLastName, age, user),
                  const SizedBox(height: 24),
                  _buildMediaGallery(user.mediaUrls ?? []),
                  const SizedBox(height: 32),
                  _buildInfoSection(
                      "Looking for", user.datingIntention?.label ?? ""),
                  const SizedBox(height: 24),
                  _buildPromptSection(user.prompts),
                  const SizedBox(height: 32),
                  _buildAudioPrompt(user.audioPrompt),
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

  // _buildTopIconButton remains the same
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
        child: Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
      ),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  // _buildProfileHeader remains the same
  Widget _buildProfileHeader(
      String? name, String? lastName, int? age, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${name ?? "Your Name"} ${lastName ?? ""} ${age != null ? "• $age" : ""}', // Provide default for name
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          // Themed divider
          width: 50, height: 3,
          decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(1.5)),
        ),
        const SizedBox(height: 16),
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

  // _buildMediaGallery remains the same
  Widget _buildMediaGallery(List<String> images) {
    if (images.isEmpty) {
      return _buildEmptySection(
          "Photos & Videos",
          "Add photos and videos to show off your personality!",
          Icons.add_photo_alternate_outlined);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
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
                      setState(() {
                        _currentImageIndex = index;
                      });
                    }
                  },
                  itemBuilder: (context, index) {
                    bool isVideo =
                        images[index].toLowerCase().contains('.mp4') ||
                            images[index].toLowerCase().contains('.mov');
                    return Container(
                      color: Colors.grey[200],
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                        child: Icon(Icons.broken_image_outlined,
                                            color: Colors.grey[400],
                                            size: 48))),
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
                          if (isVideo)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle),
                                child: Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 40),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
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

  // _buildInfoSection remains the same
  Widget _buildInfoSection(String title, String content) {
    if (content.isEmpty) {
      return _buildEmptySection(
          title,
          "Add your dating intention to tell others what you're looking for.",
          Icons.favorite_border_rounded);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text(content,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  // _buildPromptSection remains the same
  Widget _buildPromptSection(List<Prompt> prompts) {
    if (prompts.isEmpty) {
      return _buildEmptySection(
          "About Me",
          "Add prompt answers to share more about yourself!",
          Icons.chat_bubble_outline);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text("About Me",
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A))),
        ),
        ...prompts.map((prompt) => _buildPromptCard(prompt)).toList(),
      ],
    );
  }

  // _buildPromptCard remains the same
  Widget _buildPromptCard(Prompt prompt) {
    if (prompt.answer.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt.question.label,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B5CF6))),
          const SizedBox(height: 10),
          Text(prompt.answer,
              style: GoogleFonts.poppins(
                  fontSize: 15, color: Colors.grey[800], height: 1.5)),
        ],
      ),
    );
  }

  // _buildAudioPrompt remains the same
  Widget _buildAudioPrompt(AudioPromptModel? audio) {
    if (audio == null || audio.audioUrl.isEmpty) {
      return _buildEmptySection(
          "Voice Prompt",
          "Record a voice prompt to let matches hear your voice!",
          Icons.mic_none_rounded);
    }
    final bool isThisPlaying = _currentAudioUrl == audio.audioUrl && _isPlaying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text("Voice Prompt",
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A))),
        ),
        GestureDetector(
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
                    ],
                  ),
                  child: Icon(
                      isThisPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28),
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
                      Text(isThisPlaying ? "Playing..." : "Tap to listen",
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // _buildPersonalDetailsSection remains the same
  Widget _buildPersonalDetailsSection(UserModel user) {
    final details = <Widget>[];
    if (user.height != null && user.height!.isNotEmpty)
      details.add(_buildDetailChip(Icons.height_rounded, user.height!));
    if (user.religiousBeliefs != null)
      details.add(_buildDetailChip(
          Icons.church_outlined, user.religiousBeliefs!.label));
    if (user.jobTitle != null && user.jobTitle!.isNotEmpty)
      details.add(_buildDetailChip(Icons.work_outline_rounded, user.jobTitle!));
    if (user.education != null && user.education!.isNotEmpty)
      details.add(_buildDetailChip(Icons.school_outlined, user.education!));
    if (user.drinkingHabit != null)
      details.add(_buildDetailChip(
          Icons.local_bar_outlined, "Drinks: ${user.drinkingHabit!.label}"));
    if (user.smokingHabit != null)
      details.add(_buildDetailChip(
          Icons.smoking_rooms_outlined, "Smokes: ${user.smokingHabit!.label}"));

    if (details.isEmpty) {
      return _buildEmptySection(
          "Vitals & Habits",
          "Add more details like your height, job, habits, etc.",
          Icons.list_alt_rounded);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
          child: Text("Vitals & Habits",
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A))),
        ),
        Wrap(spacing: 10, runSpacing: 10, children: details),
      ],
    );
  }

  // _buildDetailChip remains the same
  Widget _buildDetailChip(IconData icon, String label, {bool subtle = false}) {
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

  // _buildEmptySection remains the same
  Widget _buildEmptySection(String title, String message, IconData icon) {
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
}
