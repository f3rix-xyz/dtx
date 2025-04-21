// providers/audio_upload_provider.dart
import 'dart:io';
import 'dart:math';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import '../models/error_model.dart';
import '../models/media_upload_model.dart';
import '../models/user_model.dart';
import '../repositories/media_repository.dart';
import '../utils/app_enums.dart';
import 'error_provider.dart';
import 'service_provider.dart';
import 'user_provider.dart';

// Provider definition remains the same
final audioUploadProvider =
    StateNotifierProvider<AudioUploadNotifier, MediaUploadModel?>(
  (ref) {
    print('[AudioUpload] Initializing AudioUploadProvider');
    final mediaRepository = ref.watch(mediaRepositoryProvider);
    return AudioUploadNotifier(ref, mediaRepository);
  },
);

class AudioUploadNotifier extends StateNotifier<MediaUploadModel?> {
  final Ref ref;
  final MediaRepository _mediaRepository;
  AudioPrompt? _selectedPrompt; // Internal state to hold the selected prompt
  String? _recordingPath;

  // Initialize with null (no audio uploaded yet)
  AudioUploadNotifier(this.ref, this._mediaRepository) : super(null) {
    print('[AudioUpload] AudioUploadNotifier created');
  }

  // Max audio size (10 MB)
  static const int _maxAudioSizeBytes = 10 * 1024 * 1024;

  // Supported audio MIME types
  static final Set<String> _supportedAudioTypes = {
    'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/webm',
    'audio/aac', 'audio/x-m4a', 'audio/x-aiff', 'audio/flac',
    'audio/mp4' // Add this line to support M4A files
  };

  // Save the recording path for later use
  void setRecordingPath(String path) {
    print('[AudioUpload] Setting recording path: $path');
    _recordingPath = path;
    // Don't clear the selected prompt when setting path
  }

  // Prepare audio file with validation
  bool prepareAudioFile() {
    print('[AudioUpload] Preparing audio file');
    print('[AudioUpload] Recording path: $_recordingPath');
    // --- FIX: Read internal _selectedPrompt ---
    print('[AudioUpload] Selected prompt: ${_selectedPrompt?.value}');

    if (_recordingPath == null || _selectedPrompt == null) {
      // --- END FIX ---
      print('[AudioUpload] ERROR: Missing recording path or prompt');
      // Optionally set an error if needed
      // ref.read(errorProvider.notifier).setError(AppError.validation("Please select a prompt and record audio."));
      return false;
    }

    final file = File(_recordingPath!);
    if (!file.existsSync()) {
      print(
          '[AudioUpload] ERROR: File does not exist at path: $_recordingPath');
      return false;
    }

    try {
      // Validate file size
      final fileSize = file.lengthSync();
      print('[AudioUpload] File size: ${fileSize / 1024} KB');

      if (fileSize > _maxAudioSizeBytes) {
        print(
            '[AudioUpload] ERROR: File too large: ${fileSize / 1024 / 1024} MB (max: ${_maxAudioSizeBytes / 1024 / 1024} MB)');
        ref.read(errorProvider.notifier).setError(
              AppError.validation("Audio is too large. Maximum size is 10 MB."),
            );
        return false;
      }

      // Detect MIME type
      final fileName = path.basename(file.path);
      final mimeType =
          lookupMimeType(file.path) ?? 'audio/mpeg'; // Keep default
      print('[AudioUpload] Filename: $fileName');
      print('[AudioUpload] MIME type: $mimeType');

      // Validate audio type
      if (!_supportedAudioTypes.contains(mimeType)) {
        print('[AudioUpload] ERROR: Unsupported audio format: $mimeType');
        ref.read(errorProvider.notifier).setError(
              AppError.validation(
                  "Unsupported audio format. Please use MP3, WAV, OGG, M4A, or other common audio formats."), // Updated message
            );
        return false;
      }

      // Update state (the MediaUploadModel itself)
      print('[AudioUpload] Creating MediaUploadModel state');
      state = MediaUploadModel(
        file: file,
        fileName: fileName,
        fileType: mimeType,
        status: UploadStatus.idle,
      );

      print('[AudioUpload] Audio file prepared successfully (state updated)');
      return true;
    } catch (e, stack) {
      print('[AudioUpload] ERROR preparing audio file: $e');
      print('[AudioUpload] Stack trace: $stack');
      ref
          .read(errorProvider.notifier)
          .setError(AppError.generic("Error preparing audio file."));
      return false;
    }
  }

  // Clear audio state (MediaUploadModel) AND internal variables
  void clearAudio() {
    print('[AudioUpload] Clearing audio state and internal variables');
    state = null;
    _recordingPath = null;
    _selectedPrompt = null; // Also clear the internal selected prompt
  }

