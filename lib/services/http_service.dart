// File: services/http_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'dart:developer' as developer; // Import developer for log function

/// Implementation of ApiService using the http package
class HttpService implements ApiService {
  @override
  final String baseUrl;

  HttpService({required this.baseUrl});

  // Helper function for logging
  void _log(String method, String url,
      {Object? body, Map<String, String>? headers}) {
    final logMessage = StringBuffer();
    logMessage.writeln("--------- HTTP Request ---------");
    logMessage.writeln("Method: $method");
    logMessage.writeln("URL: $url");
    if (headers != null) {
      // Avoid logging sensitive headers like Authorization directly in production logs if possible
      final sanitizedHeaders = Map<String, String>.from(headers);
      if (sanitizedHeaders.containsKey('Authorization')) {
        sanitizedHeaders['Authorization'] = 'Bearer [REDACTED]';
      }
      logMessage.writeln("Headers: $sanitizedHeaders");
    }
    if (body != null) {
      try {
        // Try to encode body for pretty printing, limit length
        String bodyString = json.encode(body);
        if (bodyString.length > 500) {
          bodyString = '${bodyString.substring(0, 500)}... [TRUNCATED]';
        }
        logMessage.writeln("Body: $bodyString");
      } catch (e) {
        logMessage.writeln("Body: (Could not encode body for logging: $e)");
      }
    }
    logMessage.write("--------------------------------");
    developer.log(logMessage.toString(),
        name: 'HttpService'); // Use developer.log
  }

  @override
  Map<String, String> addAuthToken(Map<String, String>? headers, String token) {
    final updatedHeaders = {...(headers ?? {})};
    updatedHeaders['Authorization'] = 'Bearer $token';
    // Avoid logging the token directly here if possible, logged sanitized in _log
    return updatedHeaders;
  }

