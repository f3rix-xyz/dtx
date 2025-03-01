// File: repositories/media_repository.dart
import 'dart:convert';
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
// Upload a file to S3 using presigned URL
Future<bool> uploadFileToS3(MediaUploadModel mediaUpload) async {
  if (mediaUpload.presignedUrl == null) {
    throw ApiException('Missing presigned URL for upload');
  }

  final file = mediaUpload.file;
  final contentType = mediaUpload.fileType;
  final filePath = file.path;

  try {
    print('⏫ Starting S3 upload for: ${mediaUpload.fileName}');
    print('📁 File path: $filePath');
    print('📦 Content-Type: $contentType');
    print('📏 File size: ${(await file.length()) / 1024} KB');
    print('🔗 Presigned URL: ${mediaUpload.presignedUrl}');

    final client = HttpClient();
    final request = await client.putUrl(Uri.parse(mediaUpload.presignedUrl!));
    
    // Set headers from curl example
    request.headers.set(HttpHeaders.contentTypeHeader, contentType);
    request.contentLength = await file.length();

    // Add debug headers
    print('📨 Request headers:');
    request.headers.forEach((name, values) {
      print('   $name: ${values.join(', ')}');
    });

    // Pipe file content directly
    final fileStream = file.openRead();
    await request.addStream(fileStream);
    final response = await request.close();

    // Get response details
    final statusCode = response.statusCode;
    final responseHeaders = response.headers;
    final responseBody = await response.transform(utf8.decoder).join();

    print('📩 Upload response:');
    print('   Status: $statusCode');
    print('   Headers:');
    responseHeaders.forEach((name, values) {
      print('     $name: ${values.join(', ')}');
    });
    print('   Body: $responseBody');

    if (statusCode != HttpStatus.ok) {
      print('❌ Upload failed with status $statusCode');
      return false;
    }

    print('✅ Upload successful for ${mediaUpload.fileName}');
    return true;
  } catch (e, stack) {
    print('‼️ Critical upload error: $e');
    print('🛑 Stack trace: $stack');
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
