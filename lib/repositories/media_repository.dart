// File: repositories/media_repository.dart
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/utils/token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // <-- ADDED for kDebugMode

import '../models/media_upload_model.dart';
import '../services/api_service.dart';

class MediaRepository {
  final ApiService _apiService;
  final Ref? ref; // Keep ref if needed for token access

  MediaRepository(this._apiService, [this.ref]);

  // --- Helper to get token (avoids repetition) ---
  Future<String?> _getAuthToken() async {
    String? token;
    if (ref != null) {
      try {
        final authState = ref!.read(authProvider);
        token = authState.jwtToken;
      } catch (e) {
        if (kDebugMode) {
          print(
              "[MediaRepository _getAuthToken] Error reading auth provider: $e");
        }
      }
    }
    if (token == null || token.isEmpty) {
      token = await TokenStorage.getToken();
    }
    return token;
  }
  // --- END Helper ---

  // --- START: Method for CHAT Media Presigned URL ---
  /// Fetches presigned URL and final object URL for uploading media in chat.
  ///
  /// Throws [ApiException] on failure.
  Future<Map<String, String>> getChatMediaPresignedUrl(
      String filename, String fileType) async {
    final String methodName = 'getChatMediaPresignedUrl';
    if (kDebugMode) {
      print(
          '[MediaRepository $methodName] Getting chat media presigned URL for $filename ($fileType)...');
    }
    try {
      String? token = await _getAuthToken();
      if (token == null) {
        throw ApiException('Authentication token is missing');
      }
      final headers = {'Authorization': 'Bearer $token'};
      final body = {'filename': filename, 'type': fileType};
      if (kDebugMode) {
        print('[MediaRepository $methodName] Request Body: $body');
      }

      final response = await _apiService.post(
        '/api/chat/upload', // Use the CHAT media endpoint
        body: body,
        headers: headers,
      );

      if (kDebugMode) {
        print('[MediaRepository $methodName] API Response: $response');
      }
      if (response['success'] == true &&
          response['presigned_url'] != null &&
          response['object_url'] != null) {
        if (kDebugMode) {
          print('[MediaRepository $methodName] URLs received successfully.');
        }
        return {
          'presigned_url': response['presigned_url'].toString(),
          'object_url': response['object_url'].toString(),
        };
      } else {
        final message = response['message']?.toString() ??
            'Failed to get chat media presigned URL.';
        if (kDebugMode) {
          print('[MediaRepository $methodName] Failed: $message');
        }
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        print(
            '[MediaRepository $methodName] API Exception: ${e.message} (Status: ${e.statusCode})');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('[MediaRepository $methodName] Unexpected Error: $e');
      }
      throw ApiException('Error getting chat presigned URL: ${e.toString()}');
    }
  }
  // --- END CHAT Media Method ---