  @override
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? headers}) async {
    final url = '$baseUrl$endpoint';
    _log('GET', url, headers: headers); // Log request
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type':
              'application/json', // Still specify expected request type
          // 'Accept-Charset': 'utf-8', // Tell server we prefer UTF-8
          ...?headers,
        },
      );
      // Pass the raw response to _handleResponse
      return _handleResponse(response, 'GET', url);
    } on SocketException catch (e) {
      developer.log('SocketException on GET $url: $e',
          name: 'HttpService', error: e);
      throw ApiException('No internet connection or server unavailable.');
    } catch (e) {
      developer.log('Error performing GET $url: $e',
          name: 'HttpService', error: e);
      if (e is ApiException) rethrow;
      throw ApiException('Failed to perform GET request: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final url = '$baseUrl$endpoint';
    _log('POST', url, body: body, headers: headers); // Log request
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type':
              'application/json; charset=utf-8', // Specify UTF-8 in request
          // 'Accept-Charset': 'utf-8', // And accept it
          ...?headers,
        },
        // json.encode naturally handles UTF-8
        body: json.encode(body),
      );
      // Pass the raw response to _handleResponse
      return _handleResponse(response, 'POST', url);
    } on SocketException catch (e) {
      developer.log('SocketException on POST $url: $e',
          name: 'HttpService', error: e);
      throw ApiException('No internet connection or server unavailable.');
    } catch (e) {
      developer.log('Error performing POST $url: $e',
          name: 'HttpService', error: e);
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
    final url = '$baseUrl$endpoint';
    _log('PUT', url, body: body, headers: headers); // Log request
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          // 'Accept-Charset': 'utf-8',
          ...?headers,
        },
        body: json.encode(body),
      );
      return _handleResponse(response, 'PUT', url);
    } on SocketException catch (e) {
      developer.log('SocketException on PUT $url: $e',
          name: 'HttpService', error: e);
      throw ApiException('No internet connection or server unavailable.');
    } catch (e) {
      developer.log('Error performing PUT $url: $e',
          name: 'HttpService', error: e);
      if (e is ApiException) rethrow;
      throw ApiException('Failed to perform PUT request: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> patch(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final url = '$baseUrl$endpoint';
    _log('PATCH', url, body: body, headers: headers); // Log request
    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          // 'Accept-Charset': 'utf-8',
          ...?headers,
        },
        body: json.encode(body),
      );
      return _handleResponse(response, 'PATCH', url);
    } on SocketException catch (e) {
      developer.log('SocketException on PATCH $url: $e',
          name: 'HttpService', error: e);
      throw ApiException('No internet connection or server unavailable.');
    } catch (e) {
      developer.log('Error performing PATCH $url: $e',
          name: 'HttpService', error: e);
      if (e is ApiException) rethrow;
      throw ApiException('Failed to perform PATCH request: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = '$baseUrl$endpoint';
    _log('DELETE', url, body: body, headers: headers); // Log request
    try {
      final request = http.Request('DELETE', Uri.parse(url));

      request.headers.addAll({
        'Content-Type': 'application/json; charset=utf-8',
        // 'Accept-Charset': 'utf-8',
        ...?headers,
      });

      if (body != null) {
        request.body = json.encode(body);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response, 'DELETE', url);
    } on SocketException catch (e) {
      developer.log('SocketException on DELETE $url: $e',
          name: 'HttpService', error: e);
      throw ApiException('No internet connection or server unavailable.');
    } catch (e) {
      developer.log('Error performing DELETE $url: $e',
          name: 'HttpService', error: e);
      if (e is ApiException) rethrow;
      throw ApiException('Failed to perform DELETE request: ${e.toString()}');
    }
  }

  /// Handle the HTTP response, decode it, and convert to a standardized format
  Map<String, dynamic> _handleResponse(
      http.Response response, String method, String url) {
    final logResponse = StringBuffer();
    logResponse.writeln("--------- HTTP Response ---------");
    logResponse.writeln("URL: $method $url");
    logResponse.writeln("Status Code: ${response.statusCode}");
    logResponse.writeln("Headers: ${response.headers}");
    // Log raw bytes (truncated) - useful for seeing if corruption happened before decoding
    final bytesLength = response.bodyBytes.length;
    final truncatedBytes =
        response.bodyBytes.sublist(0, (bytesLength > 200 ? 200 : bytesLength));
    logResponse.writeln(
        "Raw Body Bytes (first ${truncatedBytes.length}): $truncatedBytes");

    String responseBody = ''; // Store decoded body

    try {
      // *** Explicitly decode response body as UTF-8 ***
      // Use allowMalformed: true to prevent crashing if bytes are truly invalid
      // Although if they are invalid, the source is likely the server or proxy.
      responseBody = utf8.decode(response.bodyBytes, allowMalformed: true);
      logResponse.writeln(
          "Decoded Body (UTF-8, truncated): ${responseBody.substring(0, (responseBody.length > 500 ? 500 : responseBody.length))}...");
      logResponse.write("--------------------------------");
      developer.log(logResponse.toString(),
          name: 'HttpService'); // Log before JSON decode attempt

      // --- Process based on Status Code ---
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.isEmpty) {
          developer.log(
              'Success (Status ${response.statusCode}) with empty body.',
              name: 'HttpService');
          return {'success': true, 'message': 'Operation successful'};
        }
        // Attempt to decode the JSON from the UTF-8 string
        final responseData = json.decode(responseBody) as Map<String, dynamic>;
        developer.log('Success (Status ${response.statusCode}) with JSON body.',
            name: 'HttpService');
        return responseData; // Assuming server sends success field if applicable
      } else {
        // --- Handle Error Status Codes ---
        developer.log('Error Status Code: ${response.statusCode}',
            name: 'HttpService');
        Map<String, dynamic>? responseData;
        String errorMessage =
            'Request failed: ${response.statusCode} ${response.reasonPhrase ?? ''}'; // Default error

        try {
          if (responseBody.isNotEmpty) {
            // Try to parse error details from the body
            responseData = json.decode(responseBody) as Map<String, dynamic>;
            if (responseData.containsKey('message')) {
              errorMessage = responseData['message'].toString();
            } else if (responseData.containsKey('error')) {
              errorMessage = responseData['error'].toString();
            }
            developer.log('Parsed error response body: $responseData',
                name: 'HttpService');
          }
        } on FormatException {
          developer.log('Warning: Non-JSON error response body received.',
              name: 'HttpService');
          // Use the default errorMessage from status code/reason phrase
        }

        // Throw the specific error
        throw ApiException(errorMessage, statusCode: response.statusCode);
      }
    } on FormatException catch (e) {
      // Catch errors during json.decode()
      final bodyStart = responseBody.substring(
          0, (responseBody.length > 200 ? 200 : responseBody.length));
      developer.log(
          'JSON FormatException: $e. Decoded body started with: "$bodyStart"',
          name: 'HttpService',
          error: e);
      throw ApiException('Invalid JSON format received from server.',
          statusCode: response.statusCode);
    } catch (e) {
      // Catch other errors during response handling (e.g., UTF-8 decode if malformed bytes were strict)
      developer.log('Error processing response: $e',
          name: 'HttpService', error: e);
      // Re-throw specific ApiException if it came from the error handling block above
      if (e is ApiException) rethrow;
      // Otherwise, wrap in a generic ApiException
      throw ApiException('Failed to process response: ${e.toString()}',
          statusCode: response.statusCode);
    }
  }
}
