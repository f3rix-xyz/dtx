// File: lib/views/audioprompt.dart
import 'dart:async';
import 'dart:io';
import 'dart:math'; // Import math

import 'package:audioplayers/audioplayers.dart';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/media_upload_model.dart';
import 'package:dtx/models/auth_model.dart';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/providers/audio_upload_provider.dart';
import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/media_upload_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/audiopromptsselect.dart';
import 'package:dtx/views/main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:dtx/repositories/user_repository.dart';

class VoicePromptScreen extends ConsumerStatefulWidget {
  final bool isEditing;

  const VoicePromptScreen({
    Key? key,
    this.isEditing = false,
  }) : super(key: key);

  @override
  ConsumerState<VoicePromptScreen> createState() => _VoicePromptScreenState();
}

class _VoicePromptScreenState extends ConsumerState<VoicePromptScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String _recordingTime = "0:00 / 0:30";
  String? _audioPath;
  bool _isPlaying = false;
  DateTime? _startTime;
  Timer? _recordingTimer;
  bool _isSaving = false;
  // Selected prompt is now managed solely within AudioUploadNotifier
  String? _existingAudioUrl;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final existingPromptModel = ref.read(userProvider).audioPrompt;
      if (existingPromptModel != null) {
        // Initialize the provider's internal selected prompt
        ref
            .read(audioUploadProvider.notifier)
            .setSelectedPrompt(existingPromptModel.prompt);
        _existingAudioUrl = existingPromptModel.audioUrl;
        print(
            "[VoicePromptScreen initState] Editing mode. Initial prompt set in provider: ${existingPromptModel.prompt.value}, Existing URL: $_existingAudioUrl");
      } else {
        // --- FIX: Pass null correctly ---
        ref.read(audioUploadProvider.notifier).setSelectedPrompt(null);
        _existingAudioUrl = null;
        print(
            "[VoicePromptScreen initState] Editing mode. No existing prompt found. Provider prompt set to null.");
        // --- END FIX ---
      }
    } else {
      // Onboarding: Clear audio provider state
      ref.read(audioUploadProvider.notifier).clearAudio();
      print(
          "[VoicePromptScreen initState] Onboarding mode. Cleared audio provider.");
      _existingAudioUrl = null;
    }
    _initializeAudioSession();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted && state != PlayerState.playing) {
        if (_isPlaying && state != PlayerState.paused) {
          setState(() => _isPlaying = false);
        }
      }
    });
  }

  // _initializeAudioSession, _startRecording, _stopRecording, _playRecording remain the same
  Future<void> _initializeAudioSession() async {
    print("[VoicePromptScreen] Requesting microphone permission...");
    final status = await Permission.microphone.request();
    print("[VoicePromptScreen] Microphone permission status: $status");
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _existingAudioUrl =
          null; // Clear existing URL when starting new recording
      _audioPath = null;
      _recordingTime = "0:00 / 0:30";
    });
    // Keep clearAudio call here? Yes, it clears the provider's file/path state.
    ref
        .read(audioUploadProvider.notifier)
        .clearAudio(); // Clears provider's file state AND internal selected prompt
    if (!await _audioRecorder.hasPermission()) {
      print("[VoicePromptScreen] Start Recording: Permission denied.");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied.')));
      return;
    }
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    }
    try {
      print("[VoicePromptScreen] Starting recording...");
      final directory = await getApplicationDocumentsDirectory();
      final newPath =
          '${directory.path}/voice_prompt_${DateTime.now().millisecondsSinceEpoch}.m4a';
      print("[VoicePromptScreen] Recording path set to: $newPath");
      await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: newPath);
      _audioPath = newPath;
      _startTime = DateTime.now();
      if (!mounted) return;
      setState(() => _isRecording = true);
      print("[VoicePromptScreen] Recording started.");
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isRecording || !mounted || _startTime == null) {
          timer.cancel();
          return;
        }
        final duration = DateTime.now().difference(_startTime!).inSeconds;
        if (duration >= 30) {
          timer.cancel();
          _stopRecording();
          return;
        }
        if (mounted) {
          setState(() {
            _recordingTime = "0:${duration.toString().padLeft(2, '0')} / 0:30";
          });
        }
      });
    } catch (e) {
      print('[VoicePromptScreen] Recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recording failed: ${e.toString()}')));
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      print('[VoicePromptScreen] Recording stopped. Path from recorder: $path');
      if (path != null) {
        final file = File(path);
        if (!await file.exists() || await file.length() == 0) {
          print(
              '[VoicePromptScreen] Error: Recording file is missing or empty after stop.');
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Failed to save recording. Please try again.')));
          setState(() {
            _isRecording = false;
            _audioPath = null;
            _recordingTime = "0:00 / 0:30";
          });
          return;
        }
        _audioPath = path;
        if (mounted) {
          setState(() {
            _isRecording = false;
          });
          // Set the path in the provider, which is needed for prepareAudioFile
          ref.read(audioUploadProvider.notifier).setRecordingPath(_audioPath!);
          print(
              "[VoicePromptScreen] Recording path saved to provider: $_audioPath");
        }
      } else {
        print("[VoicePromptScreen] Stop recording returned null path.");
        if (mounted) {
          setState(() => _isRecording = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save recording.')),
          );
        }
      }
    } catch (e) {
      print('[VoicePromptScreen] Stop recording error: $e');
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _playRecording() async {
    final String? pathOrUrlToPlay = _audioPath ?? _existingAudioUrl;
    print(
        "[VoicePromptScreen] Play recording requested. Source: $pathOrUrlToPlay");
    if (pathOrUrlToPlay == null) {
      print("[VoicePromptScreen] Playback Error: No audio source available.");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Please record or ensure existing audio is loaded.')));
      return;
    }
    // Check local file existence if _audioPath is set
    if (_audioPath != null) {
      final file = File(_audioPath!);
      if (!await file.exists() || await file.length() == 0) {
        print(
            "[VoicePromptScreen] Playback Error: File is missing or empty at $_audioPath");
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Recording file error. Please record again.')));
        setState(() {
          _audioPath = null; // Clear invalid path
          _recordingTime = "0:00 / 0:30";
        });
        return;
      }
    }
    try {
      // Determine the source based on whether _audioPath or _existingAudioUrl should be used
      final Source audioSource = (_audioPath != null &&
              File(_audioPath!).existsSync())
          ? DeviceFileSource(_audioPath!)
          : UrlSource(
              pathOrUrlToPlay); // Fallback to existing URL if local path invalid/null

      if (_isPlaying) {
        print("[VoicePromptScreen] Pausing playback.");
        await _audioPlayer.pause();
      } else {
        if (_audioPlayer.state == PlayerState.playing ||
            _audioPlayer.state == PlayerState.paused) {
          await _audioPlayer.stop(); // Stop previous before playing new/resume
        }
        print(
            "[VoicePromptScreen] Starting playback from: ${audioSource is UrlSource ? audioSource.url : (audioSource as DeviceFileSource).path}");
        await _audioPlayer.play(audioSource);
      }
      // State update (_isPlaying) is handled by listeners
    } catch (e) {
      print('[VoicePromptScreen] Playback error: $e');
      if (mounted) {
        setState(() => _isPlaying = false); // Reset playing state on error
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playback failed: ${e.toString()}')));
      }
    }
  }

  void _selectPrompt() {
    if (_isPlaying) {
      _audioPlayer.pause();
    }
    print("[VoicePromptScreen] Navigating to select audio prompt.");
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AudioSelectPromptScreen(
                isEditing: widget.isEditing,
              )),
    ).then((_) {
      // Trigger rebuild after returning to update the displayed prompt text
      if (mounted) {
        setState(
            () {}); // Rebuild to reflect the change in the provider's selected prompt
        final selectedPrompt =
            ref.read(audioUploadProvider.notifier).selectedPrompt;
        print(
            "[VoicePromptScreen] Returned from prompt selection. Selected in provider: ${selectedPrompt?.label}");
      }
    });
  }

  // --- SAVE METHOD (No functional changes needed from previous fix) ---
  Future<void> _saveProfileAndNavigate() async {
    print(
        '[VoicePromptScreen] Starting _saveProfileAndNavigate (isEditing: ${widget.isEditing})');
    final errorNotifier = ref.read(errorProvider.notifier);
    final userNotifier = ref.read(userProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);
    final audioUploadNotifier = ref.read(audioUploadProvider.notifier);
    errorNotifier.clearError();

    // Read selected prompt directly from the provider
    final AudioPrompt? selectedPrompt = audioUploadNotifier.selectedPrompt;

    if (selectedPrompt == null) {
      print('[VoicePromptScreen] Validation Error: No audio prompt selected.');
      errorNotifier
          .setError(AppError.validation("Please select an audio prompt."));
      return;
    }

    bool isNewAudioRecording =
        _audioPath != null && File(_audioPath!).existsSync();
    bool audioPrepared = false;
    MediaUploadModel? audioUploadModel;
    String? finalAudioUrl =
        _existingAudioUrl; // Start with existing URL if editing

    // --- Audio Preparation (only if NEW recording exists) ---
    if (isNewAudioRecording) {
      print(
          '[VoicePromptScreen] New audio recording found at $_audioPath. Preparing for upload.');
      audioPrepared = audioUploadNotifier.prepareAudioFile();
      if (!audioPrepared) {
        print('[VoicePromptScreen] Audio file preparation/validation failed.');
        return;
      }
      audioUploadModel =
          ref.read(audioUploadProvider); // Get prepared model state
      if (audioUploadModel == null) {
        print(
            '[VoicePromptScreen] Error: Audio prepared but provider state is null.');
        errorNotifier
            .setError(AppError.generic("Error preparing audio model state."));
        return;
      }
    } else if (_existingAudioUrl == null && !widget.isEditing) {
      print(
          '[VoicePromptScreen] Validation Error: No audio recorded for onboarding.');
      errorNotifier.setError(
          AppError.validation("Please record your voice prompt answer."));
      return;
    } else if (_existingAudioUrl != null) {
      print('[VoicePromptScreen] Using existing audio URL: $_existingAudioUrl');
    }

    setState(() => _isSaving = true);

    try {
      // --- STEP 1: Upload General Media (ONLY during ONBOARDING) ---
      if (!widget.isEditing) {
        print(
            "[VoicePromptScreen Onboarding] Attempting to upload general media...");
        final mediaSuccess =
            await ref.read(mediaUploadProvider.notifier).uploadAllMedia();
        if (!mediaSuccess) {
          print("[VoicePromptScreen Onboarding] General media upload failed.");
          if (ref.read(errorProvider) == null) {
            errorNotifier
                .setError(AppError.server("Failed to upload photos/videos."));
          }
          throw ApiException(
              "Media upload failed during onboarding."); // Stop the process
        }
        print(
            "[VoicePromptScreen Onboarding] General media upload successful.");
      }

      // --- STEP 2: Upload Audio (if new recording exists) ---
      bool audioUploadedSuccessfully = true;
      if (isNewAudioRecording && audioPrepared && audioUploadModel != null) {
        print('[VoicePromptScreen] Attempting audio upload...');
        audioUploadedSuccessfully =
            await audioUploadNotifier.uploadAudioAndSaveToProfile();

        if (!audioUploadedSuccessfully) {
          print('[VoicePromptScreen] Audio upload failed.');
          throw ApiException("Audio upload failed.");
        }
        finalAudioUrl = ref.read(audioUploadProvider)?.presignedUrl;
        print(
            '[VoicePromptScreen] Audio upload successful. New URL: $finalAudioUrl');
      } else if (!isNewAudioRecording && _existingAudioUrl != null) {
        print(
            '[VoicePromptScreen] No new audio upload needed. Updating user model with existing URL.');
        final currentAudioModel = AudioPromptModel(
            prompt: selectedPrompt, audioUrl: _existingAudioUrl!);
        userNotifier.updateAudioPrompt(currentAudioModel);
        finalAudioUrl = _existingAudioUrl;
      } else if (widget.isEditing &&
          !isNewAudioRecording &&
          _existingAudioUrl == null) {
        print(
            '[VoicePromptScreen Editing] No existing or new audio. Setting audio prompt to null.');
        userNotifier.updateAudioPrompt(null);
        finalAudioUrl = null;
      }

      // --- STEP 3: Save Profile (POST for Onboarding, PATCH for Editing) ---
      bool profileSaved = false;
      if (widget.isEditing) {
        print('[VoicePromptScreen Editing] Saving profile changes (PATCH)...');
        final latestUserState = ref.read(userProvider);
        final payload = latestUserState.toJsonForEdit();
        if (finalAudioUrl != null) {
          payload['audio_prompt'] =
              AudioPromptModel(prompt: selectedPrompt, audioUrl: finalAudioUrl)
                  .toJson();
        } else {
          payload['audio_prompt'] = null;
        }
        print("[VoicePromptScreen Editing] PATCH Payload: $payload");
        profileSaved =
            await ref.read(userRepositoryProvider).editProfile(payload);
      } else {
        print(
            '[VoicePromptScreen Onboarding] Saving profile details (POST)...');
        profileSaved = await userNotifier.saveProfile();
      }

      // --- STEP 4: Navigation ---
      if (profileSaved) {
        print('[VoicePromptScreen] Profile save successful.');
        if (widget.isEditing) {
          print("[VoicePromptScreen Editing] Popping back.");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Audio prompt updated!"),
                  backgroundColor: Colors.green),
            );
            Navigator.of(context).pop();
          }
        } else {
          print('[VoicePromptScreen Onboarding] Fetching updated profile...');
          await userNotifier.fetchProfile();
          print('[VoicePromptScreen Onboarding] Profile fetch complete.');
          final finalStatus =
              await authNotifier.checkAuthStatus(updateState: true);
          if (mounted) {
            print(
                '[VoicePromptScreen Onboarding] Navigating to MainNavigationScreen. Status: $finalStatus');
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
              (route) => false,
            );
          }
        }
      } else {
        print('[VoicePromptScreen] Profile save failed.');
        if (mounted && ref.read(errorProvider) == null) {
          errorNotifier
              .setError(AppError.server("Failed to save profile changes."));
        }
      }
    } on ApiException catch (e) {
      print(
          '[VoicePromptScreen] Save Process Failed: API Exception - ${e.message}');
      if (mounted) errorNotifier.setError(AppError.server(e.message));
    } catch (e, stack) {
      print('[VoicePromptScreen] Save Process Failed: Unexpected Error - $e');
      print(stack);
      if (mounted)
        errorNotifier.setError(AppError.generic(
            "An unexpected error occurred. Please try again."));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorState = ref.watch(errorProvider);
    // --- FIX: Read selected prompt directly from the notifier ---
    final AudioPrompt? selectedPrompt =
        ref.watch(audioUploadProvider.notifier).selectedPrompt;
    // --- END FIX ---

    final bool hasSelection = selectedPrompt != null;
    final bool hasAudioSource = _audioPath != null || _existingAudioUrl != null;
    // Allow saving null in edit mode OR if a new recording exists OR if an existing URL is present
    final bool canSave = hasSelection &&
        ((widget.isEditing &&
                _existingAudioUrl == null &&
                _audioPath == null) // Allow saving null
            ||
            hasAudioSource // Allow saving if audio exists
        ) &&
        !_isRecording;

    // --- UI Code ---
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                // Header
                padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.isEditing)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                      )
                    else
                      const SizedBox(width: 48), // Placeholder for alignment
                    Text(
                      widget.isEditing ? "Edit Voice Prompt" : "",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    if (widget.isEditing)
                      TextButton(
                        onPressed: canSave && !_isSaving
                            ? _saveProfileAndNavigate
                            : null,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF8B5CF6)))
                            : Text(
                                "Done",
                                style: GoogleFonts.poppins(
                                  color: canSave && !_isSaving
                                      ? const Color(0xFF8B5CF6)
                                      : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      )
                    else
                      const SizedBox(width: 48), // Placeholder for alignment
                  ],
                ),
              ),
              if (!widget.isEditing) ...[
                // Onboarding Dots
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      3,
                      (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 10,
                            width: 10,
                            decoration: BoxDecoration(
                              color: index < 2
                                  ? Colors.grey[300]
                                  : const Color(0xFF8b5cf6),
                              shape: BoxShape.circle,
                            ),
                          )),
                ),
                const SizedBox(height: 20),
              ],
              // Title
              Text(
                widget.isEditing
                    ? 'Edit your Voice Prompt'
                    : 'Add a Voice Prompt\nto your profile',
                style: GoogleFonts.poppins(
                  fontSize: widget.isEditing ? 28 : 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle
              Text(
                widget.isEditing
                    ? "Select a prompt and record your answer."
                    : "Let potential matches hear your voice!",
                style:
                    GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              // Prompt Selection Row
              GestureDetector(
                onTap: _isSaving
                    ? null
                    : _selectPrompt, // Disable tap while saving
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedPrompt?.label ??
                              'Select a prompt *', // Read from variable
                          style: GoogleFonts.poppins(
                            color: selectedPrompt != null
                                ? Colors.black87
                                : Colors.grey[600],
                            fontSize: 16,
                            fontWeight: selectedPrompt != null
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.arrow_drop_down_rounded,
                            color: Colors.grey[800], size: 28),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Recording Area
              Expanded(
                child: GestureDetector(
                  onTap: _isRecording || _isSaving
                      ? null
                      : _startRecording, // Disable tap if recording/saving
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _recordingTime,
                          style: GoogleFonts.poppins(
                              color: Colors.grey[500], fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isRecording
                              ? 'Recording...'
                              : (_audioPath == null && _existingAudioUrl == null
                                  ? 'Tap microphone to start (Max 30s)'
                                  : 'Tap microphone to re-record'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: Colors.grey[600], fontSize: 16),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _isSaving
                              ? null
                              : (_isRecording
                                  ? _stopRecording
                                  : _startRecording), // Disable tap if saving
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? Colors.redAccent
                                  : (_isSaving
                                      ? Colors.grey
                                      : const Color(
                                          0xFF8b5cf6)), // Grey out if saving
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: (_isRecording
                                            ? Colors.redAccent
                                            : const Color(0xFF8b5cf6))
                                        .withOpacity(_isSaving
                                            ? 0.1
                                            : 0.3), // Reduce shadow if saving
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Icon(
                                _isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                color: Colors.white,
                                size: 36),
                          ),
                        ),
                        const Spacer(),
                        if (hasAudioSource) // Show button if audio source exists
                          TextButton.icon(
                            onPressed: _isSaving || _isRecording
                                ? null
                                : _playRecording, // Disable if saving/recording
                            style: TextButton.styleFrom(
                                foregroundColor: _isSaving || _isRecording
                                    ? Colors.grey
                                    : const Color(
                                        0xFF8b5cf6)), // Grey out if disabled
                            icon: Icon(_isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                            label: Text(
                              _isPlaying
                                  ? 'Pause'
                                  : 'Play ${_audioPath != null ? "recording" : "existing"}',
                              style: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          )
                        else
                          const SizedBox(height: 48), // Keep placeholder space
                      ],
                    ),
                  ),
                ),
              ),
              // Error Display
              if (errorState != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                  child: Center(
                    child: Text(
                      errorState.message,
                      style: GoogleFonts.poppins(
                          color: Colors.redAccent, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Onboarding FAB
              if (!widget.isEditing)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: _isSaving
                        ? const CircularProgressIndicator(
                            color: Color(0xFF8b5cf6))
                        : FloatingActionButton(
                            heroTag: 'audio_save_fab',
                            onPressed: canSave ? _saveProfileAndNavigate : null,
                            backgroundColor: canSave
                                ? const Color(0xFF8b5cf6)
                                : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            child: const Icon(Icons.check_rounded),
                          ),
                  ),
                ),
              if (widget.isEditing) const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    print("[VoicePromptScreen] Disposing screen...");
    _recordingTimer?.cancel();
    try {
      _audioRecorder.dispose();
    } catch (e) {
      print("Error disposing recorder: $e");
    }
    try {
      if (_audioPlayer.state == PlayerState.playing ||
          _audioPlayer.state == PlayerState.paused) {
        _audioPlayer.stop();
      }
      _audioPlayer.dispose();
    } catch (e) {
      print("Error disposing player: $e");
    }
    super.dispose();
  }
}
