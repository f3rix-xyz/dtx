// lib/repositories/filter_repository.dart
import 'package:dtx/models/filter_model.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/utils/token_storage.dart';

class FilterRepository {
  final ApiService _apiService;

  FilterRepository(this._apiService);

  Future<FilterSettings> fetchFilters() async {
    final String methodName = 'fetchFilters';
    print('[FilterRepository $methodName] Fetching filters...');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');
      final headers = {'Authorization': 'Bearer $token'};

      // *** Log the raw response from the API ***
      final response =
          await _apiService.get('/api/get-filters', headers: headers);
      print('[FilterRepository $methodName] Raw API Response: $response');
      // *** End Log ***

      if (response['success'] == true) {
        if (response['filters'] != null &&
            response['filters'] is Map<String, dynamic>) {
          print('[FilterRepository $methodName] Filters found, parsing...');
          // Parsing happens within the factory now
          return FilterSettings.fromJson(
              response['filters'] as Map<String, dynamic>);
        } else {
          print(
              '[FilterRepository $methodName] Filters not set by API, returning defaults.');
          return const FilterSettings(); // Return default settings
        }
      } else {
        final message = response['message']?.toString() ??
            'Failed to fetch filters (API success false).';
        print('[FilterRepository $methodName] Fetch failed: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print(
          '[FilterRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      print(
          '[FilterRepository $methodName] Returning default filters due to API Exception.');
      return const FilterSettings(); // Return default on API error
    } catch (e) {
      print('[FilterRepository $methodName] Unexpected Error: $e');
      print(
          '[FilterRepository $methodName] Returning default filters due to Unexpected Error.');
      return const FilterSettings(); // Return default on unexpected errors
    }
  }

  Future<bool> updateFilters(FilterSettings filters) async {
    // ... (updateFilters remains the same as previous version) ...
    final String methodName = 'updateFilters';
    print('[FilterRepository $methodName] Updating filters...');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw ApiException('Authentication token missing');
      final headers = {'Authorization': 'Bearer $token'};
      final body = filters.toJsonForApi();
      print('[FilterRepository $methodName] Request Body: $body');
      final response =
          await _apiService.post('/api/filters', body: body, headers: headers);
      print('[FilterRepository $methodName] API Response: $response');
      if (response['success'] == true) {
        print('[FilterRepository $methodName] Filters updated successfully.');
        return true;
      } else {
        final message =
            response['message']?.toString() ?? 'Failed to update filters.';
        print('[FilterRepository $methodName] Update failed: $message');
        throw ApiException(message);
      }
    } on ApiException catch (e) {
      print(
          '[FilterRepository $methodName] API Exception: ${e.message}, Status: ${e.statusCode}');
      rethrow;
    } catch (e) {
      print('[FilterRepository $methodName] Unexpected Error: $e');
      throw ApiException(
          'An unexpected error occurred while updating filters: ${e.toString()}');
    }
  }
}
