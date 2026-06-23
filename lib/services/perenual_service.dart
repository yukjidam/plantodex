import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/plant_care_info.dart';

class PerenualService {
  PerenualService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _baseUrl = 'https://perenual.com/api';

  String get _apiKey => dotenv.env['PERENUAL_API_KEY'] ?? '';

  /// Looks up care info by common name first, then scientific name as fallback.
  /// Returns [PlantCareInfo.empty] if no match is found or the species is
  /// behind Perenual's paywall (406).
  Future<PlantCareInfo> fetchByName(String scientificName,
      {String? commonName}) async {
    if (_apiKey.isEmpty) {
      throw StateError('PERENUAL_API_KEY is missing — check your .env file.');
    }

    // Try common name first (better match rate), then scientific name.
    final candidates = [
      if (commonName != null && commonName.isNotEmpty) commonName,
      scientificName,
    ];

    for (final query in candidates) {
      final care = await _tryFetch(query);
      if (care != null) return care;
    }

    return PlantCareInfo.empty;
  }

  Future<PlantCareInfo?> _tryFetch(String query) async {
    try {
      final searchRes = await _dio.get(
        '$_baseUrl/species-list',
        queryParameters: {'key': _apiKey, 'q': query},
      );

      final results = (searchRes.data['data'] as List<dynamic>? ?? []);
      if (results.isEmpty) return null;

      final id = (results.first as Map<String, dynamic>)['id'] as int;

      final detailRes = await _dio.get(
        '$_baseUrl/species/details/$id',
        queryParameters: {'key': _apiKey},
      );

      return PlantCareInfo.fromPerenualDetailJson(
          detailRes.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 406 = species exists but is behind Perenual's paywall
      final status = e.response?.statusCode;
      if (status == 406 || status == 404 || status == 429) {
        return null;
      }
      rethrow;
    }
  }
}
