// File: views/profile_screens.dart
import 'dart:math'; // Needed for interleaving logic
import 'dart:io'; // Needed for File type checking

import 'package:dtx/models/media_upload_model.dart';
import 'package:dtx/views/audioprompt.dart';
import 'package:dtx/views/dating_intentions.dart';
import 'package:dtx/views/drinking.dart';
import 'package:dtx/views/height.dart';
import 'package:dtx/views/hometown.dart';
import 'package:dtx/views/job.dart';
import 'package:dtx/views/media.dart';
import 'package:dtx/views/prompt.dart';
import 'package:dtx/views/religion.dart';
import 'package:dtx/views/smoking.dart';
import 'package:dtx/views/study.dart';
import 'package:dtx/views/textpromptsselect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart'; // Keep for local player

import 'package:dtx/models/user_model.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/settings_screen.dart';
import 'package:dtx/providers/error_provider.dart'; // <<< ADDED
import 'package:dtx/models/error_model.dart'; // <<< ADDED
import 'package:dtx/providers/service_provider.dart'; // <<< ADDED for repository
import 'package:dtx/providers/media_upload_provider.dart'; // <<< ADDED for upload
import 'package:dtx/services/api_service.dart'; // <<< ADDED for ApiException

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

  // --- NEW State for Edit Mode ---
  bool _isEditing = false;
  bool _isSaving = false;
  UserModel? _originalProfileData; // To store data before editing starts
  // --- END NEW State ---

  @override
  void initState() {
    super.initState();
    // Fetching initiated in MainNavigationScreen initState now

    // --- Retained Audio Player Listeners ---
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
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
          _currentAudioUrl = null;
        });
      }
    });
    // --- End Retained Listeners ---
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
    // _pageController.dispose(); // Removed PageController
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
        if (currentState == PlayerState.playing ||
            currentState == PlayerState.paused) {
          await _audioPlayer.stop();
        }
        await _audioPlayer.play(UrlSource(audioUrl));
        if (mounted) setState(() => _currentAudioUrl = audioUrl);
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

  // --- NEW Edit Mode Handlers ---
  void _enterEditMode() {
    // Store current state before starting edits
    _originalProfileData = ref.read(userProvider);
    setState(() => _isEditing = true);
  }

  void _cancelEditMode() {
    // Discard changes by restoring original data or refetching
    if (_originalProfileData != null) {
      ref.read(userProvider.notifier).state = _originalProfileData!;
    } else {
      // Fallback: Refetch if original data wasn't stored
      ref.read(userProvider.notifier).fetchProfile();
    }
    // Reset media changed flag
    ref.read(userProvider.notifier).setMediaChangedFlag(false);
    setState(() => _isEditing = false);
  }

  Future<void> _handleSave() async {
    print("[ProfileScreen] Starting Save Process...");
    ref.read(errorProvider.notifier).clearError(); // Clear previous errors
    if (!mounted) return;
    setState(() => _isSaving = true);

    final userState = ref.read(userProvider);
    final userNotifier = ref.read(userProvider.notifier);
    List<String> finalMediaUrls =
        List<String>.from(userState.mediaUrls ?? []); // Start with current URLs

    try {
      // --- Media Upload Logic (if changed) ---
      if (userState.mediaChangedDuringEdit) {
        print("[ProfileScreen] Media changed, initiating upload...");
        final mediaUploadNotifier = ref.read(mediaUploadProvider.notifier);
        final currentMediaItems = userState.mediaUrls ??
            []; // List might contain URLs and local paths now

        // Identify new files to upload
        final List<File> filesToUpload = [];
        final List<int> fileIndices = []; // Track original indices of files
        final List<String> existingUrls = []; // Track existing URLs in order

        // Prepare the list for the upload provider based on the mixed list
        List<File?> filesForProvider = List.filled(6, null);

        for (int i = 0; i < currentMediaItems.length && i < 6; i++) {
          final item = currentMediaItems[i];
          File potentialFile = File(item); // Try treating it as a path
          if (await potentialFile.exists()) {
            // Check if it's a local file path
            filesToUpload.add(potentialFile);
            fileIndices.add(i);
            filesForProvider[i] =
                potentialFile; // Place file at correct index for provider
            print("   - Found new file at index $i: ${potentialFile.path}");
          } else if (item.startsWith('http')) {
            existingUrls.add(item); // Keep existing URLs
            print("   - Found existing URL at index $i: $item");
            // No file to upload for this slot
          } else {
            print(
                "   - Warning: Item at index $i is neither a valid file path nor a URL: $item");
          }
        }
        // Ensure minimum 3 media items rule is still met before upload/save
        if ((existingUrls.length + filesToUpload.length) < 3) {
          throw ApiException("Minimum of 3 media items required.");
        }

        if (filesToUpload.isNotEmpty) {
          // Set files in the provider in their correct order
          for (int i = 0; i < filesForProvider.length; i++) {
            if (filesForProvider[i] != null) {
              mediaUploadNotifier.setMediaFile(i, filesForProvider[i]!);
            } else {
              // If you have a clear method in provider, call it here for slots that are now empty
              // mediaUploadNotifier.removeMedia(i);
            }
          }

          print("[ProfileScreen] Calling uploadAllMedia...");
          final uploadSuccess = await mediaUploadNotifier.uploadAllMedia();

          if (!uploadSuccess) {
            print("[ProfileScreen] Media upload failed.");
            throw ApiException("Failed to upload media. Please try again.");
          }
          print("[ProfileScreen] Media upload successful.");

          // --- Reconstruct the final URL list ---
          final uploadedItemsState =
              ref.read(mediaUploadProvider); // Get the state AFTER upload
          final Map<String, String> uploadedFileNameToUrl = {};
          for (final uploadedItem in uploadedItemsState) {
            if (uploadedItem != null &&
                uploadedItem.status == UploadStatus.success &&
                uploadedItem.presignedUrl != null) {
              // Assuming presignedUrl IS the final URL after upload (adjust if not)
              uploadedFileNameToUrl[uploadedItem.fileName] =
                  uploadedItem.presignedUrl!;
            }
          }

          // Build the final list based on the original order
          final List<String> reconstructedUrls = [];
          for (final itemPathOrUrl in currentMediaItems) {
            File potentialFile = File(itemPathOrUrl);
            if (await potentialFile.exists()) {
              final fileName = potentialFile.path.split('/').last;
              if (uploadedFileNameToUrl.containsKey(fileName)) {
                reconstructedUrls.add(uploadedFileNameToUrl[fileName]!);
              } else {
                print("Warning: Uploaded file URL not found for $fileName");
              }
            } else if (itemPathOrUrl.startsWith('http')) {
              reconstructedUrls.add(itemPathOrUrl);
            }
          }
          finalMediaUrls = reconstructedUrls;
          print(
              "[ProfileScreen] Final reconstructed Media URLs: $finalMediaUrls");
        } else {
          print(
              "[ProfileScreen] Media marked changed, but no new files found to upload.");
          // Use the potentially reordered/deleted list directly
          finalMediaUrls = currentMediaItems
              .where((item) => item.startsWith('http'))
              .toList();
          if (finalMediaUrls.length < 3) {
            throw ApiException(
                "Minimum of 3 media items required after edits.");
          }
        }
      } else {
        print("[ProfileScreen] Media not changed, using existing URLs.");
        finalMediaUrls = userState.mediaUrls ?? [];
        if (finalMediaUrls.length < 3) {
          throw ApiException("Minimum of 3 media items required.");
        }
      }
      // --- End Media Upload Logic ---

      // --- Prepare PATCH Payload ---
      // Get the latest state which includes edits from other screens
      final latestUserState = ref.read(userProvider);
      Map<String, dynamic> payload = latestUserState.toJsonForEdit();
      // IMPORTANT: Overwrite media_urls in payload with the potentially updated list
      payload['media_urls'] = finalMediaUrls;

      // Remove non-editable fields explicitly just in case they slipped in
      payload.remove('name');
      payload.remove('last_name');
      payload.remove('date_of_birth');
      payload.remove('latitude');
      payload.remove('longitude');
      payload.remove('gender');
      payload.remove('id'); // Don't send ID in payload

      print("[ProfileScreen] Preparing PATCH payload: $payload");

      // --- Call API ---
      final userRepository = ref.read(userRepositoryProvider);
      final bool success = await userRepository.editProfile(payload);

      if (success) {
        print("[ProfileScreen] Profile edit successful.");
        // Update user provider with the final media URLs and reset flags
        userNotifier.updateMediaUrls(
            finalMediaUrls); // Updates URLs and resets mediaChanged flag
        userNotifier.setMediaChangedFlag(false); // Explicitly reset flag

        // Optionally refetch profile for absolute certainty (might be redundant)
        // await userNotifier.fetchProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Profile updated successfully!"),
                backgroundColor: Colors.green),
          );
          setState(() => _isEditing = false); // Exit edit mode
        }
      } else {
        print(
            "[ProfileScreen] Profile edit failed (API returned false or non-success).");
        // Error should ideally be thrown by the repository/service layer
        if (mounted && ref.read(errorProvider) == null) {
          // Check if error already exists
          ref
              .read(errorProvider.notifier)
              .setError(AppError.server("Failed to save profile changes."));
        }
      }
    } on ApiException catch (e) {
      print("[ProfileScreen] Save failed: API Exception - ${e.message}");
      if (mounted)
        ref.read(errorProvider.notifier).setError(AppError.server(e.message));
    } catch (e, stack) {
      print("[ProfileScreen] Save failed: Unexpected error - $e");
      print(stack); // Print stack trace for debugging
      if (mounted)
        ref
            .read(errorProvider.notifier)
            .setError(AppError.generic("An unexpected error occurred."));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- END NEW Edit Mode Handlers ---

  // --- Helper Methods (some adapted from HomeProfileCard) ---

  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // --- UPDATED Top Icon Button Builder ---
  Widget _buildTopIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isDisabled = false, // Added disabled state
    Color? color, // Optional color override
  }) {
    final iconColor =
        isDisabled ? Colors.grey[400] : (color ?? const Color(0xFF8B5CF6));
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey[200]
              : Colors.grey[100], // Different bg when disabled
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      tooltip: isDisabled ? null : tooltip, // No tooltip if disabled
      onPressed: isDisabled ? null : onPressed,
    );
  }
  // --- END UPDATED ---

  Widget _buildEmptySection(
      String title, String message, IconData icon, VoidCallback? onEditTap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!)),
      child: Stack(// Use stack for edit button
          children: [
        Column(
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
        // Edit button overlay (visible only in edit mode)
        if (_isEditing && onEditTap != null)
          Positioned(
            top: 8,
            right: 8,
            child: _buildSmallEditButton(onPressed: onEditTap),
          ),
      ]),
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
          Icon(icon,
              size: subtle ? 16 : 18,
              color: subtle ? Colors.grey.shade600 : const Color(0xFF8B5CF6)),
          const SizedBox(width: 6),
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

  // --- NEW: Small Edit Button ---
  Widget _buildSmallEditButton(
      {required VoidCallback onPressed,
      IconData icon = Icons.edit_outlined,
      String? tooltip = 'Edit'}) {
    return Material(
      // Provides ink splash effect
      color: Colors.white.withOpacity(0.8),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(6), // Smaller padding
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3)
            ],
          ),
          child: Icon(icon,
              color: const Color(0xFF8B5CF6), size: 18), // Smaller icon
        ),
      ),
    );
  }
  // --- END NEW ---

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isLoadingProfile = ref.watch(userLoadingProvider);
    final apiError =
        ref.watch(errorProvider); // Watch for API errors during save

    // --- Loading State ---
    if (isLoadingProfile && user.name == null && !_isEditing) {
      // Show loading only on initial load
      // ... (loading scaffold remains the same) ...
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
            _buildTopIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit Profile',
                onPressed: () {},
                isDisabled: true),
            const SizedBox(width: 8),
            _buildTopIconButton(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onPressed: () {},
                isDisabled: true),
            const SizedBox(width: 8),
          ],
        ),
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
      );
    }

    // --- Error State (Show general API errors if not saving) ---
    if (apiError != null && !_isSaving) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          /* ... AppBar ... */
          title: Text("Profile",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            /* ... Actions (can be disabled) ... */
            _buildTopIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit Profile',
                onPressed: _enterEditMode), // Still allow entering edit maybe?
            const SizedBox(width: 8),
            _buildTopIconButton(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen()))),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 50),
              const SizedBox(height: 15),
              Text(apiError.message,
                  textAlign: TextAlign.center, style: GoogleFonts.poppins()),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  ref.read(errorProvider.notifier).clearError();
                  ref.read(userProvider.notifier).fetchProfile(); // Retry fetch
                },
                child: const Text("Retry"),
              )
            ],
          ),
        )),
      );
    }

    // --- Prepare Content Blocks (Logic from HomeProfileCard) ---
    final List<dynamic> contentBlocks = [];
    final mediaUrls =
        user.mediaUrls ?? []; // Use potentially modified list from provider
    final prompts = user.prompts;

    // 1. Header (Not editable, always show)
    contentBlocks.add("header_section");

    // 2. Media Section (Uses _buildMediaGallery wrapper now)
    contentBlocks.add("media_gallery");

    // 3. First Prompt (if available, else empty section)
    if (prompts.isNotEmpty) {
      contentBlocks.add(prompts[0]);
    } else {
      contentBlocks.add("empty_prompt_section");
    }

    // 4. Vitals Section
    contentBlocks.add("vitals_section");

    // 5. Interleave remaining media and prompts (Starting from index 1)
    int mediaBlockIndex = 1; // Index within the displayed media blocks
    int promptIndex = 1;

    // Find the actual number of remaining media items to display
    int remainingMediaCount =
        mediaUrls.length - 1; // Exclude the first one (handled in gallery)

    int maxRemaining = max(remainingMediaCount, prompts.length - 1);

    for (int i = 0; i < maxRemaining; i++) {
      // Add remaining prompts first
      if (promptIndex < prompts.length) {
        contentBlocks.add(prompts[promptIndex]);
        promptIndex++;
      }
      // Add remaining media after prompts (if any) - Now handled by Media Gallery
      // if (mediaBlockIndex < remainingMediaCount) {
      //    // Calculate the correct URL index (since first is handled by gallery)
      //    if (mediaBlockIndex < mediaUrls.length) { // Double check bounds
      //       contentBlocks.add(mediaUrls[mediaBlockIndex]);
      //    }
      //    mediaBlockIndex++;
      // }
    }
    // Add remaining prompts if media ran out first
    while (promptIndex < prompts.length) {
      contentBlocks.add(prompts[promptIndex]);
      promptIndex++;
    }

    // 6. Add Audio Prompt (if available, else empty section)
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
        onRefresh: () async {
          if (!_isEditing) {
            // Allow refresh only when not editing
            await ref.read(userProvider.notifier).fetchProfile();
          }
        },
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
              title: Text(_isEditing ? "Edit Profile" : "Profile",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              actions: _isEditing
                  ? [
                      // Actions in Edit Mode
                      if (_isSaving) // Show loading indicator instead of buttons
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else ...[
                        TextButton(
                          onPressed: _cancelEditMode,
                          child: Text("Cancel",
                              style: GoogleFonts.poppins(color: Colors.grey)),
                        ),
                        TextButton(
                          onPressed: _handleSave,
                          child: Text("Save",
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFF8B5CF6),
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ]
                  : [
                      // Actions in View Mode
                      _buildTopIconButton(
                          icon: Icons.edit_outlined,
                          tooltip: 'Edit Profile',
                          onPressed: _enterEditMode),
                      const SizedBox(width: 8),
                      _buildTopIconButton(
                          icon: Icons.settings_outlined,
                          tooltip: 'Settings',
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const SettingsScreen()))),
                      const SizedBox(width: 8),
                    ],
            ),

            // Use SliverList with ListView.builder equivalent logic
            SliverPadding(
              padding: const EdgeInsets.only(top: 8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = contentBlocks[index];
                    final double bottomPadding = 24.0; // Consistent spacing
                    final double horizontalPadding =
                        16.0; // Consistent horizontal padding

                    Widget contentWidget;

                    // Build content based on type
                    if (item is String && item == "header_section") {
                      contentWidget = _buildHeaderBlock(user);
                    } else if (item is String && item == "media_gallery") {
                      contentWidget = _buildMediaGallery(
                          context, ref, mediaUrls); // Use gallery builder
                    }
                    // Handle empty sections with edit callbacks
                    else if (item is String && item == "empty_media_section") {
                      contentWidget = _buildEmptySection(
                          "Photos & Videos",
                          "Add photos and videos to show off your personality!",
                          Icons.add_photo_alternate_outlined,
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const MediaPickerScreen(
                                      isEditing: true))));
                    } else if (item is String &&
                        item == "empty_prompt_section") {
                      contentWidget = _buildEmptySection(
                          "About Me",
                          "Add prompt answers to share more about yourself!",
                          Icons.chat_bubble_outline,
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      ProfileAnswersScreen(isEditing: true))));
                    } else if (item is String &&
                        item == "empty_audio_section") {
                      contentWidget = _buildEmptySection(
                          "Voice Prompt",
                          "Record a voice prompt to let matches hear your voice!",
                          Icons.mic_none_rounded,
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const VoicePromptScreen(
                                      isEditing: true))));
                    }
                    // Handle individual items
                    // else if (item is String && item.startsWith('http')) { // Media items are now handled by the gallery
                    //   contentWidget = _buildMediaItem(item);
                    // }
                    else if (item is Prompt) {
                      // Find the original index of this prompt for editing
                      int promptEditIndex = user.prompts
                          .indexWhere((p) => p.question == item.question);
                      contentWidget = _buildPromptItem(item,
                          onEditTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => TextSelectPromptScreen(
                                      isEditing: true,
                                      editIndex: promptEditIndex >= 0
                                          ? promptEditIndex
                                          : null))));
                    } else if (item is AudioPromptModel) {
                      contentWidget = _buildAudioItem(item,
                          onEditTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const VoicePromptScreen(
                                      isEditing: true))));
                    } else if (item is String && item == "vitals_section") {
                      contentWidget = _buildVitalsBlock(user,
                          onEditTap: () =>
                              _navigateToVitalsEditFlow() // Navigate to first vitals screen
                          );
                    } else {
                      contentWidget = const SizedBox.shrink();
                    }

                    // Wrap content with Padding
                    return Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPadding, 0,
                          horizontalPadding, bottomPadding),
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

  // --- Block Builder Widgets (Adapted for ProfileScreen with Edit Icons) ---

  Widget _buildHeaderBlock(UserModel user) {
    // (No edit icon needed here based on requirements)
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
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
              height: 1.2),
        ),
        const SizedBox(height: 12),
        if (user.gender != null ||
            (user.hometown != null && user.hometown!.isNotEmpty))
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              // These are not editable per requirements
              if (user.gender != null)
                _buildDetailChip(
                    Icons.person_outline_rounded, user.gender!.label,
                    subtle: true),
              if (user.hometown != null && user.hometown!.isNotEmpty)
                _buildDetailChip(Icons.location_on_outlined, user.hometown!,
                    subtle: true),
              // --- ADD EDITABLE CHIP ---
              if (user.datingIntention != null)
                _buildEditableChip(
                    icon: Icons.favorite_border_rounded,
                    label: user.datingIntention!.label,
                    onEditTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const DatingIntentionsScreen(isEditing: true))),
                    subtle: true)
              else if (_isEditing) // Show add button if editing and no intention set
                _buildAddChip(
                    label: "Add Intention",
                    onAddTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const DatingIntentionsScreen(isEditing: true))),
                    subtle: true),
            ],
          ),
      ],
    );
  }

  // --- NEW: Media Gallery Builder ---
  Widget _buildMediaGallery(
      BuildContext context, WidgetRef ref, List<String> mediaUrls) {
    // Use a GridView or similar to display media items.
    // Add an Edit button visible only in _isEditing mode.
    return Stack(
      children: [
        if (mediaUrls.isEmpty)
          _buildEmptySection(
            "Photos & Videos",
            "Add photos and videos to show off your personality!",
            Icons.add_photo_alternate_outlined,
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const MediaPickerScreen(isEditing: true))),
          )
        else
          Container(
            // Simple GridView example - adjust styling as needed
            constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * 0.5), // Limit height
            child: GridView.builder(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(), // Disable grid scrolling, rely on CustomScrollView
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0, // Square aspect ratio
              ),
              itemCount: mediaUrls.length,
              itemBuilder: (context, index) {
                final url = mediaUrls[index];
                final isVideo = url.toLowerCase().endsWith('.mp4') ||
                    url.toLowerCase().endsWith('.mov');
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image)),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Center(
                                child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null)),
                      ),
                      if (isVideo)
                        const Center(
                            child: Icon(Icons.play_circle_fill,
                                color: Colors.white70, size: 30)),
                    ],
                  ),
                );
              },
            ),
          ),

        // Centralized Edit Button for the Gallery
        if (_isEditing && mediaUrls.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: _buildSmallEditButton(
              tooltip: "Edit Media",
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          const MediaPickerScreen(isEditing: true))),
            ),
          ),
      ],
    );
  }
  // --- END NEW Media Gallery Builder ---

  Widget _buildPromptItem(Prompt prompt, {required VoidCallback onEditTap}) {
    if (prompt.answer.trim().isEmpty && !_isEditing)
      return const SizedBox.shrink(); // Hide empty in view mode

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
      child: Stack(
        // Use Stack for edit button
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prompt.question.label,
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8B5CF6))),
              const SizedBox(height: 10),
              if (prompt.answer.trim().isNotEmpty)
                Text(prompt.answer,
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[850],
                        height: 1.5,
                        fontWeight: FontWeight.w500))
              else if (_isEditing) // Show placeholder if editing and empty
                Text("Tap edit to add your answer...",
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic)),
            ],
          ),
          // Edit button overlay
          if (_isEditing)
            Positioned(
              top: -8, // Adjust position
              right: -8, // Adjust position
              child: _buildSmallEditButton(onPressed: onEditTap),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioItem(AudioPromptModel audio,
      {required VoidCallback onEditTap}) {
    final bool isThisPlaying = _currentAudioUrl == audio.audioUrl && _isPlaying;
    final bool isThisPaused = _currentAudioUrl == audio.audioUrl &&
        !_isPlaying &&
        _audioPlayer.state == PlayerState.paused;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            // Add Row for title and edit button
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Voice Prompt",
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A))),
              if (_isEditing)
                _buildSmallEditButton(
                    onPressed: onEditTap, tooltip: "Edit Voice Prompt"),
            ],
          ),
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
                      ]),
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
                      Text(
                          isThisPlaying
                              ? "Playing..."
                              : (isThisPaused ? "Paused" : "Tap to listen"),
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

  Widget _buildVitalsBlock(UserModel user, {required VoidCallback onEditTap}) {
    final List<Widget> vitals = [];
    // Use _buildEditableChip for editable vitals
    if (user.height != null && user.height!.isNotEmpty)
      vitals.add(_buildEditableChip(
          icon: Icons.height_rounded,
          label: user.height!,
          onEditTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const HeightSelectionScreen(isEditing: true)))));
    if (user.religiousBeliefs != null)
      vitals.add(_buildEditableChip(
          icon: Icons.church_outlined,
          label: user.religiousBeliefs!.label,
          onEditTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const ReligionScreen(isEditing: true)))));
    if (user.jobTitle != null && user.jobTitle!.isNotEmpty)
      vitals.add(_buildEditableChip(
          icon: Icons.work_outline_rounded,
          label: user.jobTitle!,
          onEditTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const JobTitleScreen(isEditing: true)))));
    if (user.education != null && user.education!.isNotEmpty)
      vitals.add(_buildEditableChip(
          icon: Icons.school_outlined,
          label: user.education!,
          onEditTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const StudyLocationScreen(isEditing: true)))));
    if (user.drinkingHabit != null)
      vitals.add(_buildEditableChip(
          icon: Icons.local_bar_outlined,
          label: "Drinks: ${user.drinkingHabit!.label}",
          onEditTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const DrinkingScreen(isEditing: true)))));
    if (user.smokingHabit != null)
      vitals.add(_buildEditableChip(
          icon: Icons.smoking_rooms_outlined,
          label: "Smokes: ${user.smokingHabit!.label}",
          onEditTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const SmokingScreen(isEditing: true)))));

    // Add "Add" buttons if editing and field is empty
    if (_isEditing) {
      if (user.height == null || user.height!.isEmpty)
        vitals.add(_buildAddChip(
            label: "Add Height",
            onAddTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const HeightSelectionScreen(isEditing: true)))));
      if (user.religiousBeliefs == null)
        vitals.add(_buildAddChip(
            label: "Add Religion",
            onAddTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const ReligionScreen(isEditing: true)))));
      if (user.jobTitle == null || user.jobTitle!.isEmpty)
        vitals.add(_buildAddChip(
            label: "Add Job",
            onAddTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const JobTitleScreen(isEditing: true)))));
      if (user.education == null || user.education!.isEmpty)
        vitals.add(_buildAddChip(
            label: "Add Education",
            onAddTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const StudyLocationScreen(isEditing: true)))));
      if (user.drinkingHabit == null)
        vitals.add(_buildAddChip(
            label: "Add Drinking Habit",
            onAddTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const DrinkingScreen(isEditing: true)))));
      if (user.smokingHabit == null)
        vitals.add(_buildAddChip(
            label: "Add Smoking Habit",
            onAddTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const SmokingScreen(isEditing: true)))));
    }

    if (vitals.isEmpty && !_isEditing) {
      // Hide if empty and not editing
      return const SizedBox.shrink();
    }
    if (vitals.isEmpty && _isEditing) {
      // Show empty section if editing and empty
      return _buildEmptySection(
          "Vitals & Habits",
          "Add more details like your height, job, habits, etc.",
          Icons.list_alt_rounded,
          onEditTap // Pass the main edit tap handler
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            // Row for title and edit button
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Vitals & Habits",
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A))),
              if (_isEditing &&
                  vitals.isNotEmpty) // Show edit only if editing and not empty
                _buildSmallEditButton(
                    onPressed: onEditTap, tooltip: "Edit Vitals"),
            ],
          ),
        ),
        Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 0, vertical: 8), // Reduced padding
            width: double.infinity,
            // Removed background decoration - let chips handle their own style
            child: Wrap(
              // Use Wrap for better layout
              spacing: 8,
              runSpacing: 8,
              children: vitals,
            )),
      ],
    );
  }

  // --- NEW: Editable Chip Widget ---
  Widget _buildEditableChip({
    required IconData icon,
    required String label,
    required VoidCallback onEditTap,
    bool subtle = false,
  }) {
    if (label.isEmpty) return const SizedBox.shrink();
    return InkWell(
      // Make chip tappable in edit mode
      onTap: _isEditing ? onEditTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
            Icon(icon,
                size: subtle ? 16 : 18,
                color: subtle ? Colors.grey.shade600 : const Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            Flexible(
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: subtle ? 13 : 14,
                        fontWeight: FontWeight.w500,
                        color:
                            subtle ? Colors.grey.shade700 : Colors.grey[800]),
                    overflow: TextOverflow.ellipsis)),
            if (_isEditing) ...[
              // Show mini edit icon if editing
              const SizedBox(width: 6),
              Icon(Icons.edit, size: 14, color: Colors.grey[500]),
            ]
          ],
        ),
      ),
    );
  }
  // --- END NEW Editable Chip ---

  // --- NEW: Add Chip Widget ---
  Widget _buildAddChip({
    required String label,
    required VoidCallback onAddTap,
    bool subtle = false,
  }) {
    return InkWell(
      onTap: onAddTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: subtle ? 10 : 12, vertical: subtle ? 6 : 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.grey.shade400,
              style: BorderStyle
                  .solid), // Dashed border? DottedBorder package needed
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline,
                size: subtle ? 16 : 18, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Flexible(
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: subtle ? 13 : 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
  // --- END NEW Add Chip ---

  // Helper to navigate to the start of the vitals editing flow
  // This might need refinement if you want specific edit targets
  void _navigateToVitalsEditFlow() {
    // Start with Height as an example
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                const HeightSelectionScreen(isEditing: true)));
    // You might chain navigations or create a dedicated "Edit Vitals" screen
  }
} // End of _ProfileScreenState
