
// models/media_upload_model.dart
import 'dart:io';

enum UploadStatus {
  idle,
  inProgress,
  success,
  failed,
}

class MediaUploadModel {
  final File file;
  final String fileName;
  final String fileType;
  final String? presignedUrl;
  final UploadStatus status;
  final String? errorMessage;
  
  MediaUploadModel({
    required this.file,
    required this.fileName,
    required this.fileType,
    this.presignedUrl,
    this.status = UploadStatus.idle,
    this.errorMessage,
  });
  
  MediaUploadModel copyWith({
    File? file,
    String? fileName,
    String? fileType,
    String? Function()? presignedUrl,
    UploadStatus? status,
    String? Function()? errorMessage,
  }) {
    return MediaUploadModel(
      file: file ?? this.file,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      presignedUrl: presignedUrl != null ? presignedUrl() : this.presignedUrl,
      status: status ?? this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}