  // Upload audio and save to user profile
  Future<bool> uploadAudioAndSaveToProfile() async {
    print('[AudioUpload] Starting uploadAudioAndSaveToProfile');

    // --- FIX: Check internal _selectedPrompt ---
    if (state == null || _selectedPrompt == null) {
      // --- END FIX ---
      print(
          '[AudioUpload] State or prompt is null, attempting to prepare file');
      final prepared = prepareAudioFile();
      if (!prepared) {
        print('[AudioUpload] Failed to prepare audio file');
        // Error should be set within prepareAudioFile
        return false;
      }
      // Re-check state after preparation
      if (state == null) {
        print(
            '[AudioUpload] Error: State is still null after successful preparation.');
        ref.read(errorProvider.notifier).setError(
            AppError.generic("Internal error preparing audio state."));
        return false;
      }
    }

    // --- FIX: Ensure _selectedPrompt is not null again ---
    if (_selectedPrompt == null) {
      print('[AudioUpload] Error: Selected prompt became null unexpectedly.');
      ref.read(errorProvider.notifier).setError(AppError.validation(
          "Audio prompt selection was lost. Please re-select."));
      return false;
    }
    // --- END FIX ---

    try {
      print('[AudioUpload] Clearing any previous errors');
      ref.read(errorProvider.notifier).clearError();

      // Update state to show upload in progress
      print('[AudioUpload] Setting state to UPLOADING');
      // Use the state that was confirmed/set after prepareAudioFile
      state = state!.copyWith(status: UploadStatus.inProgress);

      // Get presigned URL for audio
      print('[AudioUpload] Getting presigned URL for ${state!.fileName}');
      final presignedUrlResponse = await _mediaRepository.getAudioPresignedUrl(
        state!.fileName,
        state!.fileType,
        _selectedPrompt!, // Use the validated internal prompt
      );

      print(
          '[AudioUpload] Received presigned URL response: ${presignedUrlResponse.toString().substring(0, min(100, presignedUrlResponse.toString().length))}...'); // Safely print start

      // Update state with presigned URL
      print('[AudioUpload] Updating state with presigned URL');
      state = state!.copyWith(
        presignedUrl: () => presignedUrlResponse['url'],
      );

      // Upload audio to S3
      print('[AudioUpload] Uploading file to S3');
      bool success = await _mediaRepository.uploadFileToS3(state!);
      print('[AudioUpload] Initial upload result: $success');

      // If failed, retry
      if (!success) {
        print('[AudioUpload] Initial upload failed, retrying...');
        success = await _mediaRepository.retryUpload(state!);
        print('[AudioUpload] Retry upload result: $success');
      }

      // Update state with result
      print(
          '[AudioUpload] Setting final upload status: ${success ? "SUCCESS" : "FAILED"}');
      state = state!.copyWith(
        status: success ? UploadStatus.success : UploadStatus.failed,
        errorMessage: success ? () => null : () => 'Failed to upload audio',
      );

      if (success) {
        // Create AudioPromptModel
        print(
            '[AudioUpload] Creating AudioPromptModel with prompt: ${_selectedPrompt!.value}');
        final audioPromptModel = AudioPromptModel(
          prompt: _selectedPrompt!, // Use the internal prompt
          audioUrl: presignedUrlResponse['url'],
        );

        // Add to user model
        print('[AudioUpload] Updating user model with audio prompt');
        ref.read(userProvider.notifier).updateAudioPrompt(audioPromptModel);
        print('[AudioUpload] User model updated successfully');
      } else {
        // If upload failed, set error if not already set by repo/service
        if (ref.read(errorProvider) == null) {
          ref
              .read(errorProvider.notifier)
              .setError(AppError.network("Failed to upload audio to storage."));
        }
      }

      return success;
    } catch (e, stack) {
      print('[AudioUpload] ERROR during upload: $e');
      print('[AudioUpload] Stack trace: $stack');

      if (state != null) {
        state = state!.copyWith(
          status: UploadStatus.failed,
          errorMessage: () => 'Failed to upload audio: ${e.toString()}',
        );
      }
      // Set error if not already set
      if (ref.read(errorProvider) == null) {
        if (e is ApiException) {
          ref.read(errorProvider.notifier).setError(AppError.server(e.message));
        } else {
          ref.read(errorProvider.notifier).setError(AppError.generic(
              "An unexpected error occurred during audio upload."));
        }
      }
      return false;
    }
  }

  // Get the selected prompt (public getter for the internal state)
  AudioPrompt? get selectedPrompt => _selectedPrompt;

  // --- FIX: Update setSelectedPrompt to accept nullable AudioPrompt ---
  // Set the selected prompt (updates internal state)
  void setSelectedPrompt(AudioPrompt? prompt) {
    // --- END FIX ---
    print('[AudioUpload] Setting selected prompt: ${prompt?.value}');
    _selectedPrompt = prompt;
    // Note: This does NOT change the main `state` (MediaUploadModel) directly.
    // It only updates the internal variable used for validation and API calls.
  }
}
