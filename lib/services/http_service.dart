// File: services/http_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Implementation of ApiService using the http package
class HttpService implements ApiService {
  @override
  final String baseUrl;

  HttpService({required this.baseUrl});

  @override
  Map<String, String> addAuthToken(Map<String, String>? headers, String token) {
    final updatedHeaders = {...(headers ?? {})};
    updatedHeaders['Authorization'] = 'Bearer $token';
    print(updatedHeaders);
    return updatedHeaders;
  }

  @override
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? headers}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          ...?headers,
        },
      );

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      throw ApiException('Failed to perform GET request: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          ...?headers,
        },
        body: json.encode(body),
      );

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to perform POST request: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> put(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          ...?headers,
        },
        body: json.encode(body),
      );

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to perform PUT request: ${e.toString()}');
    }
  }

  // --- ADDED PATCH METHOD ---
  @override
  Future<Map<String, dynamic>> patch(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          ...?headers,
        },
        body: json.encode(body),
      );
      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to perform PATCH request: ${e.toString()}');
    }
  }
  // --- END ADDED PATCH METHOD ---

  @override
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final request = http.Request('DELETE', Uri.parse('$baseUrl$endpoint'));

      request.headers.addAll({
        'Content-Type': 'application/json',
        ...?headers,
      });

      if (body != null) {
        request.body = json.encode(body);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to perform DELETE request: ${e.toString()}');
    }
  }

  /// Handle the HTTP response and convert to a standardized format
  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      // Allow empty body for success codes like 204 No Content
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return {'success': true, 'message': 'Operation successful'};
        }
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return responseData;
      } else {
        // Attempt to decode body even for errors, as it might contain error details
        Map<String, dynamic>? responseData;
        try {
          if (response.body.isNotEmpty) {
            responseData = json.decode(response.body) as Map<String, dynamic>;
          }
        } on FormatException {
          // Ignore format exception if body isn't valid JSON
          print("Warning: Non-JSON error response body: ${response.body}");
        }

        // Extract only the actual error message from the API response
        String errorMessage;

        if (responseData != null && responseData.containsKey('message')) {
          // Use the message directly from the response
          errorMessage = responseData['message'].toString();
        } else if (responseData != null && responseData.containsKey('error')) {
          // Some APIs use 'error' property
          errorMessage = responseData['error'].toString();
        } else {
          // Fallback error message including status code and reason phrase
          errorMessage =
              'Request failed: ${response.statusCode} ${response.reasonPhrase ?? ''}';
        }

        throw ApiException(errorMessage, statusCode: response.statusCode);
      }
    } on FormatException {
      // This catches JSON decoding errors for successful responses (shouldn't happen often)
      throw ApiException('Invalid response format received from server.',
          statusCode: response.statusCode);
    } catch (e) {
      // Catch other errors like network issues during response handling
      if (e is ApiException)
        rethrow; // Re-throw if it's already an ApiException
      throw ApiException('Failed to process response: ${e.toString()}',
          statusCode: response.statusCode);
    }
  }
}
