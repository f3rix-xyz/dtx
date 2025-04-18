// File: services/api_service.dart
import 'dart:convert';

/// Abstract class defining the API service interface
abstract class ApiService {
  /// Base URL for all API requests
  String get baseUrl;

  /// Makes a GET request to the specified endpoint
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? headers});

  /// Makes a POST request to the specified endpoint with the provided body
  Future<Map<String, dynamic>> post(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  });

  /// Makes a PUT request to the specified endpoint with the provided body
  Future<Map<String, dynamic>> put(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  });

  /// Makes a PATCH request to the specified endpoint with the provided body
  Future<Map<String, dynamic>> patch(
    // <<< ADDED
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  });

  /// Makes a DELETE request to the specified endpoint
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });

  /// Adds authorization token to headers
  Map<String, String> addAuthToken(Map<String, String>? headers, String token);
}

/// Exception thrown when API requests fail
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException: $message ${statusCode != null ? '(Status code: $statusCode)' : ''}';
}
