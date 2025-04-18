// File: views/profile_screens.dart
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
import 'package:audioplayers/audioplayers.dart';

import 'package:dtx/models/user_model.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/settings_screen.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/media_upload_provider.dart';
import 'package:dtx/services/api_service.dart';
// Import audio player provider for audio playback UI state
import 'package:dtx/providers/audio_player_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Retain state for Audio Player, Edit Mode, Saving, Original Data
  final AudioPlayer _audioPlayer =
      AudioPlayer(); // Use LOCAL player for this screen
  bool _isPlaying = false;
  String? _currentAudioUrl; // Track which URL is playing LOCALLY
  bool _isEditing = false;
  bool _isSaving = false;
  UserModel? _originalProfileData; // To store data before editing starts

  @override
  void initState() {
    super.initState();
    // Setup local audio player listeners
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
    // Dispose local audio player
    try {
      if (_audioPlayer.state == PlayerState.playing ||
          _audioPlayer.state == PlayerState.paused) {
        _audioPlayer.stop();
      }
      _audioPlayer.release(); // Use release for better resource cleanup
      _audioPlayer.dispose();
    } catch (e) {
      print("Error releasing/disposing local audio player: $e");
    }
    super.dispose();
  }

  // --- Local Audio Control ---
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
        // Stop any previous playback before starting new
        if (currentState == PlayerState.playing ||
            currentState == PlayerState.paused) {
          await _audioPlayer.stop();
        }
        await _audioPlayer.setSource(UrlSource(audioUrl)); // Set source first
        await _audioPlayer.resume(); // Start playing
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

  // --- Edit Mode Handlers (_enterEditMode, _cancelEditMode, _handleSave) ---
  void _enterEditMode() {
    _originalProfileData = ref.read(userProvider);
    setState(() => _isEditing = true);
  }

  void _cancelEditMode() {
    if (_originalProfileData != null) {
      ref.read(userProvider.notifier).state = _originalProfileData!;
    } else {
      ref.read(userProvider.notifier).fetchProfile();
    }
    ref.read(userProvider.notifier).setMediaChangedFlag(false);
    setState(() => _isEditing = false);
  }

  Future<void> _handleSave() async {
    print("[ProfileScreen] Starting Save Process...");
    ref.read(errorProvider.notifier).clearError();
    if (!mounted) return;
    setState(() => _isSaving = true);

    final userState = ref.read(userProvider);
    final userNotifier = ref.read(userProvider.notifier);
    List<String> finalMediaUrls = List<String>.from(userState.mediaUrls ?? []);

    try {
      // --- Media Upload Logic ---
      if (userState.mediaChangedDuringEdit) {
        print("[ProfileScreen] Media changed, initiating upload...");
        final mediaUploadNotifier = ref.read(mediaUploadProvider.notifier);
        final currentMediaItems = userState.mediaUrls ?? []; // Mixed list

        final List<File> filesToUpload = [];
        List<File?> filesForProvider = List.filled(6, null);

        for (int i = 0; i < currentMediaItems.length && i < 6; i++) {
          final item = currentMediaItems[i];
          try {
            // More robust check if it's a local file path
            if (Uri.tryParse(item)?.isAbsolute == false ||
                item.startsWith('/')) {
              File potentialFile = File(item);
              if (await potentialFile.exists()) {
                filesToUpload.add(potentialFile);
                filesForProvider[i] = potentialFile;
                print("   - Found new file at index $i: ${potentialFile.path}");
                continue; // Move to next item
              }
            }
            // If it's not a local file, assume it's an existing URL (or invalid)
            if (item.startsWith('http')) {
              print("   - Found existing URL at index $i: $item");
            } else if (item.isNotEmpty) {
              // Avoid logging empty strings if list was padded
              print(
                  "   - Warning: Item at index $i is neither a valid file path nor a URL: $item");
            }
          } catch (e) {
            print("Error checking file existence for item '$item': $e");
          }
        }

        // Check minimum media rule *before* upload attempt
        int finalMediaCount =
            currentMediaItems.where((item) => item.isNotEmpty).length;
        if (finalMediaCount < 3) {
          throw ApiException("Minimum of 3 media items required.");
        }

        if (filesToUpload.isNotEmpty) {
          // Set files in the provider
          for (int i = 0; i < filesForProvider.length; i++) {
            if (filesForProvider[i] != null) {
              mediaUploadNotifier.setMediaFile(i, filesForProvider[i]!);
            } else {
              mediaUploadNotifier
                  .removeMedia(i); // Explicitly remove if slot is now empty
            }
          }

          print("[ProfileScreen] Calling uploadAllMedia...");
          final uploadSuccess = await mediaUploadNotifier.uploadAllMedia();

          if (!uploadSuccess) {
            print("[ProfileScreen] Media upload failed.");
            throw ApiException("Failed to upload media. Please try again.");
          }
          print("[ProfileScreen] Media upload successful.");

          // --- SAFER Reconstruction ---
          final List<String> saferReconstructedUrls = [];
          List<String?> currentItemsAfterEdit = List.from(
              userState.mediaUrls ?? []); // Take the potentially modified list

          int uploadedFileIndex =
              0; // Track index within successfully uploaded files
          // Get the state *after* upload completes
          final uploadedItemsState = ref.read(mediaUploadProvider);
          List<String> successfulUploadUrls = uploadedItemsState
              .where((item) =>
                  item != null &&
                  item.status == UploadStatus.success &&
                  item.presignedUrl != null)
              .map((item) => item!.presignedUrl!)
              .toList();

          for (int i = 0; i < currentItemsAfterEdit.length && i < 6; i++) {
            String item = currentItemsAfterEdit[i] ?? '';
            bool isPotentiallyFile =
                Uri.tryParse(item)?.isAbsolute == false || item.startsWith('/');

            if (item.isEmpty) continue; // Skip empty slots

            bool fileExisted = false;
            if (isPotentiallyFile) {
              try {
                File fileCheck = File(item);
                fileExisted = await fileCheck.exists();
              } catch (e) {
                // Handle potential errors if path is invalid format for File()
                print("Error creating File object for check: $e");
                fileExisted = false;
              }
            }

            if (fileExisted) {
              // If it was a file, use the corresponding uploaded URL
              if (uploadedFileIndex < successfulUploadUrls.length) {
                saferReconstructedUrls
                    .add(successfulUploadUrls[uploadedFileIndex]);
                uploadedFileIndex++;
              } else {
                print(
                    "Warning: Mismatch between files marked for upload and successful uploads. Missing URL for potential file: $item");
              }
            } else if (item.startsWith('http')) {
              // If it's a URL, keep it
              saferReconstructedUrls.add(item);
            }
            // Ignore empty strings or invalid entries implicitly
          }
          finalMediaUrls = saferReconstructedUrls;

          print(
              "[ProfileScreen] Final reconstructed Media URLs: $finalMediaUrls");
        } else {
          print(
              "[ProfileScreen] Media marked changed, but no new files found to upload.");
          // Use the potentially reordered/deleted list, filtering out non-URLs and empty strings
          finalMediaUrls = currentMediaItems
              .where((item) => item.isNotEmpty && item.startsWith('http'))
              .toList();
          // Re-check minimum after potential deletions
          if (finalMediaUrls.length < 3) {
            throw ApiException(
                "Minimum of 3 media items required after edits.");
          }
        }
      } else {
        print("[ProfileScreen] Media not changed, using existing URLs.");
        finalMediaUrls = userState.mediaUrls ?? [];
        // Check minimum media rule even if not changed (in case initial state was invalid)
        if (finalMediaUrls.length < 3) {
          throw ApiException("Minimum of 3 media items required.");
        }
      }
      // --- End Media Upload Logic ---

      // --- Prepare PATCH Payload ---
      final latestUserState = ref.read(userProvider);
      Map<String, dynamic> payload = latestUserState.toJsonForEdit();
      payload['media_urls'] = finalMediaUrls; // Use the final list

      payload.remove('name');
      payload.remove('last_name');
      payload.remove('date_of_birth');
      payload.remove('latitude');
      payload.remove('longitude');
      payload.remove('gender');
      payload.remove('id');

      print("[ProfileScreen] Preparing PATCH payload: $payload");

      // --- Call API ---
      final userRepository = ref.read(userRepositoryProvider);
      final bool success = await userRepository.editProfile(payload);

      if (success) {
        print("[ProfileScreen] Profile edit successful.");
        // Update user provider with final URLs and reset flags
        userNotifier.updateMediaUrls(finalMediaUrls);
        // userNotifier.setMediaChangedFlag(false); // updateMediaUrls should reset it

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
        if (mounted && ref.read(errorProvider) == null) {
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
      print(stack);
      if (mounted)
        ref
            .read(errorProvider.notifier)
            .setError(AppError.generic("An unexpected error occurred."));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  // --- End Edit Mode Handlers ---

  // --- Helper Methods ---
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
                  overflow: TextOverflow.ellipsis)),
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
    final apiError = ref.watch(errorProvider);

    // --- Loading State ---
    if (isLoadingProfile && user.name == null && !_isEditing) {
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

    // --- Error State ---
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
            padding: const EdgeInsets.all(20.0), // Added padding argument
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

    // --- Prepare Content Blocks (Logic from HomeProfileCard) ---
    final List<dynamic> contentBlocks = [];
    final currentMedia = user.mediaUrls ?? [];
    final prompts = user.prompts;

    contentBlocks.add("header_section");

    if (currentMedia.isNotEmpty) {
      contentBlocks
          .add({"type": "media", "value": currentMedia[0], "index": 0});
    } else {
      contentBlocks.add("empty_media_section");
    }

    if (prompts.isNotEmpty) {
      contentBlocks.add(prompts[0]);
    } else {
      contentBlocks.add("empty_prompt_section");
    }

    contentBlocks.add("vitals_section");

    int mediaIndex = 1;
    int promptIndex = 1;
    int maxRemaining = max(currentMedia.length, prompts.length);

    for (int i = 1; i < maxRemaining; i++) {
      if (mediaIndex < currentMedia.length) {
        contentBlocks.add({
          "type": "media",
          "value": currentMedia[mediaIndex],
          "index": mediaIndex
        });
        mediaIndex++;
      }
      if (promptIndex < prompts.length) {
        contentBlocks.add(prompts[promptIndex]);
        promptIndex++;
      }
    }

    if (user.audioPrompt != null) {
      contentBlocks.add(user.audioPrompt!);
    } else {
      contentBlocks.add("empty_audio_section");
    }
    // --- End Content Block Preparation ---

    // --- Build UI ---
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: const Color(0xFF8B5CF6),
        onRefresh: () async {
          if (!_isEditing) {
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
                      if (_isSaving)
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
                                style:
                                    GoogleFonts.poppins(color: Colors.grey))),
                        TextButton(
                            onPressed: _handleSave,
                            child: Text("Save",
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF8B5CF6),
                                    fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                      ],
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
                    // Handle Empty Sections
                    else if (item is String && item == "empty_media_section") {
                      contentWidget = _buildEmptySection(
                          "Photos & Videos",
                          "Add photos and videos!",
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
                          "Add prompt answers!",
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
                          "Record a voice prompt!",
                          Icons.mic_none_rounded,
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const VoicePromptScreen(
                                      isEditing: true))));
                    }
                    // Handle Content Items
                    else if (item is Map && item["type"] == "media") {
                      String displayValue = item["value"];
                      bool isLocalFile =
                          Uri.tryParse(displayValue)?.isAbsolute == false ||
                              displayValue.startsWith('/');
                      File? tempFile = isLocalFile ? File(displayValue) : null;
                      // Check existence async (might cause flicker, but safer)
                      // A better approach might be to store type info in the list
                      Future<bool> checkFileExists() async {
                        if (tempFile == null) return false;
                        try {
                          return await tempFile.exists();
                        } catch (e) {
                          return false;
                        }
                      }

                      contentWidget = FutureBuilder<bool>(
                          future: checkFileExists(),
                          builder: (context, snapshot) {
                            // While checking, show placeholder or previous state?
                            bool fileDefinitelyExists = snapshot.data == true;
                            return _buildMediaItem(
                                context, ref, displayValue, item["index"],
                                isLocalFile: fileDefinitelyExists);
                          });
                    } else if (item is Prompt) {
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
    );
  }

