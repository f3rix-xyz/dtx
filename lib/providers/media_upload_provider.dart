import 'dart:io';
import 'package:dtx/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import '../models/error_model.dart';
import '../models/media_upload_model.dart';
import '../repositories/media_repository.dart';
import 'error_provider.dart';
import 'service_provider.dart';

final mediaUploadProvider = StateNotifierProvider<MediaUploadNotifier, List<MediaUploadModel?>>((ref) {
  final mediaRepository = ref.watch(mediaRepositoryProvider);
  return MediaUploadNotifier(ref, mediaRepository);
});

class MediaUploadNotifier extends StateNotifier<List<MediaUploadModel?>> {
  final Ref ref;
  final MediaRepository _mediaRepository;
  
  // Initialize with 6 null slots for media
  MediaUploadNotifier(this.ref, this._mediaRepository) : super(List.filled(6, null));
  
  // File size limits in bytes
  static const int _maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int _maxVideoSizeBytes = 50 * 1024 * 1024; // 50 MB

  MediaUploadModel? _verificationImage;

  MediaUploadModel? get verificationImage => _verificationImage;

  void setVerificationImage(File file) {
    // Validate file size
    final fileSize = file.lengthSync();
    final fileName = path.basename(file.path);
    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';

    final isImage = mimeType.startsWith('image/');

    if (!isImage) {
      ref.read(errorProvider.notifier).setError(
        AppError.validation("Only image files are allowed."),
      );
      return;
    }

    if (fileSize > _maxImageSizeBytes) {
      ref.read(errorProvider.notifier).setError(
        AppError.validation("Image is too large. Maximum size is 10 MB."),
      );
      return;
    }

    // Update state
    _verificationImage = MediaUploadModel(
      file: file,
      fileName: fileName,
      fileType: mimeType,
    );
  }

  void clearVerificationImage() {
    _verificationImage = null;
  }

  Future<bool> uploadVerificationImage() async {
    if (_verificationImage == null) return false;

    try {
      // Clear any existing errors
      ref.read(errorProvider.notifier).clearError();

      // Get presigned URL
      final presignedUrl = await _mediaRepository.getVerificationPresignedUrl(
        _verificationImage!.fileName,
        _verificationImage!.fileType,
      );

      // Update verification image with presigned URL
      _verificationImage = _verificationImage!.copyWith(
        presignedUrl: () => presignedUrl,
        status: UploadStatus.inProgress,
      );

      // Upload the file
      final success = await _mediaRepository.uploadFileToS3(_verificationImage!);

      // Update status
      _verificationImage = _verificationImage!.copyWith(
        status: success ? UploadStatus.success : UploadStatus.failed,
        errorMessage: success ? () => null : () => 'Failed to upload verification image',
      );

      return success;
    } on ApiException catch (e) {
      _verificationImage = _verificationImage!.copyWith(
        status: UploadStatus.failed,
        errorMessage: () => e.message,
      );
      ref.read(errorProvider.notifier).setError(
        AppError.auth(e.message),
      );
      return false;
    } catch (e) {
      _verificationImage = _verificationImage!.copyWith(
        status: UploadStatus.failed,
        errorMessage: () => 'An unexpected error occurred. Please try again.',
      );
      ref.read(errorProvider.notifier).setError(
        AppError.auth("An unexpected error occurred. Please try again."),
      );
      return false;
    }
  }
  
  // Add or update media at a specific index
  void setMediaFile(int index, File file) {
    // Validate file size
    final fileSize = file.lengthSync();
    final fileName = path.basename(file.path);
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    
    final isImage = mimeType.startsWith('image/');
    final isVideo = mimeType.startsWith('video/');
    
    // Size validation
    if (isImage && fileSize > _maxImageSizeBytes) {
      ref.read(errorProvider.notifier).setError(
        AppError.validation("Image is too large. Maximum size is 10 MB."),
      );
      return;
    }
    
    if (isVideo && fileSize > _maxVideoSizeBytes) {
      ref.read(errorProvider.notifier).setError(
        AppError.validation("Video is too large. Maximum size is 50 MB."),
      );
      return;
    }
    
    // Update state
    final updatedState = [...state];
    updatedState[index] = MediaUploadModel(
      file: file,
      fileName: fileName,
      fileType: mimeType,
    );
    state = updatedState;
  }
  
  // Remove media at a specific index
  void removeMedia(int index) {
    final updatedState = [...state];
    updatedState[index] = null;
    state = updatedState;
  }
  
  // Get all non-null media items
  List<MediaUploadModel> getMediaItems() {
    return state.whereType<MediaUploadModel>().toList();
  }
  
  // Check if we have minimum required media (3)
  bool hasMinimumMedia() {
    return getMediaItems().length >= 3;
  }
  
  // Upload all media
  Future<bool> uploadAllMedia() async {
    final mediaItems = getMediaItems();
    if (mediaItems.isEmpty) return false;
    
    try {
      // Prepare file details for presigned URL request
      final fileDetails = mediaItems.map((item) => {
        'filename': item.fileName,
        'type': item.fileType,
      }).toList();
      
  print("lauda lassan 2");
      // Get presigned URLs
      final presignedUrlsResponse = await _mediaRepository.getPresignedUrls(fileDetails);
      
      // Update media items with presigned URLs
      final updatedState = [...state];
      for (int i = 0; i < mediaItems.length; i++) {
        final index = state.indexOf(mediaItems[i]);
        if (index >= 0 && index < presignedUrlsResponse.length) {
          updatedState[index] = mediaItems[i].copyWith(
            presignedUrl: () => presignedUrlsResponse[i]['url'],
            status: UploadStatus.inProgress,
          );
        }
      }
      state = updatedState;
      
      // Upload each file
      bool allSucceeded = true;
      for (int i = 0; i < mediaItems.length; i++) {
        final mediaItem = state.firstWhere(
          (item) => item?.fileName == mediaItems[i].fileName,
          orElse: () => null,
        );
        
        if (mediaItem != null) {
          final index = state.indexOf(mediaItem);
          bool success = false;
          
          try {
            success = await _mediaRepository.uploadFileToS3(mediaItem);
          } catch (e) {
            print('Initial upload failed: $e');
            success = false;
          }
          
          // Retry if failed
          if (!success) {
            success = await _mediaRepository.retryUpload(mediaItem);
          }
          
          // Update state with result
          final newUpdatedState = [...state];
          newUpdatedState[index] = mediaItem.copyWith(
            status: success ? UploadStatus.success : UploadStatus.failed,
            errorMessage: success ? () => null : () => 'Failed to upload',
          );
          state = newUpdatedState;
          
          if (!success) allSucceeded = false;
        }
      }
      
      return allSucceeded;
    } catch (e) {
      ref.read(errorProvider.notifier).setError(
        AppError.auth(e.toString()),
      );
      return false;
    }
  }
}