  // --- Existing methods (getEditPresignedUrls, getPresignedUrls, getAudioPresignedUrl, getVerificationPresignedUrl) ---
  // ... keep the existing code for these methods ...
  Future<List<Map<String, dynamic>>> getEditPresignedUrls(
      List<Map<String, String>> fileDetails) async {
    final String methodName = 'getEditPresignedUrls';
    print(
        '[MediaRepository $methodName] Getting presigned URLs for editing...');
    if (fileDetails.isEmpty) {
      print(
          '[MediaRepository $methodName] No file details provided, returning empty list.');
      return []; // Return empty list if no files need uploading
    }
    try {
      String? token = await _getAuthToken(); // Use helper to get token
      if (token == null) {
        throw ApiException('Authentication token is missing');
      }
      final headers = {'Authorization': 'Bearer $token'};
      final body = {'files': fileDetails};
      print('[MediaRepository $methodName] Request Body: $body');

      final response = await _apiService.post(
        '/api/edit-presigned-urls', // <-- Use the NEW endpoint
        body: body,
        headers: headers,
      );

      print('[MediaRepository $methodName] API Response: $response');
      if (response['uploads'] != null && response['uploads'] is List) {
        print('[MediaRepository $methodName] Presigned URLs received.');
        return List<Map<String, dynamic>>.from(response['uploads']);
      } else {
        final message = response['message']?.toString() ??
            'Failed to get edit presigned URLs.';
        print('[MediaRepository $methodName] Failed: $message');
        // Throw specific error if prerequisite failed
        if (message.contains("must have at least 3 existing media items")) {
          throw ApiException(message,
              statusCode: 400); // Use 400 as indicated in docs for this error
        }
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print(
          '[MediaRepository $methodName] API Exception: ${e.message} (Status: ${e.statusCode})');
      rethrow;
    } catch (e) {
      print('[MediaRepository $methodName] Unexpected Error: $e');
      throw ApiException('Error getting edit presigned URLs: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getPresignedUrls(
      List<Map<String, String>> fileDetails) async {
    // (Used for initial onboarding media upload)
    final String methodName = 'getPresignedUrls (Onboarding)';
    print(
        '[MediaRepository $methodName] Getting presigned URLs for onboarding...');
    try {
      String? token = await _getAuthToken();
      if (token == null) throw ApiException('Authentication token is missing');
      final headers = {'Authorization': 'Bearer $token'};
      final body = {'files': fileDetails};
      print('[MediaRepository $methodName] Request Body: $body');

      final response = await _apiService.post(
        '/upload', // <-- Uses the ORIGINAL endpoint for onboarding
        body: body,
        headers: headers,
      );

      print('[MediaRepository $methodName] API Response: $response');
      if (response['uploads'] != null && response['uploads'] is List) {
        print('[MediaRepository $methodName] Presigned URLs received.');
        return List<Map<String, dynamic>>.from(response['uploads']);
      } else {
        final message = response['message']?.toString() ??
            'Failed to get onboarding presigned URLs.';
        print('[MediaRepository $methodName] Failed: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print(
          '[MediaRepository $methodName] API Exception: ${e.message} (Status: ${e.statusCode})');
      rethrow;
    } catch (e) {
      print('[MediaRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'Error getting onboarding presigned URLs: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getAudioPresignedUrl(
      String filename, String fileType, AudioPrompt prompt) async {
    // (Keep as is for audio)
    final String methodName = 'getAudioPresignedUrl';
    print('[MediaRepository $methodName] Getting audio presigned URL...');
    try {
      String? token = await _getAuthToken();
      if (token == null) throw ApiException('Authentication token is missing');
      final headers = {'Authorization': 'Bearer $token'};
      final body = {
        'filename': filename,
        'type': fileType,
        'prompt': prompt.value,
      };
      print('[MediaRepository $methodName] Request Body: $body');
      final response = await _apiService.post(
        '/audio',
        body: body,
        headers: headers,
      );
      print('[MediaRepository $methodName] API Response: $response');
      return response;
    } on ApiException catch (e) {
      print(
          '[MediaRepository $methodName] API Exception: ${e.message} (Status: ${e.statusCode})');
      rethrow;
    } catch (e) {
      print('[MediaRepository $methodName] Unexpected Error: $e');
      throw ApiException('Error getting audio presigned URL: ${e.toString()}');
    }
  }

  Future<String> getVerificationPresignedUrl(
      String filename, String fileType) async {
    // (Keep as is for verification)
    final String methodName = 'getVerificationPresignedUrl';
    print(
        '[MediaRepository $methodName] Getting verification presigned URL...');
    try {
      String? token = await _getAuthToken();
      if (token == null) throw ApiException('Authentication token is missing');
      final headers = {'Authorization': 'Bearer $token'};
      final body = {'filename': filename, 'type': fileType};
      print('[MediaRepository $methodName] Request Body: $body');
      final response = await _apiService.post(
        '/verify',
        body: body,
        headers: headers,
      );
      print('[MediaRepository $methodName] API Response: $response');
      if (response['upload_url'] != null) {
        print('[MediaRepository $methodName] Presigned URL received.');
        return response['upload_url'];
      } else {
        final message = response['message']?.toString() ??
            'Failed to get verification presigned URL.';
        print('[MediaRepository $methodName] Failed: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print(
          '[MediaRepository $methodName] API Exception: ${e.message} (Status: ${e.statusCode})');
      rethrow;
    } catch (e) {
      print('[MediaRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'Error getting verification presigned URL: ${e.toString()}');
    }
  }
  // --- End Existing Methods ---

  // --- Upload a file to S3 using presigned URL (No changes needed) ---
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

      request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      request.headers.set(HttpHeaders.contentLengthHeader,
          (await file.length()).toString()); // Ensure length header

      final fileStream = file.openRead();
      await request.addStream(fileStream);
      final response = await request.close();

      final statusCode = response.statusCode;
      final responseBody = await response.transform(utf8.decoder).join();

      print('📩 Upload response: Status=$statusCode, Body=$responseBody');

      if (statusCode != HttpStatus.ok && statusCode != HttpStatus.created) {
        // Allow 201 Created as well
        print('❌ Upload failed with status $statusCode');
        return false;
      }

      print('✅ Upload successful for ${mediaUpload.fileName}');
      return true;
    } catch (e, stack) {
      print('‼️ Critical upload error: $e');
      print('🛑 Stack trace: $stack');
      return false; // Indicate failure
    }
  }
  // --- End S3 Upload ---

  // --- Retry failed uploads with exponential backoff (No changes needed) ---
  Future<bool> retryUpload(MediaUploadModel mediaUpload,
      {int maxRetries = 3}) async {
    int retryCount = 0;
    int backoffMs = 1000;

    while (retryCount < maxRetries) {
      try {
        // Add a small delay before retrying
        await Future.delayed(Duration(milliseconds: backoffMs ~/ 2));
        print(
            '🔄 Retrying upload ($retryCount/${maxRetries - 1}) for: ${mediaUpload.fileName}');
        final success = await uploadFileToS3(mediaUpload);
        if (success) return true;
      } catch (e) {
        print('Retry $retryCount failed: $e');
      }

      retryCount++;
      if (retryCount < maxRetries) {
        await Future.delayed(Duration(milliseconds: backoffMs));
        backoffMs *= 2;
      }
    }
    print(
        '❌ Upload failed after $maxRetries retries for: ${mediaUpload.fileName}');
    return false;
  }
  // --- End Retry Upload ---
}
