import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/plant_care_info.dart';

class PerenualService {
  PerenualService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _baseUrl = 'https://perenual.com/api';

  String get _apiKey => dotenv.env['PERENUAL_API_KEY'] ?? '';

  /// Looks up care info by common/scientific name. Perenual's search is
  /// fuzzy on common name, so we try the cleanest term we have.
  Future<PlantCareInfo> fetchByName(String name) async {
    if (_apiKey.isEmpty) {
      throw StateError('PERENUAL_API_KEY is missing — check your .env file.');
    }

    // 1. Search for a species id matching the name.
    final searchRes = await _dio.get(
      '$_baseUrl/species-list',
      queryParameters: {'key': _apiKey, 'q': name},
    );
    final results = (searchRes.data['data'] as List<dynamic>? ?? []);
    if (results.isEmpty) {
      return PlantCareInfo.empty;
    }
    final id = (results.first as Map<String, dynamic>)['id'] as int;

    // 2. Fetch full details for that species id.
    final detailRes = await _dio.get(
      '$_baseUrl/species/details/$id',
      queryParameters: {'key': _apiKey},
    );
    return PlantCareInfo.fromPerenualDetailJson(
        detailRes.data as Map<String, dynamic>);
  }
}
