import 'dart:math';
import 'dart:io';

// Keep necessary imports...
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
import 'package:path/path.dart' as path; // Import path package
import 'package:mime/mime.dart'; // Import mime package

import 'package:dtx/models/user_model.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/settings_screen.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/service_provider.dart'; // Keep
import 'package:dtx/providers/media_upload_provider.dart'; // Keep
import 'package:dtx/services/api_service.dart'; // Keep
// Import audio player provider for audio playback UI state (Global player, not local)
// Keep import if global player UI is needed elsewhere, but playback uses local _audioPlayer
import 'package:dtx/providers/audio_player_provider.dart';
// Import MediaRepository provider
import 'package:dtx/repositories/media_repository.dart'; // Import MediaRepository

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Retain state for Audio Player, Edit Mode, Saving, Original Data
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentAudioUrl;
  bool _isEditing = false;
  bool _isSaving = false;
  UserModel? _originalProfileData; // To store data before editing starts

  @override
  void initState() {
    super.initState();
    // Fetch profile if needed (e.g., if user lands directly here after login)
    // Moved fetching logic primarily to MainNavigationScreen
    _setupLocalAudioPlayerListeners();
  }

  void _setupLocalAudioPlayerListeners() {
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
  }

  @override
  void dispose() {
    try {
      if (_audioPlayer.state == PlayerState.playing ||
          _audioPlayer.state == PlayerState.paused) {
        _audioPlayer.stop();
      }
      _audioPlayer.release();
      _audioPlayer.dispose();
    } catch (e) {
      print("Error releasing/disposing local audio player: $e");
    }
    super.dispose();
  }

  // --- Local Audio Control --- (Keep as is)
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
        await _audioPlayer.setSource(UrlSource(audioUrl));
        await _audioPlayer.resume();
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

  // --- Edit Mode Handlers (_enterEditMode, _cancelEditMode) ---
  void _enterEditMode() {
    _originalProfileData = ref.read(userProvider); // Store original state
    ref.read(userProvider.notifier).setMediaChangedFlag(false); // Reset flag
    setState(() => _isEditing = true);
  }

  void _cancelEditMode() {
    if (_originalProfileData != null) {
      // Restore state ONLY if media hasn't changed during the edit process
      // If media DID change, it's complex to revert provider state easily,
      // so we might just refetch or accept the userProvider's current state.
      // For simplicity, let's just refetch if media changed.
      if (!ref.read(userProvider).mediaChangedDuringEdit) {
        print("[ProfileScreen] Cancelling edit, restoring original data.");
        ref.read(userProvider.notifier).state = _originalProfileData!;
      } else {
        print("[ProfileScreen] Cancelling edit, media changed, refetching.");
        // Optionally clear the flag before refetching
        ref.read(userProvider.notifier).setMediaChangedFlag(false);
        ref.read(userProvider.notifier).fetchProfile();
      }
    } else {
      print("[ProfileScreen] Cancelling edit, no original data, refetching.");
      ref
          .read(userProvider.notifier)
          .fetchProfile(); // Refetch if original is missing
    }
    ref.read(errorProvider.notifier).clearError(); // Clear any edit errors
    setState(() => _isEditing = false);
  }

  // --- *** UPDATED Save Handler *** ---
  Future<void> _handleSave() async {
    print("[ProfileScreen _handleSave] Starting Save Process...");
    final errorNotifier = ref.read(errorProvider.notifier)..clearError();
    if (!mounted) return;
    setState(() => _isSaving = true); // Show loading indicator

    final userState = ref.read(userProvider);
    final userNotifier = ref.read(userProvider.notifier);
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final userRepo = ref.read(userRepositoryProvider);

    // Use original data for comparison if available, else current state
    final initialMediaUrls =
        _originalProfileData?.mediaUrls ?? userState.mediaUrls ?? [];
    final currentMediaIdentifiers =
        List<String>.from(userState.mediaUrls ?? []); // List from userProvider

    List<String> finalMediaUrls = []; // To store the final list of S3 URLs
    List<Map<String, String>> filesToUploadDetails = [];
    List<MediaUploadModel> fileModelsToUpload = []; // Keep models for S3 upload

    try {
      // --- Identify Files vs Existing URLs ---
      print("[ProfileScreen _handleSave] Identifying files vs URLs...");
      for (int i = 0; i < currentMediaIdentifiers.length; i++) {
        final identifier = currentMediaIdentifiers[i];
        if (identifier.isEmpty) continue; // Skip empty slots

        bool isLocalFile = false;
        File? potentialFile;
        try {
          // Check if it's an absolute path (common on mobile) or relative
          Uri? uri = Uri.tryParse(identifier);
          if (uri != null &&
              !uri.isAbsolute &&
              !identifier.startsWith('http')) {
            // If it's not an absolute URI and not HTTP(S), treat as potential file path
            isLocalFile = true;
          } else if (identifier.startsWith('/')) {
            // Catch explicit absolute paths like /data/user/...
            isLocalFile = true;
          }

          if (isLocalFile) {
            potentialFile = File(identifier);
            // Check existence *only* if it looks like a file path
            isLocalFile = await potentialFile.exists();
          }
        } catch (e) {
          print("Error checking file path '$identifier': $e");
          isLocalFile = false;
        }

        if (isLocalFile && potentialFile != null) {
          print("  - Found Local File at index $i: ${potentialFile.path}");
          final fileName = path.basename(potentialFile.path);
          final mimeType =
              lookupMimeType(potentialFile.path) ?? 'application/octet-stream';
          filesToUploadDetails.add({'filename': fileName, 'type': mimeType});
          // Store the model WITH the file object for later upload
          fileModelsToUpload.add(MediaUploadModel(
            file: potentialFile,
            fileName: fileName,
            fileType: mimeType,
            // presignedUrl will be added later
          ));
        } else if (identifier.startsWith('http')) {
          print("  - Found Existing URL at index $i: $identifier");
          // Add existing URL directly to the final list for now
          // We'll reconstruct the order later
        } else {
          print(
              "  - Warning: Skipping invalid identifier at index $i: $identifier");
        }
      }
      print(
          "[ProfileScreen _handleSave] Files to upload: ${fileModelsToUpload.length}");

      // --- Upload Files if Needed ---
      Map<String, String> uploadedUrlMap =
          {}; // Map original path -> new S3 URL
      if (fileModelsToUpload.isNotEmpty) {
        print(
            "[ProfileScreen _handleSave] Getting presigned URLs for ${fileModelsToUpload.length} files...");
        final presignedUrlsResponse =
            await mediaRepo.getEditPresignedUrls(filesToUploadDetails);

        if (presignedUrlsResponse.length != fileModelsToUpload.length) {
          throw ApiException("Mismatch in number of presigned URLs received.");
        }

        // Prepare models with URLs for upload
        List<Future<bool>> uploadFutures = [];
        for (int i = 0; i < fileModelsToUpload.length; i++) {
          final fileModel = fileModelsToUpload[i];
          final urlData = presignedUrlsResponse.firstWhere(
              (u) =>
                  u['filename'] == fileModel.fileName &&
                  u['type'] == fileModel.fileType,
              orElse: () => throw ApiException(
                  "Could not find presigned URL for ${fileModel.fileName}"));
          final presignedUrl = urlData['url'] as String;

          final modelWithUrl =
              fileModel.copyWith(presignedUrl: () => presignedUrl);
          fileModelsToUpload[i] = modelWithUrl; // Update the model in the list

          print(
              "[ProfileScreen _handleSave] Uploading ${fileModel.fileName}...");
          // Use retryUpload for robustness
          uploadFutures.add(mediaRepo.retryUpload(modelWithUrl).then((success) {
            if (success) {
              // Store mapping from original file path to S3 URL
              uploadedUrlMap[fileModel.file.path] = presignedUrl
                  .split('?')
                  .first; // Store URL without query params
            }
            return success;
          }));
        }

        final uploadResults = await Future.wait(uploadFutures);
        if (uploadResults.any((success) => !success)) {
          // Find which one failed for better logging (optional)
          for (int i = 0; i < uploadResults.length; ++i) {
            if (!uploadResults[i]) {
              print("❌ Upload failed for: ${fileModelsToUpload[i].fileName}");
            }
          }
          throw ApiException("One or more media uploads failed.");
        }
        print("[ProfileScreen _handleSave] All media uploads successful.");
      } else {
        print("[ProfileScreen _handleSave] No new files to upload.");
      }

      // --- Reconstruct Final URL List ---
      print("[ProfileScreen _handleSave] Reconstructing final URL list...");
      for (final identifier in currentMediaIdentifiers) {
        if (identifier.isEmpty) continue;

        if (uploadedUrlMap.containsKey(identifier)) {
          // It was a local file that was successfully uploaded
          final s3Url = uploadedUrlMap[identifier];
          if (s3Url != null) {
            finalMediaUrls.add(s3Url);
            print("  - Adding New URL: $s3Url (from $identifier)");
          } else {
            print(
                "  - Warning: Uploaded file path $identifier not found in URL map.");
          }
        } else if (identifier.startsWith('http')) {
          // It was an existing URL
          finalMediaUrls.add(identifier);
          print("  - Adding Existing URL: $identifier");
        }
        // Skip invalid identifiers already warned about
      }
      print("[ProfileScreen _handleSave] Final URLs: $finalMediaUrls");

      // --- Validate Final Media Count ---
      if (finalMediaUrls.length < 3) {
        throw ApiException(
            "Profile must have at least 3 media items after saving.");
      }

      // --- Prepare PATCH Payload ---
      final latestUserState = ref.read(userProvider); // Read latest state again
      Map<String, dynamic> payload = latestUserState.toJsonForEdit();
      payload['media_urls'] =
          finalMediaUrls; // Use the final reconstructed list

      // Remove non-editable fields just in case
      payload.removeWhere((key, value) => [
            'name',
            'last_name',
            'date_of_birth',
            'latitude',
            'longitude',
            'gender',
            'id',
            'email',
            'phone_number',
            'created_at',
            'verification_status',
            'role',
            'verification_pic'
          ].contains(key));

      print("[ProfileScreen _handleSave] Preparing PATCH payload: $payload");

      // --- Call API ---
      print("[ProfileScreen _handleSave] Calling userRepo.editProfile...");
      final bool success = await userRepo.editProfile(payload);

      if (success) {
        print("[ProfileScreen _handleSave] Profile edit successful.");
        // Update user provider with final URLs and reset flags
        userNotifier.updateMediaUrls(
            finalMediaUrls); // updateMediaUrls now resets the flag internally
        _originalProfileData = ref
            .read(userProvider); // Update original data after successful save

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
            "[ProfileScreen _handleSave] Profile edit failed (API returned false).");
        if (mounted && ref.read(errorProvider) == null) {
          errorNotifier
              .setError(AppError.server("Failed to save profile changes."));
        }
      }
    } on ApiException catch (e) {
      print(
          "[ProfileScreen _handleSave] Save failed: API Exception - ${e.message}");
      if (mounted) errorNotifier.setError(AppError.server(e.message));
    } catch (e, stack) {
      print("[ProfileScreen _handleSave] Save failed: Unexpected error - $e");
      print(stack);
      if (mounted) {
        errorNotifier
            .setError(AppError.generic("An unexpected error occurred."));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false); // Hide loading indicator
    }
  }
  // --- *** END UPDATED Save Handler *** ---

  // --- Helper Methods --- (Keep capitalizeFirstLetter, _buildTopIconButton, _buildEmptySection, _buildDetailChip, _buildSmallEditButton as is)
  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isDisabled = false,
    Color? color,
  }) {
    final iconColor =
        isDisabled ? Colors.grey[400] : (color ?? const Color(0xFF8B5CF6));
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey[200] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      tooltip: isDisabled ? null : tooltip,
      onPressed: isDisabled ? null : onPressed,
    );
  }

  Widget _buildEmptySection(
      String title, String message, IconData icon, VoidCallback? onEditTap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      margin: const EdgeInsets.symmetric(
          vertical: 16), // Keep margin for consistency
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!)),
      child: Stack(children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800])),
            const SizedBox(height: 16), // Add space below title
            Icon(icon, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
        if (_isEditing && onEditTap != null)
          Positioned(
            top: 8,
            right: 8,
            child: _buildSmallEditButton(
                onPressed: onEditTap, tooltip: 'Add $title'),
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

  Widget _buildSmallEditButton(
      {required VoidCallback onPressed,
      IconData icon = Icons.edit_outlined,
      String? tooltip = 'Edit'}) {
    return Material(
      color: Colors.white.withOpacity(0.8),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3)
            ],
          ),
          child: Icon(icon, color: const Color(0xFF8B5CF6), size: 18),
        ),
      ),
    );
  }
  // --- END Helper Methods ---

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isLoadingProfile = ref.watch(userLoadingProvider);
    // Watch for API errors specifically during save
    final apiError = ref.watch(errorProvider);

    // --- Loading State --- (Keep as is)
    if (isLoadingProfile && user.name == null && !_isEditing) {
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
            ]),
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
      );
    }

    // --- Error State (Display non-saving errors) ---
    // Only show general API errors if NOT currently in the saving process
    if (apiError != null && !_isSaving) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text("Profile Error",
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 15),
                Text("Could not load profile",
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(apiError.message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.grey[600])),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    ref.read(errorProvider.notifier).clearError();
                    ref.read(userProvider.notifier).fetchProfile();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white),
                  child: const Text("Retry"),
                )
              ],
            ),
          ),
        ),
      );
    }

    // --- Prepare Content Blocks (Logic remains the same) ---
    final List<dynamic> contentBlocks = [];
    final currentMedia = user.mediaUrls ?? [];
    final prompts = user.prompts;

    contentBlocks.add("header_section");

    if (currentMedia.isNotEmpty) {
      // Add the first media item or an empty placeholder if editing
      contentBlocks
          .add({"type": "media", "value": currentMedia[0], "index": 0});
    } else if (_isEditing) {
      contentBlocks.add("empty_media_section");
    }

    if (prompts.isNotEmpty) {
      contentBlocks.add(prompts[0]);
    } else if (_isEditing) {
      contentBlocks.add("empty_prompt_section");
    }

    contentBlocks.add("vitals_section"); // Always add vitals section wrapper

    int mediaIndex = 1;
    int promptIndex = 1;
    // Use max of lengths OR 6/3 if editing to show empty slots potentially
    int maxMediaSlots = _isEditing ? 6 : currentMedia.length;
    int maxPromptSlots = _isEditing ? 3 : prompts.length;
    int maxRemaining = max(maxMediaSlots, maxPromptSlots);

    for (int i = 1; i < maxRemaining; i++) {
      // Add Media (existing or empty slot if editing)
      if (mediaIndex < maxMediaSlots) {
        if (mediaIndex < currentMedia.length) {
          contentBlocks.add({
            "type": "media",
            "value": currentMedia[mediaIndex],
            "index": mediaIndex
          });
        } else if (_isEditing) {
          // Add placeholder for potential add in media picker
          contentBlocks.add({"type": "empty_media_slot", "index": mediaIndex});
        }
        mediaIndex++;
      }
      // Add Prompt (existing or empty slot if editing)
      if (promptIndex < maxPromptSlots) {
        if (promptIndex < prompts.length) {
          contentBlocks.add(prompts[promptIndex]);
        } else if (_isEditing) {
          // Add placeholder for potential add in prompt editor
          contentBlocks
              .add({"type": "empty_prompt_slot", "index": promptIndex});
        }
        promptIndex++;
      }
    }

    // Add Audio Prompt (existing or empty slot if editing)
    if (user.audioPrompt != null) {
      contentBlocks.add(user.audioPrompt!);
    } else if (_isEditing) {
      contentBlocks.add("empty_audio_section");
    }
    // --- End Content Block Preparation ---

    // --- Build UI ---
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(// Use Stack for loading overlay
          children: [
        RefreshIndicator(
          color: const Color(0xFF8B5CF6),
          onRefresh: () async {
            if (!_isEditing) {
              ref
                  .read(errorProvider.notifier)
                  .clearError(); // Clear error on refresh
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
                        /* Save/Cancel Actions */
                        TextButton(
                            onPressed: _isSaving
                                ? null
                                : _cancelEditMode, // Disable during save
                            child: Text("Cancel",
                                style: GoogleFonts.poppins(
                                    color: _isSaving
                                        ? Colors.grey[400]
                                        : Colors.grey))),
                        TextButton(
                            onPressed: _isSaving
                                ? null
                                : _handleSave, // Disable during save
                            child: Text("Save",
                                style: GoogleFonts.poppins(
                                    color: _isSaving
                                        ? Colors.grey[400]
                                        : const Color(0xFF8B5CF6),
                                    fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                      ]
                    : [
                        /* View Mode Actions */
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

              // --- Main Content List ---
              SliverPadding(
                padding: const EdgeInsets.only(top: 8.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = contentBlocks[index];
                      final double bottomPadding = 24.0;
                      final double horizontalPadding = 16.0;
                      Widget contentWidget;

                      // Build content based on type
                      if (item is String && item == "header_section") {
                        contentWidget = _buildHeaderBlock(user);
                      }
                      // Handle Empty Sections (Placeholders shown during edit)
                      else if (item is String &&
                          item == "empty_media_section") {
                        contentWidget = _buildEmptySection(
                            "Photos & Videos",
                            "Add photos and videos!",
                            Icons.add_photo_alternate_outlined,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const MediaPickerScreen(
                                            isEditing: true))));
                      } else if (item is String &&
                          item == "empty_prompt_section") {
                        contentWidget = _buildEmptySection(
                            "About Me",
                            "Add prompt answers!",
                            Icons.chat_bubble_outline,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ProfileAnswersScreen(
                                        isEditing: true))));
                      } else if (item is String &&
                          item == "empty_audio_section") {
                        contentWidget = _buildEmptySection(
                            "Voice Prompt",
                            "Record a voice prompt!",
                            Icons.mic_none_rounded,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const VoicePromptScreen(
                                            isEditing: true))));
                      } else if (item is Map &&
                          item["type"] == "empty_media_slot") {
                        contentWidget = _buildEmptyMediaSlot(() =>
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const MediaPickerScreen(
                                            isEditing: true))));
                      } else if (item is Map &&
                          item["type"] == "empty_prompt_slot") {
                        contentWidget = _buildEmptyPromptSlot(
                            item["index"],
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => TextSelectPromptScreen(
                                        isEditing:
                                            true)))); // Pass index if needed later
                      }

                      // Handle Content Items
                      else if (item is Map && item["type"] == "media") {
                        String displayValue = item["value"];
                        bool isLocalFile = false;
                        // More robust check if it's a local file path vs URL
                        if (!displayValue.startsWith('http') &&
                            (displayValue.contains('/') ||
                                displayValue.contains('\\'))) {
                          // Basic check: Doesn't start with http and contains path separators
                          // A more reliable check might involve trying File(displayValue).exists() but that's async
                          isLocalFile = true;
                        }
                        contentWidget = _buildMediaItem(
                            context, ref, displayValue, item["index"],
                            isLocalFile: isLocalFile);
                      } else if (item is Prompt) {
                        int promptEditIndex = user.prompts
                            .indexWhere((p) => p.question == item.question);
                        contentWidget = _buildPromptItem(item,
                            onEditTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        TextSelectPromptScreen(
                                            isEditing: true,
                                            editIndex: promptEditIndex >= 0
                                                ? promptEditIndex
                                                : null))));
                      } else if (item is AudioPromptModel) {
                        contentWidget = _buildAudioItem(item,
                            onEditTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const VoicePromptScreen(
                                            isEditing: true))));
                      } else if (item is String && item == "vitals_section") {
                        contentWidget = _buildVitalsBlock(user,
                            onEditTap: _navigateToVitalsEditFlow);
                      } else {
                        contentWidget = const SizedBox.shrink();
                      }

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
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
        // --- Loading Overlay ---
        if (_isSaving)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              ),
            ),
          ),
      ]),
    );
  }

  // --- Block Builder Widgets (Adapted for ProfileScreen) ---

  Widget _buildHeaderBlock(UserModel user) {
    // (Keep as is)
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
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            // Non-editable
            if (user.gender != null)
              _buildDetailChip(Icons.person_outline_rounded, user.gender!.label,
                  subtle: true),
            // Editable - Hometown (Now editable via Vitals flow)
            if (user.hometown != null && user.hometown!.isNotEmpty)
              _buildEditableChip(
                icon: Icons.location_on_outlined,
                label: user.hometown!,
                onEditTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const HometownScreen(isEditing: true))),
                subtle: true, // Keep subtle look
              )
            else if (_isEditing)
              _buildAddChip(
                  label: "Add Hometown",
                  onAddTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const HometownScreen(isEditing: true))),
                  subtle: true),

            // Editable - Dating Intention
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
            else if (_isEditing)
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

  // --- Modified Media Item Builder ---
  Widget _buildMediaItem(
      BuildContext context, WidgetRef ref, String urlOrPath, int index,
      {required bool isLocalFile}) {
    bool isVideo = false;
    if (!isLocalFile) {
      // Basic URL check for video extensions
      final lowerUrl = urlOrPath.toLowerCase();
      isVideo = ['.mp4', '.mov', '.avi', '.mpeg', '.mpg', '.3gp', '.ts', '.mkv']
          .any((ext) => lowerUrl.endsWith(ext));
    } else {
      // Use MIME type for local files if possible, fallback to extension
      final mimeType = lookupMimeType(urlOrPath);
      if (mimeType != null) {
        isVideo = mimeType.startsWith('video/');
      } else {
        // Fallback extension check for local files
        String ext = path.basename(urlOrPath).split('.').last.toLowerCase();
        isVideo = ['mp4', 'mov', 'avi', 'mpeg', 'mpg', '3gp', 'ts', 'mkv']
            .contains(ext);
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 4 / 5.5,
        child: Container(
          decoration: BoxDecoration(color: Colors.grey[200]),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Display Image/Video Thumbnail
              if (isLocalFile)
                Image.file(File(urlOrPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image))
              else
                Image.network(urlOrPath,
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
              // Video indicator
              if (isVideo)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),

              // *** --- START FIX: Edit Button Condition --- ***
              // Show edit button if _isEditing, regardless of index
              if (_isEditing)
                // *** --- END FIX --- ***
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildSmallEditButton(
                      icon: Icons.edit, // Use edit icon
                      tooltip: "Edit Media Gallery",
                      onPressed: () async {
                        // Make async
                        // --- ADDED: Clear media provider before navigating ---
                        print(
                            "[ProfileScreen] Clearing mediaUploadProvider before navigating to MediaPickerScreen (Edit).");
                        ref.read(mediaUploadProvider.notifier).state =
                            List.filled(6, null);
                        // --- END ADDED ---
                        await Navigator.push(
                            // Await navigation
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const MediaPickerScreen(isEditing: true)));
                        // Optional: Force rebuild or state sync after returning?
                        // Not strictly necessary if MediaPickerScreen correctly updates userProvider.
                      }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NEW: Empty Media Slot ---
  Widget _buildEmptyMediaSlot(VoidCallback onEditTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 4 / 5.5,
        child: Material(
          color: Colors.grey[100],
          child: InkWell(
            onTap: onEditTap, // Navigate to media picker
            child: Center(
              child: Icon(Icons.add_photo_alternate_outlined,
                  size: 40, color: Colors.grey[400]),
            ),
          ),
        ),
      ),
    );
  }

  // --- NEW: Empty Prompt Slot ---
  Widget _buildEmptyPromptSlot(int index, VoidCallback onEditTap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!)),
      child: Material(
        // Wrap with Material for InkWell effect
        color: Colors.transparent,
        child: InkWell(
          onTap: onEditTap, // Navigate to prompt selection/writing
          borderRadius: BorderRadius.circular(16), // Match container radius
          child: Padding(
            // Add padding inside InkWell for content
            padding: const EdgeInsets.symmetric(
                vertical: 20), // Adjust vertical padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center content
              children: [
                Icon(Icons.add_circle_outline,
                    color: Colors.grey[400], size: 24),
                const SizedBox(width: 8),
                Text(
                  "Add prompt #${index + 1}",
                  style: GoogleFonts.poppins(
                      fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromptItem(Prompt prompt, {required VoidCallback onEditTap}) {
    // (Keep as is)
    if (prompt.answer.trim().isEmpty && !_isEditing)
      return const SizedBox.shrink();
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
        clipBehavior: Clip.none, // Allow button overflow slightly
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
              else if (_isEditing)
                Text("Tap edit to add your answer...",
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic)),
            ],
          ),
          if (_isEditing) // Show edit button only in edit mode
            Positioned(
              top: -12,
              right: -12,
              child: _buildSmallEditButton(
                  onPressed: onEditTap, tooltip: "Edit Prompt"),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioItem(AudioPromptModel audio,
      {required VoidCallback onEditTap}) {
    // (Keep as is)
    final bool isThisPlaying = _currentAudioUrl == audio.audioUrl && _isPlaying;
    final bool isThisPaused = _currentAudioUrl == audio.audioUrl &&
        !_isPlaying &&
        _audioPlayer.state == PlayerState.paused;

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
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _playOrPauseAudio(audio.audioUrl),
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
                  child: Icon(
                      isThisPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28),
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
          if (_isEditing)
            Positioned(
              top: -12,
              right: -12,
              child: _buildSmallEditButton(
                  onPressed: onEditTap, tooltip: "Edit Voice Prompt"),
            ),
        ],
      ),
    );
  }

  Widget _buildVitalsBlock(UserModel user, {required VoidCallback onEditTap}) {
    // (Keep as is)
    final List<Widget> vitals = [];
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
    // Editable Job/Edu via this block's edit button
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
    // Editable Habits
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

    if (vitals.isEmpty && !_isEditing) return const SizedBox.shrink();
    if (vitals.isEmpty && _isEditing)
      return _buildEmptySection("Vitals & Habits", "Add more details!",
          Icons.list_alt_rounded, onEditTap);

    return Container(
        width: double.infinity,
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
        child: Stack(clipBehavior: Clip.none, children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text("Vitals & Habits",
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A))),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: vitals),
            ],
          ),
          if (_isEditing)
            Positioned(
              top: -12,
              right: -12,
              child: _buildSmallEditButton(
                  onPressed: onEditTap, tooltip: "Edit Vitals"),
            ),
        ]));
  }

  // --- Editable Chip Widget --- (Keep as is)
  Widget _buildEditableChip({
    required IconData icon,
    required String label,
    required VoidCallback onEditTap,
    bool subtle = false,
  }) {
    if (label.isEmpty) return const SizedBox.shrink();
    return InkWell(
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
              const SizedBox(width: 6),
              Icon(Icons.edit, size: 14, color: Colors.grey[500]),
            ]
          ],
        ),
      ),
    );
  }

  // --- Add Chip Widget --- (Keep as is)
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
          border:
              Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
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

  // Helper to navigate to the start of the vitals editing flow (Keep as is)
  void _navigateToVitalsEditFlow() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                const HeightSelectionScreen(isEditing: true)));
  }
} // End of _ProfileScreenState
