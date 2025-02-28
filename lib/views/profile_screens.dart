import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/providers/user_provider.dart';

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
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Helper function to capitalize first letter
  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _playOrPauseAudio(String audioUrl) async {
    try {
      if (_isPlaying && _currentAudioUrl == audioUrl) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else if (_currentAudioUrl == audioUrl) {
        await _audioPlayer.resume();
        setState(() {
          _isPlaying = true;
        });
      } else {
        setState(() => _isPlaying = false);
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() {
          _isPlaying = true;
          _currentAudioUrl = audioUrl;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isLoading = ref.watch(userLoadingProvider);
    final age = user.dateOfBirth != null
        ? DateTime.now().difference(user.dateOfBirth!).inDays ~/ 365
        : null;

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

    // Capitalize first letter of name and lastName if available
    final capitalizedName = user.name != null ? capitalizeFirstLetter(user.name!) : null;
    final capitalizedLastName = user.lastName != null ? capitalizeFirstLetter(user.lastName!) : null;

    return Scaffold(
      backgroundColor: Colors.white,
      // No AppBar - removed as requested
      body: RefreshIndicator(
        color: const Color(0xFF8B5CF6),
        onRefresh: () => ref.read(userProvider.notifier).fetchProfile(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Top space for status bar
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top + 16),
            ),
            
            // Main content
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Back and Edit buttons at top
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: const Color(0xFF8B5CF6),
                            size: 20,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      // Edit button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: const Color(0xFF8B5CF6),
                            size: 20,
                          ),
                        ),
                        onPressed: () {
                          // Edit profile action
                        },
                      ),
                    ],
                  ),
                  
                  _buildProfileHeader(capitalizedName, capitalizedLastName, age, user),
                  const SizedBox(height: 24),
                  _buildMediaGallery(user.mediaUrls ?? []),
                  const SizedBox(height: 32),
                  
                  if (user.datingIntention != null) 
                    _buildInfoSection("Looking for", user.datingIntention!.label),
                  
                  const SizedBox(height: 24),
                  _buildPromptSection(user.prompts),
                  const SizedBox(height: 32),
                  
                  if (user.audioPrompt != null) 
                    _buildAudioPrompt(user.audioPrompt!),
                  
                  const SizedBox(height: 32),
                  _buildPersonalDetailsSection(user),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String? name, String? lastName, int? age, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${name ?? "Your Profile"} ${lastName ?? ""} ${age != null ? "• $age" : ""}',
          style: GoogleFonts.poppins(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        // Add a subtle themed divider
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        if (user.gender != null || user.hometown != null)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (user.gender != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                  ),
                  child: Text(
                    user.gender!.label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              if (user.hometown != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: const Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.hometown!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildMediaGallery(List<String> images) {
    if (images.isEmpty) {
      return _buildEmptySection(
        "Photos",
        "Add photos to your profile",
        Icons.add_photo_alternate_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
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
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey[400],
                              size: 48,
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: const Color(0xFF8B5CF6),
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
                // Gradient overlay at bottom for better text visibility
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                // Page indicator dots
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.2), width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
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
        "Add prompts to tell others about yourself",
        Icons.chat_bubble_outline,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "About Me",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        ...prompts.map((prompt) => _buildPromptCard(prompt)).toList(),
      ],
    );
  }

  Widget _buildPromptCard(Prompt prompt) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt.question.label,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            prompt.answer,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: const Color(0xFF1A1A1A),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPrompt(AudioPromptModel audio) {
    final bool isThisPlaying = _currentAudioUrl == audio.audioUrl && _isPlaying;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Voice Prompt",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _playOrPauseAudio(audio.audioUrl),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isThisPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audio.prompt.label,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isThisPlaying ? "Playing..." : "Tap to listen",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                  if (isThisPlaying)
                  Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 4,
                        height: 16 + (index * 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(2),
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

  Widget _buildPersonalDetailsSection(UserModel user) {
    final hasDetails = user.height != null || 
                      user.religiousBeliefs != null || 
                      user.jobTitle != null || 
                      user.education != null || 
                      user.drinkingHabit != null || 
                      user.smokingHabit != null;
    
    if (!hasDetails) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Personal Details",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (user.height != null) 
              _buildDetailChip(Icons.height, "Height: ${user.height}"),
            if (user.religiousBeliefs != null) 
              _buildDetailChip(Icons.church_outlined, user.religiousBeliefs!.label),
            if (user.jobTitle != null) 
              _buildDetailChip(Icons.work_outline, user.jobTitle!),
            if (user.education != null) 
              _buildDetailChip(Icons.school_outlined, user.education!),
            if (user.drinkingHabit != null) 
              _buildDetailChip(Icons.local_bar_outlined, user.drinkingHabit!.label),
            if (user.smokingHabit != null) 
              _buildDetailChip(Icons.smoking_rooms_outlined, user.smokingHabit!.label),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String title, String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Icon(
            icon,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
