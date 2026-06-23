import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../models/plant_care_info.dart';
import '../models/plant_identification.dart';
import '../services/perenual_service.dart';
import '../services/plant_cache_db.dart';
import '../services/plant_gate_service.dart';
import '../services/plant_image_quality_service.dart';
import '../services/plantnet_service.dart';

/// Bundled result of the full identify → enrich pipeline.
class PlantResult {
  const PlantResult({required this.identification, required this.careInfo});
  final PlantIdentification identification;
  final PlantCareInfo careInfo;
}

/// Raised by the repository when the on-device gate decides the photo
/// isn't a plant — lets the UI short-circuit before any network call.
class NotAPlantException implements Exception {
  const NotAPlantException();
  @override
  String toString() => "That doesn't look like a plant.";
}

class PlantRepository {
  PlantRepository({
    PlantGateService? gate,
    PlantImageQualityService? quality,
    PlantNetService? plantNet,
    PerenualService? perenual,
    PlantCacheDb? cache,
  })  : _gate = gate ?? PlantGateService(),
        _quality = quality ?? const PlantImageQualityService(),
        _plantNet = plantNet ?? PlantNetService(),
        _perenual = perenual ?? PerenualService(),
        _cache = cache ?? PlantCacheDb.instance;

  final PlantGateService _gate;
  final PlantImageQualityService _quality;
  final PlantNetService _plantNet;
  final PerenualService _perenual;
  final PlantCacheDb _cache;

  /// Full pipeline:
  ///   1. ML Kit gate      — is this a plant?
  ///   2. Quality check    — is the photo good enough to identify?
  ///   3. Compress         — resize before upload
  ///   4. Pl@ntNet ID      — species identification
  ///   5. Perenual         — care info (cached)
  ///
  /// Throws [NotAPlantException], [PoorImageQualityException],
  /// [PlantIdNoMatchException], or [PlantNetQuotaExceededException] as needed.
  Future<PlantResult> identify(File photo) async {
    // Step 1 — plant gate
    final isPlant = await _gate.looksLikePlant(photo);
    if (!isPlant) {
      throw const NotAPlantException();
    }

    // Step 2 — image quality check (throws PoorImageQualityException if bad)
    await _quality.validate(photo);

    // Step 3 — compress
    final compressed = await _compress(photo);

    // Step 4 — species ID
    final identification = await _plantNet.identify(compressed);

    // Step 5 — care info (cache-first)
    var careInfo = await _cache.get(identification.scientificName);
    if (careInfo == null) {
      careInfo = await _perenual.fetchByName(identification.scientificName);
      await _cache.put(identification.scientificName, careInfo);
    }

    return PlantResult(identification: identification, careInfo: careInfo);
  }

  Future<File> _compress(File original) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/plantodex_upload_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      original.path,
      targetPath,
      minWidth: 1280,
      minHeight: 1280,
      quality: 80,
    );
    return File(result?.path ?? original.path);
  }

  void dispose() {
    _gate.dispose();
  }
}
