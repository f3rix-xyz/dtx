// File: repositories/media_repository.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/utils/token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../models/media_upload_model.dart';
import '../services/api_service.dart';

class MediaRepository {
  final ApiService _apiService;
  final Ref? ref;
  
  MediaRepository(this._apiService, [this.ref]);
  
  // Get presigned URLs for uploading files
  Future<List<Map<String, dynamic>>> getPresignedUrls(List<Map<String, String>> fileDetails) async {
    try {
      // Get the token either from the provider or storage
      String? token;
      if (ref != null) {
        final authState = ref!.read(authProvider);
        token = authState.jwtToken;
      }
      
      if (token == null) {
        // Fallback to token storage if not available from provider
        token = await TokenStorage.getToken();
      }
      
      if (token == null) {
        throw ApiException('Authentication token is missing');
      }
      
      // Create auth headers
      final headers = {
        'Authorization': 'Bearer $token',
      };
      
      final response = await _apiService.post(
        '/upload',
        body: {
          'files': fileDetails,
        },
        headers: headers,
      );
      
      if (response['uploads'] != null) {
        return List<Map<String, dynamic>>.from(response['uploads']);
      } else {
        throw ApiException('Failed to get presigned URLs');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error getting presigned URLs: ${e.toString()}');
    }
  }

  // Get presigned URL for audio upload
  Future<Map<String, dynamic>> getAudioPresignedUrl(String filename, String fileType, AudioPrompt prompt) async {
    try {
      // Get the token either from the provider or storage
      String? token;
      if (ref != null) {
        final authState = ref!.read(authProvider);
        token = authState.jwtToken;
      }
      
      if (token == null) {
        // Fallback to token storage if not available from provider
        token = await TokenStorage.getToken();
      }
      
      if (token == null) {
        throw ApiException('Authentication token is missing');
      }
      
      // Create auth headers
      final headers = {
        'Authorization': 'Bearer $token',
      };
      
      final response = await _apiService.post(
        '/audio',
        body: {
          'filename': filename,
          'type': fileType,
          'prompt': prompt.value,
        },
        headers: headers,
      );
      
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error getting audio presigned URL: ${e.toString()}');
    }
  }

    // Get presigned URL for verification photo upload
  Future<String> getVerificationPresignedUrl(String filename, String fileType) async {
    try {
      // Get the token either from the provider or storage
      String? token;
      if (ref != null) {
        final authState = ref!.read(authProvider);
        token = authState.jwtToken;
      }

      if (token == null) {
        // Fallback to token storage if not available from provider
        token = await TokenStorage.getToken();
      }

      if (token == null) {
        throw ApiException('Authentication token is missing');
      }

      // Create auth headers
      final headers = {
        'Authorization': 'Bearer $token',
      };

      final response = await _apiService.post(
        '/verify',
        body: {
          'filename': filename,
          'type': fileType,
        },
        headers: headers,
      );

      if (response['upload_url'] != null) {
        return response['upload_url'];
      } else {
        throw ApiException('Failed to get verification presigned URL');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error getting verification presigned URL: ${e.toString()}');
    }
  }
  
  // Upload a file to S3 using presigned URL
  Future<bool> uploadFileToS3(MediaUploadModel mediaUpload) async {
    if (mediaUpload.presignedUrl == null) {
      throw ApiException('Missing presigned URL for upload');
    }

    try {
      final dio = Dio();
      final file = mediaUpload.file;
      final fileLength = await file.length();
      final contentType = mediaUpload.fileType;

      print('▶ Starting upload for: ${mediaUpload.fileName}');
      print('ℹ Presigned URL: ${mediaUpload.presignedUrl}');
      print('ℹ File size: ${fileLength / 1024} KB');
      print('ℹ Content-Type: $contentType');

      final response = await dio.put(
        mediaUpload.presignedUrl!,
        data: await file.openRead().toList().then((lists) => lists.expand((x) => x).toList()),
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': fileLength.toString(),
          },
          contentType: contentType,
          receiveDataWhenStatusError: true,
          validateStatus: (status) => true,
          followRedirects: false,
          maxRedirects: 0,
          listFormat: ListFormat.multiCompatible,
        ),
      );

      print('◀ Response received');
      print('ℹ Status code: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e, stack) {
      print('‼ Upload error: $e');
      return false;
    }
  }

  // Retry failed uploads with exponential backoff
  Future<bool> retryUpload(MediaUploadModel mediaUpload, {int maxRetries = 3}) async {
    int retryCount = 0;
    int backoffMs = 1000; // Start with 1 second
    
    while (retryCount < maxRetries) {
      try {
        final success = await uploadFileToS3(mediaUpload);
        if (success) return true;
      } catch (e) {
        print('Retry $retryCount failed: $e');
      }
      
      retryCount++;
      if (retryCount < maxRetries) {
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: backoffMs));
        backoffMs *= 2; // Double the wait time for next retry
      }
    }
    
    return false;
  }
}
