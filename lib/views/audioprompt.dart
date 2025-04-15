// File: views/audioprompt.dart
import 'dart:async';
import 'package:dtx/models/error_model.dart';
import 'package:dtx/models/media_upload_model.dart';
import 'package:dtx/providers/audio_upload_provider.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/audiopromptsselect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/auth_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
// Import MainNavigationScreen
import 'package:dtx/views/main_navigation_screen.dart';
// Removed Home import
// Removed FeedType import

class VoicePromptScreen extends ConsumerStatefulWidget {
  const VoicePromptScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VoicePromptScreen> createState() => _VoicePromptScreenState();
}

class _VoicePromptScreenState extends ConsumerState<VoicePromptScreen> {
  // ... (initState, _initializeAudioSession, _startRecording, _stopRecording, _playRecording, _selectPrompt remain the same) ...
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String _recordingTime = "0:00 / 0:30";
  String? _audioPath;
  bool _isPlaying = false;
  DateTime? _startTime;
  Timer? _recordingTimer; // Store timer to cancel it
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeAudioSession();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted && state != PlayerState.playing) {
        if (_isPlaying && state != PlayerState.paused) {
          setState(() => _isPlaying = false);
        }
      }
    });
  }

  Future<void> _initializeAudioSession() async {
    print("[VoicePromptScreen] Requesting microphone permission...");
    final status = await Permission.microphone.request();
    print("[VoicePromptScreen] Microphone permission status: $status");
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (!await _audioRecorder.hasPermission()) {
      print("[VoicePromptScreen] Start Recording: Permission denied.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
      }
      return;
    }
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    }
    setState(() {
      _audioPath = null;
      _recordingTime = "0:00 / 0:30";
    });
    ref.read(audioUploadProvider.notifier).clearAudio();

    try {
      print("[VoicePromptScreen] Starting recording...");
      final directory = await getApplicationDocumentsDirectory();
      final newPath =
          '${directory.path}/voice_prompt_${DateTime.now().millisecondsSinceEpoch}.m4a';
      print("[VoicePromptScreen] Recording path set to: $newPath");

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: newPath,
      );

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
          _stopRecording(); // Auto-stop
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
          SnackBar(content: Text('Recording failed: ${e.toString()}')),
        );
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Failed to save recording. Please try again.')),
            );
            setState(() {
              _isRecording = false;
              _audioPath = null;
              _recordingTime = "0:00 / 0:30";
            });
          }
          return;
        }
        _audioPath = path;
        if (mounted) {
          setState(() {
            _isRecording = false;
          });
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
    print("[VoicePromptScreen] Play recording requested. Path: $_audioPath");
    if (_audioPath == null) {
      print("[VoicePromptScreen] Playback Error: Audio path is null.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please record your voice first.')),
        );
      }
      return;
    }
    final file = File(_audioPath!);
    if (!await file.exists()) {
      print(
          "[VoicePromptScreen] Playback Error: File does not exist at $_audioPath");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Recording file not found. Please record again.')),
        );
      }
      setState(() => _audioPath = null);
      return;
    }
    if (await file.length() == 0) {
      print("[VoicePromptScreen] Playback Error: File is empty at $_audioPath");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Recording file is empty. Please record again.')),
        );
      }
      setState(() => _audioPath = null);
      return;
    }

    try {
      if (_isPlaying) {
        print("[VoicePromptScreen] Pausing playback.");
        await _audioPlayer.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        if (_audioPlayer.state == PlayerState.playing) {
          await _audioPlayer.stop();
        }
        print("[VoicePromptScreen] Starting playback from: $_audioPath");
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
        if (mounted) setState(() => _isPlaying = true);
      }
    } catch (e) {
      print('[VoicePromptScreen] Playback error: $e');
      if (mounted) {
        setState(() => _isPlaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback failed: ${e.toString()}')),
        );
      }
    }
  }

  void _selectPrompt() {
    if (_isPlaying) {
      _audioPlayer.pause();
      if (mounted) setState(() => _isPlaying = false);
    }
    print("[VoicePromptScreen] Navigating to select audio prompt.");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AudioSelectPromptScreen()),
    ).then((_) {
      if (mounted) {
        print(
            "[VoicePromptScreen] Returned from prompt selection. Refreshing UI.");
        setState(() {});
      }
    });
  }

  Future<void> _saveProfileAndNavigate() async {
    print('[VoicePromptScreen] Starting _saveProfileAndNavigate');
    final errorNotifier = ref.read(errorProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);
    final userNotifier = ref.read(userProvider.notifier);
    errorNotifier.clearError();

    final selectedPrompt =
        ref.read(audioUploadProvider.notifier).selectedPrompt;
    if (selectedPrompt == null) {
      print('[VoicePromptScreen] Validation Error: No audio prompt selected.');
      errorNotifier
          .setError(AppError.validation("Please select an audio prompt."));
      return;
    }

    bool audioNeedsUpload =
        _audioPath != null && File(_audioPath!).existsSync();
    bool audioPrepared = false;
    MediaUploadModel? audioUploadModel;

    if (audioNeedsUpload) {
      ref.read(audioUploadProvider.notifier).setRecordingPath(_audioPath!);
      audioPrepared = ref.read(audioUploadProvider.notifier).prepareAudioFile();
      if (!audioPrepared) {
        print('[VoicePromptScreen] Audio file preparation/validation failed.');
        return;
      }
      audioUploadModel = ref.read(audioUploadProvider);
      if (audioUploadModel == null) {
        print('[VoicePromptScreen] Error: Audio prepared but model is null.');
        errorNotifier
            .setError(AppError.generic("Error preparing audio model."));
        return;
      }
    } else {
      print('[VoicePromptScreen] No audio recording found or needed.');
      userNotifier.updateAudioPrompt(null);
    }

    setState(() => _isSaving = true);

    try {
      bool audioUploadedSuccessfully = true;
      if (audioNeedsUpload && audioPrepared && audioUploadModel != null) {
        print('[VoicePromptScreen] Audio model exists, attempting upload...');
        audioUploadedSuccessfully = await ref
            .read(audioUploadProvider.notifier)
            .uploadAudioAndSaveToProfile();
        if (!audioUploadedSuccessfully) {
          print('[VoicePromptScreen] Audio upload failed.');
          setState(() => _isSaving = false);
          return;
        }
        print('[VoicePromptScreen] Audio upload successful.');
      } else if (audioNeedsUpload && !audioPrepared) {
        print(
            '[VoicePromptScreen] Error: Audio needed upload but was not prepared.');
        errorNotifier.setError(
            AppError.generic("Error preparing audio. Please re-record."));
        setState(() => _isSaving = false);
        return;
      } else {
        print('[VoicePromptScreen] No audio to upload.');
      }

      final userModel = ref.read(userProvider);
      final profileData = userModel.toJsonForProfileUpdate();
      print('[VoicePromptScreen] Profile data prepared for API: $profileData');

      final userRepository = ref.read(userRepositoryProvider);
      print(
          '[VoicePromptScreen] Calling userRepository.updateProfileDetails...');
      final profileSaved =
          await userRepository.updateProfileDetails(profileData);

      if (profileSaved) {
        print('[VoicePromptScreen] Profile details saved successfully.');
        final finalStatus =
            await authNotifier.checkAuthStatus(updateState: true);
        if (mounted) {
          print(
              '[VoicePromptScreen] Navigating to MainNavigationScreen. Status: $finalStatus');
          // FIXED NAVIGATION: Navigate to MainNavigationScreen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
            (route) => false,
          );
        }
      } else {
        print(
            '[VoicePromptScreen] Profile details save failed (API returned false).');
        if (mounted && ref.read(errorProvider) == null) {
          errorNotifier.setError(
              AppError.server("Failed to save profile. Please try again."));
        }
      }
    } on ApiException catch (e) {
      print('[VoicePromptScreen] API Exception: ${e.message}');
      if (mounted) errorNotifier.setError(AppError.server(e.message));
    } catch (e) {
      print('[VoicePromptScreen] Unexpected Error: $e');
      if (mounted) {
        errorNotifier.setError(AppError.generic(
            "An unexpected error occurred. Please try again."));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ... (build method remains the same) ...
  @override
  Widget build(BuildContext context) {
    final selectedPrompt =
        ref.watch(audioUploadProvider.notifier).selectedPrompt;
    final errorState = ref.watch(errorProvider);
    final existingAudioPrompt = ref.watch(userProvider).audioPrompt;
    final bool canSave = selectedPrompt != null &&
        (_audioPath != null || existingAudioPrompt != null);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
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
              const SizedBox(height: 40),
              Text(
                'Add a Voice Prompt\nto your profile',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Let potential matches hear your voice!",
                style:
                    GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _selectPrompt,
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
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedPrompt?.label ?? 'Select a prompt *',
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
                        child: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Colors.grey[800],
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GestureDetector(
                  onTap: _isRecording ? null : _startRecording,
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
                            color: Colors.grey[500],
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isRecording
                              ? 'Recording...'
                              : (_audioPath == null
                                  ? 'Tap microphone to start (Max 30s)'
                                  : 'Tap microphone to re-record'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap:
                              _isRecording ? _stopRecording : _startRecording,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? Colors.redAccent
                                  : const Color(0xFF8b5cf6),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isRecording
                                          ? Colors.redAccent
                                          : const Color(0xFF8b5cf6))
                                      .withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isRecording
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_audioPath != null &&
                            File(_audioPath!).existsSync())
                          TextButton.icon(
                            onPressed: _playRecording,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF8b5cf6),
                            ),
                            icon: Icon(_isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                            label: Text(
                              _isPlaying ? 'Pause' : 'Play recording',
                              style: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          )
                        else
                          const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
              if (errorState != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                  child: Text(
                    errorState.message,
                    style: GoogleFonts.poppins(
                        color: Colors.redAccent, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
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
