import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../models/caught_plant.dart';
import '../models/plant_identification.dart';
import '../models/plant_care_info.dart';
import '../services/gbif_service.dart';
import '../services/plantnet_service.dart';
import '../services/wikipedia_service.dart';

// ── Result wrapper ─────────────────────────────────────────────────────────────

/// Bundles the Pl@ntNet identification with the Wikipedia care info so
/// the UI only needs one object from the repository.
class PlantResult {
  const PlantResult({
    required this.identification,
    required this.careInfo,
  });

  final PlantIdentification identification;
  final PlantCareInfo careInfo;
}

// ── Exceptions ─────────────────────────────────────────────────────────────────

/// Thrown when the image doesn't appear to contain a plant.
class NotAPlantException implements Exception {
  const NotAPlantException();
  @override
  String toString() => 'Image does not appear to contain a plant.';
}

/// Thrown when the user tries to save a plant they've already caught.
class DuplicateCatchException implements Exception {
  const DuplicateCatchException(this.scientificName);
  final String scientificName;
  @override
  String toString() => '$scientificName is already in your Dex.';
}

// ── Repository ─────────────────────────────────────────────────────────────────

class PlantRepository {
  PlantRepository({
    PlantNetService? plantNetService,
    WikipediaService? wikipediaService,
    GbifService? gbifService,
  })  : _plantNet = plantNetService ?? PlantNetService(),
        _wikipedia = wikipediaService ?? WikipediaService(),
        _gbif = gbifService ?? GbifService();

  static final PlantRepository instance = PlantRepository();

  final PlantNetService _plantNet;
  final WikipediaService _wikipedia;
  final GbifService _gbif;

  AppDatabase? _db;

  Future<AppDatabase> get _database async {
    _db ??= await AppDatabase.getInstance();
    return _db!;
  }

  // ── Identification flow ────────────────────────────────────────────────────

  /// Calls Pl@ntNet then Wikipedia and returns a bundled [PlantResult].
  Future<PlantResult> identify(File photo) async {
    final identification = await _plantNet.identify(photo);

    // A very low confidence score means it's probably not a plant at all.
    if (identification.confidence < 0.05) {
      throw const NotAPlantException();
    }

    final careInfo =
        await _wikipedia.fetchByScientificName(identification.scientificName);

    return PlantResult(
      identification: identification,
      careInfo: careInfo,
    );
  }

  void dispose() {
    // Nothing to close currently, kept for API compatibility with
    // DetectionProvider which calls _repository.dispose().
  }

  // ── Save a catch ───────────────────────────────────────────────────────────

  /// Copies [photo] into the app's documents directory, then saves all
  /// plant data to the database. Returns the new row's id.
  Future<int> saveCatch({
    required File photo,
    required PlantIdentification identification,
    required PlantCareInfo careInfo,
  }) async {
    if (await alreadyCaught(identification.scientificName)) {
      throw DuplicateCatchException(identification.scientificName);
    }

    final savedPhotoPath =
        await _savePhoto(photo, identification.scientificName);

    // Derive rarity from GBIF occurrence count — falls back to common on error.
    final rarity = (await _gbif.rarityFor(identification.scientificName)).name;

    final plant = CaughtPlant(
      commonName: identification.commonName,
      scientificName: identification.scientificName,
      confidence: identification.confidence,
      rarity: rarity,
      description: careInfo.description,
      family: careInfo.family,
      genus: careInfo.genus,
      toxicity: careInfo.toxicity,
      edible: careInfo.edible,
      thumbnailUrl: careInfo.thumbnailUrl,
      habitat: careInfo.habitat,
      careTips: careInfo.careTips,
      propagation: careInfo.propagation,
      floweringSeason: careInfo.floweringSeason,
      conservationStatus: careInfo.conservationStatus,
      funFacts: careInfo.funFacts,
      durationRaw: careInfo.duration.join(','),
      lightLevel: careInfo.lightLevel,
      atmosphericHumidity: careInfo.atmosphericHumidity,
      photoPath: savedPhotoPath,
      caughtAt: DateTime.now().millisecondsSinceEpoch,
    );

    final db = await _database;
    return db.caughtPlantDao.insertPlant(plant);
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<List<CaughtPlant>> getAllCatches() async {
    final db = await _database;
    return db.caughtPlantDao.getAllPlants();
  }

  Future<CaughtPlant?> getCatchById(int id) async {
    final db = await _database;
    return db.caughtPlantDao.getPlantById(id);
  }

  Future<bool> alreadyCaught(String scientificName) async {
    final db = await _database;
    final count = await db.caughtPlantDao.countByScientificName(scientificName);
    return (count ?? 0) > 0;
  }

  Future<int> totalCaught() async {
    final db = await _database;
    return (await db.caughtPlantDao.getTotalCount()) ?? 0;
  }

  Stream<List<CaughtPlant>> watchAllCatches() async* {
    final db = await _database;
    yield* db.caughtPlantDao.watchAllPlants();
  }

  Stream<int> watchTotalCount() async* {
    final db = await _database;
    yield* db.caughtPlantDao.watchTotalCount().map((n) => n ?? 0);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteCatch(CaughtPlant plant) async {
    final photoFile = File(plant.photoPath);
    if (await photoFile.exists()) await photoFile.delete();

    final db = await _database;
    await db.caughtPlantDao.deletePlant(plant);
  }

  // ── Photo helper ───────────────────────────────────────────────────────────

  Future<String> _savePhoto(File photo, String scientificName) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final catchDir = Directory(p.join(docsDir.path, 'caught_plants'));
    if (!await catchDir.exists()) await catchDir.create(recursive: true);

    final safeName =
        scientificName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext =
        p.extension(photo.path).isNotEmpty ? p.extension(photo.path) : '.jpg';
    final filename = '${safeName}_$timestamp$ext';

    final dest = File(p.join(catchDir.path, filename));
    await photo.copy(dest.path);

    debugPrint('[PlantRepository] photo saved → ${dest.path}');
    return dest.path;
  }
}
