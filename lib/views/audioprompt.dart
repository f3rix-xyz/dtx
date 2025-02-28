// views/audioprompt.dart
import 'package:dtx/providers/audio_upload_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/audiopromptsselect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../providers/user_provider.dart';
import '../views/home.dart';

class VoicePromptScreen extends ConsumerStatefulWidget {
  const VoicePromptScreen({Key? key}) : super(key: key);

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
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initializeAudioSession();
    // Add listener for playback completion
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  Future<void> _initializeAudioSession() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw 'Microphone permission not granted';
    }
  }

  Future<void> _startRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _audioPath =
          '${directory.path}/voice_prompt_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _audioPath!,
      );

      _startTime = DateTime.now();
      setState(() => _isRecording = true);

      // Update timer every second
      Stream.periodic(const Duration(seconds: 1)).listen((_) {
        if (!_isRecording || !mounted) return;

        final duration = DateTime.now().difference(_startTime!).inSeconds;
        if (duration >= 30) {
          _stopRecording();
          return;
        }

        setState(() {
          _recordingTime = "0:${duration.toString().padLeft(2, '0')} / 0:30";
        });
      });
    } catch (e) {
      print('Recording error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() => _isRecording = false);
      
      // Save the file path to the provider instead of creating the file immediately
      if (_audioPath != null) {
        // Just save the path - don't create the media model yet
        ref.read(audioUploadProvider.notifier).setRecordingPath(_audioPath!);
      }
    } catch (e) {
      print('Stop recording error: $e');
    }
  }

  Future<void> _playRecording() async {
    if (_audioPath == null || !File(_audioPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recording available')),
      );
      return;
    }

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      print('Playback error: $e');
      setState(() => _isPlaying = false);
    }
  }

  void _selectPrompt() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AudioSelectPromptScreen()),
    ).then((_) {
      // Refresh UI after selecting a prompt
      setState(() {});
    });
  }

  // Upload audio and save profile
// Upload audio and save profile
Future<void> _uploadAudioAndSaveProfile() async {
  print('[VoicePrompt] Starting _uploadAudioAndSaveProfile');
  
  if (_isRecording) {
    print('[VoicePrompt] Currently recording, stopping...');
    await _stopRecording();
    print('[VoicePrompt] Recording stopped');
    
    // Give a small delay to ensure recording is fully stopped
    print('[VoicePrompt] Waiting 200ms for recording cleanup');
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // Verify we have a recording
  if (_audioPath == null) {
    print('[VoicePrompt] ERROR: _audioPath is null');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please record your voice first')),
    );
    return;
  }
  
  final audioFile = File(_audioPath!);
  if (!audioFile.existsSync()) {
    print('[VoicePrompt] ERROR: Audio file does not exist at path: $_audioPath');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recording file not found')),
    );
    return;
  } else {
    final fileSize = audioFile.lengthSync();
    print('[VoicePrompt] Audio file exists, size: ${fileSize / 1024} KB');
  }

  // Verify prompt is selected
  final selectedPrompt = ref.read(audioUploadProvider.notifier).selectedPrompt;
  print('[VoicePrompt] Selected prompt: ${selectedPrompt?.value}');
  
  if (selectedPrompt == null) {
    print('[VoicePrompt] ERROR: No prompt selected');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a prompt category')),
    );
    return;
  }

  // Show loading state
  print('[VoicePrompt] Setting loading states to true');
  setState(() {
    _isUploading = true;
    _isSaving = true;
  });

  try {
    // Upload the audio file
    print('[VoicePrompt] Starting audio upload');
    final audioUploadNotifier = ref.read(audioUploadProvider.notifier);
    final audioUploaded = await audioUploadNotifier.uploadAudioAndSaveToProfile();
    print('[VoicePrompt] Audio upload result: $audioUploaded');
    
    if (!mounted) {
      print('[VoicePrompt] Widget not mounted after upload, returning');
      return;
    }
    
    if (audioUploaded) {
      // Now save the complete profile
      print('[VoicePrompt] Audio uploaded successfully, saving profile');
      final userNotifier = ref.read(userProvider.notifier);
      final profileSaved = await userNotifier.saveProfile();
      print('[VoicePrompt] Profile save result: $profileSaved');
      
      if (profileSaved) {
        // Navigate to home screen
        if (mounted) {
          print('[VoicePrompt] Profile saved successfully, navigating to HomeScreen');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false, // Clear all previous routes
          );
        } else {
          print('[VoicePrompt] Widget not mounted after profile save');
        }
      } else {
        if (mounted) {
          print('[VoicePrompt] ERROR: Failed to save profile');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save profile. Please try again.')),
          );
        }
      }
    } else {
      if (mounted) {
        print('[VoicePrompt] ERROR: Failed to upload audio');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload audio. Please try again.')),
        );
      }
    }
  } catch (e, stack) {
    print('[VoicePrompt] EXCEPTION during upload/save: $e');
    print('[VoicePrompt] Stack trace: $stack');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  } finally {
    print('[VoicePrompt] Resetting loading states');
    if (mounted) {
      setState(() {
        _isUploading = false;
        _isSaving = false;
      });
    } else {
      print('[VoicePrompt] Widget not mounted in finally block');
    }
  }
}
  @override
  Widget build(BuildContext context) {
    final selectedPrompt = ref.watch(audioUploadProvider.notifier).selectedPrompt;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Progress dots with mic icon
              Row(
                children: [
                  Container(
                    height: 8,
                    width: 8,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0xFF8b5cf6), width: 2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Color(0xFF8b5cf6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Title
              const Text(
                'Add a Voice Prompt to\nyour profile',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 32),

              // Prompt Selection Button
              GestureDetector(
                onTap: _selectPrompt,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Text(
                            selectedPrompt?.label ?? 'Select a prompt',
                            style: TextStyle(
                              color: selectedPrompt != null ? Colors.black : Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Recording Container
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      _isRecording ? _stopRecording() : _startRecording(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _recordingTime,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isRecording
                              ? 'Recording...'
                              : 'Tap to start recording',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? Colors.red
                                : const Color(0xFF8b5cf6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Play Sample Button
              if (_audioPath != null)
                Center(
                  child: TextButton.icon(
                    onPressed: _playRecording,
                    icon: Icon(
                      _isPlaying ? Icons.stop : Icons.play_arrow,
                      color: const Color(0xFF8b5cf6),
                    ),
                    label: Text(
                      _isPlaying ? 'Stop playing' : 'Play recording',
                      style: const TextStyle(
                        color: Color(0xFF8b5cf6),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Next Button
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: _isSaving || _isUploading
                      ? const CircularProgressIndicator(
                          color: Color(0xFF8b5cf6),
                        )
                      : FloatingActionButton(
                          onPressed: _uploadAudioAndSaveProfile,
                          backgroundColor: const Color(0xFF8b5cf6),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                          ),
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
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
