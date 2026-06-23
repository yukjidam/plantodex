import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/plant_identification.dart';

/// Thrown when Pl@ntNet's daily quota (500 req/day on the free tier) is hit.
class PlantNetQuotaExceededException implements Exception {
  const PlantNetQuotaExceededException();
  @override
  String toString() => 'Pl@ntNet daily quota exceeded.';
}

class PlantNetService {
  PlantNetService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _baseUrl = 'https://my-api.plantnet.org/v2/identify';

  String get _apiKey => dotenv.env['PLANTNET_API_KEY'] ?? '';
  String get _project => dotenv.env['PLANTNET_PROJECT'] ?? 'all';

  /// Identifies the species in [image]. [organ] should be one of:
  /// "leaf", "flower", "fruit", "bark", "habit", or "auto" (default).
  Future<PlantIdentification> identify(
    File image, {
    String organ = 'auto',
  }) async {
    if (_apiKey.isEmpty) {
      throw StateError('PLANTNET_API_KEY is missing — check your .env file.');
    }

    final formData = FormData.fromMap({
      'organs': organ,
      'images': await MultipartFile.fromFile(image.path),
    });

    print('>>> PlantNet key: "${_apiKey}"');
    print('>>> PlantNet project: "${_project}"');

    try {
      final response = await _dio.post(
        '$_baseUrl/$_project',
        queryParameters: {'api-key': _apiKey, 'lang': 'en'},
        data: formData,
      );
      return PlantIdentification.fromPlantNetJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw const PlantNetQuotaExceededException();
      }
      rethrow;
    }
  }
}