// --- Block Builder Widgets (Adapted for ProfileScreen) ---

  Widget _buildHeaderBlock(UserModel user) {
    // (Same as before, uses _buildEditableChip and _buildAddChip correctly)
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
            // Non-editable Hometown
            if (user.hometown != null && user.hometown!.isNotEmpty)
              _buildDetailChip(Icons.location_on_outlined, user.hometown!,
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
    // Edit button logic integrated here
    final bool canEdit =
        _isEditing; // Allow editing/reordering from the main picker
    bool isVideo = false;
    if (!isLocalFile) {
      isVideo = urlOrPath.toLowerCase().contains('.mp4') ||
          urlOrPath.toLowerCase().contains('.mov');
    } else {
      // Basic check for local video files (might need refinement)
      String ext = urlOrPath.split('.').last.toLowerCase();
      isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
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
                        const Icon(Icons.broken_image)) // Display local file
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
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),

              // Edit Button (Top Right, conditionally shown ONLY FOR THE FIRST IMAGE)
              // The MediaPickerScreen handles reordering/deleting others
              if (_isEditing && index == 0) // Show only for the first image
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildSmallEditButton(
                      icon: Icons.edit, // Use edit icon for consistency
                      tooltip:
                          "Edit Media Gallery", // Tooltip reflects gallery edit
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const MediaPickerScreen(isEditing: true)))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptItem(Prompt prompt, {required VoidCallback onEditTap}) {
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
              top: -12, // Adjust for better positioning
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
    final bool isThisPlaying =
        _currentAudioUrl == audio.audioUrl && _isPlaying; // Use local state
    final bool isThisPaused = _currentAudioUrl == audio.audioUrl &&
        !_isPlaying &&
        _audioPlayer.state == PlayerState.paused; // Use local state

    return Container(
      // Removed outer Column
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
        // Use Stack for the edit button
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              InkWell(
                // Play/Pause Button
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
                // Prompt Text
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
          // Edit Button (Top Right)
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
    final List<Widget> vitals = [];
    // --- Use _buildEditableChip and _buildAddChip ---
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
    // Display Hometown (Not Editable)
    if (user.hometown != null && user.hometown!.isNotEmpty)
      vitals
          .add(_buildDetailChip(Icons.location_city_outlined, user.hometown!));
    // Display Job Title (Not Editable)
    if (user.jobTitle != null && user.jobTitle!.isNotEmpty)
      vitals.add(_buildDetailChip(Icons.work_outline_rounded, user.jobTitle!));
    // Display Education (Not Editable)
    if (user.education != null && user.education!.isNotEmpty)
      vitals.add(_buildDetailChip(Icons.school_outlined, user.education!));
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
      // Add chips for non-editable fields if empty during edit
      if (user.hometown == null || user.hometown!.isEmpty)
        vitals.add(_buildAddChip(
            label: "Add Hometown",
            onAddTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const HometownScreen(isEditing: true)))));
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
      // Add chips for editable habits if empty during edit
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
      return const SizedBox.shrink();
    }
    if (vitals.isEmpty && _isEditing) {
      return _buildEmptySection("Vitals & Habits", "Add more details!",
          Icons.list_alt_rounded, onEditTap);
    }

    // Changed to a Column layout for better wrapping control
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

  // --- Editable Chip Widget ---
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

  // --- Add Chip Widget ---
  Widget _buildAddChip({
    required String label,
    required VoidCallback onAddTap,
    bool subtle = false,
  }) {
    return InkWell(
      onTap: onAddTap, // Should always be active in edit mode
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

  // Helper to navigate to the start of the vitals editing flow
  void _navigateToVitalsEditFlow() {
    // Example: Navigate to edit Height, then others can be accessed from Profile screen
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                const HeightSelectionScreen(isEditing: true)));
  }
} // End of _ProfileScreenState
