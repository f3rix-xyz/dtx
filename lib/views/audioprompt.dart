import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../providers/user_provider.dart';
import '../views/home.dart'; // Import the home screen

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
        if (!_isRecording) return;

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

  // Save profile and navigate
  Future<void> _saveProfileAndNavigate() async {
    if (_isRecording) {
      await _stopRecording();
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Save the profile data via the user provider
      final success = await ref.read(userProvider.notifier).saveProfile();
      
      if (success) {
        // Navigate to the home screen on success
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false, // Clear all previous routes
        );
      } else {
        // Show error message if saving failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save profile. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

              // Text Input Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'A boundary of mine is',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(
                        Icons.edit_outlined,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
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
              Center(
                child: TextButton.icon(
                  onPressed: _playRecording,
                  icon: Icon(
                    _isPlaying ? Icons.stop : Icons.play_arrow,
                    color: const Color(0xFF8b5cf6),
                  ),
                  label: Text(
                    _isPlaying ? 'Stop playing' : 'Play sample answer',
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
                  child: _isSaving
                      ? const CircularProgressIndicator(
                          color: Color(0xFF8b5cf6),
                        )
                      : FloatingActionButton(
                          onPressed: _saveProfileAndNavigate,
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
}
