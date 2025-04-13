// File: views/liker_profile_screen.dart
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/like_models.dart';
import 'package:dtx/providers/liker_profile_provider.dart';
import 'package:dtx/views/profile_screens.dart'; // Re-use ProfileScreen's building blocks (Keep for reference, but structure is replicated)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// --- ADDED IMPORTS ---
import 'package:dtx/models/user_model.dart';
import 'package:dtx/utils/app_enums.dart'; // For Gender enum etc. if needed in helpers
// --- END ADDED ---

class LikerProfileScreen extends ConsumerWidget {
  final int likerUserId;

  const LikerProfileScreen({super.key, required this.likerUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the specific provider instance for this liker's ID
    final state = ref.watch(likerProfileProvider(likerUserId));
    final profile = state.profile;
    final likeDetails = state.likeDetails;

    return Scaffold(
      backgroundColor: Colors.white,
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
      return _buildErrorState(context, state.error!, ref); // Pass context
    }

    if (profile == null || likeDetails == null) {
      return _buildErrorState(
          context,
          AppError.generic("Profile data could not be loaded."),
          ref); // Pass context
    }

    // --- If data loaded successfully ---
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
          title: Text(
            // --- FIX: Use profile.name ---
            profile.name ?? 'Profile',
            // --- END FIX ---
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.message_outlined,
                    color: Color(0xFF8B5CF6)),
                tooltip: "Send Message",
                onPressed: () {
                  // --- FIX: Use profile.id ---
                  print("Navigate to chat with user ${profile.id}");
                  // --- END FIX ---
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Chat functionality not yet implemented.')));
                },
              ),
            )
          ],
        ),

        // --- Like Details Banner ---
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: likeDetails.isRose
                    ? Colors.purple.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: likeDetails.isRose
                        ? Colors.purple.shade100
                        : Colors.blue.shade100)),
            child: Row(
              children: [
                Icon(
                  likeDetails.isRose
                      ? Icons.star_rounded
                      : Icons.favorite_rounded,
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
                        ? '"${likeDetails.likeComment}"' // Show comment if exists
                        : (likeDetails.isRose
                            ? 'Sent you a Rose!'
                            : 'Liked your profile!'), // Default message
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
          ),
        ),

        // --- Profile Content ---
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildProfileHeader(profile),
              const SizedBox(height: 24),
              _buildMediaGallery(
                  context, profile.mediaUrls ?? []), // Pass context
              const SizedBox(height: 32),
              if (profile.datingIntention != null)
                _buildInfoSection(
                    "Looking for", profile.datingIntention!.label),
              const SizedBox(height: 24),
              _buildPromptSection(profile.prompts),
              const SizedBox(height: 32),
              if (profile.audioPrompt != null)
                _buildAudioPrompt(
                    context, profile.audioPrompt!), // Pass context
              const SizedBox(height: 32),
              _buildPersonalDetailsSection(profile),
              const SizedBox(height: 40), // Bottom padding
            ]),
          ),
        ),
      ],
    );
  }

  // --- Error State Widget ---
  Widget _buildErrorState(BuildContext context, AppError error, WidgetRef ref) {
    // Added context
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
                  .read(likerProfileProvider(likerUserId).notifier)
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

  // --- Replicated/Adapted Widgets ---

  Widget _buildProfileHeader(UserProfileData user) {
    // --- FIX: Use user.age getter ---
    final age = user.age;
    // --- END FIX ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // --- FIX: Use user.name and check lastName ---
          '${user.name ?? ''}${user.lastName != null && user.lastName!.isNotEmpty ? ' ${user.lastName}' : ''}${age != null ? ' • $age' : ''}',
          // --- END FIX ---
          style: GoogleFonts.poppins(
            fontSize: 36, // Slightly smaller if too large
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        if (user.gender != null ||
            (user.hometown != null && user.hometown!.isNotEmpty))
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (user.gender != null)
                _buildDetailChip(Icons.person_outline, user.gender!.label,
                    subtle: true),
              if (user.hometown != null && user.hometown!.isNotEmpty)
                _buildDetailChip(Icons.location_on_outlined, user.hometown!,
                    subtle: true),
            ],
          ),
      ],
    );
  }

  Widget _buildMediaGallery(BuildContext context, List<String> images) {
    // Added context
    if (images.isEmpty) return const SizedBox.shrink();

    return Container(
      height: MediaQuery.of(context).size.height * 0.4, // Responsive height
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Container(
            width: MediaQuery.of(context).size.width * 0.6, // Responsive width
            margin: EdgeInsets.only(right: index == images.length - 1 ? 0 : 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              // Clip the image
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                      child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: Color(0xFF8B5CF6)));
                },
                errorBuilder: (context, error, stackTrace) {
                  print("Error loading image: ${images[index]} - $error");
                  return Center(
                      child: Icon(Icons.broken_image, color: Colors.grey[400]));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    // Check if content is not empty before building
    if (content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptSection(List<Prompt> prompts) {
    if (prompts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "About Me",
          style: GoogleFonts.poppins(
            fontSize: 20,
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
    // Check if answer is not empty before building
    if (prompt.answer.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt.question.label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prompt.answer,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF1A1A1A),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPrompt(BuildContext context, AudioPromptModel audio) {
    // Added context
    // Simple display, no playback logic here for now
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Voice Prompt",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.graphic_eq, // Use a different icon for display only
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  audio.prompt.label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalDetailsSection(UserProfileData user) {
    final details = <Widget>[];
    // Add checks for empty strings as well
    if (user.height != null && user.height!.isNotEmpty)
      details.add(_buildDetailChip(Icons.height, "Height: ${user.height}"));
    if (user.religiousBeliefs != null)
      details.add(_buildDetailChip(
          Icons.church_outlined, user.religiousBeliefs!.label));
    if (user.jobTitle != null && user.jobTitle!.isNotEmpty)
      details.add(_buildDetailChip(Icons.work_outline, user.jobTitle!));
    if (user.education != null && user.education!.isNotEmpty)
      details.add(_buildDetailChip(Icons.school_outlined, user.education!));
    if (user.drinkingHabit != null)
      details.add(_buildDetailChip(
          Icons.local_bar_outlined, user.drinkingHabit!.label));
    if (user.smokingHabit != null)
      details.add(_buildDetailChip(
          Icons.smoking_rooms_outlined, user.smokingHabit!.label));

    if (details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Personal Details",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: details,
        ),
      ],
    );
  }

  Widget _buildDetailChip(IconData icon, String label, {bool subtle = false}) {
    // Check if label is empty
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
            // Allow text to wrap if needed
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: subtle ? 13 : 14,
                fontWeight: FontWeight.w500,
                color: subtle ? Colors.grey.shade700 : Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis, // Prevent long text overflow
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
