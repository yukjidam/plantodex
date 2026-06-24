import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/plant_care_info.dart';

/// Caches Perenual care-info lookups by scientific name so repeat
/// identifications of the same species don't burn API quota.
class PlantCacheDb {
  PlantCacheDb._();
  static final PlantCacheDb instance = PlantCacheDb._();

  Database? _db;

  // Cache entries older than this are refetched, in case Perenual's
  // data has been updated.
  static const _ttl = Duration(days: 30);

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'plant_cache.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE cached_species (
            scientific_name TEXT PRIMARY KEY,
            care_json TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<PlantCareInfo?> get(String scientificName) async {
    final db = await _database;
    final rows = await db.query(
      'cached_species',
      where: 'scientific_name = ?',
      whereArgs: [scientificName.toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final cachedAt =
        DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int);
    if (DateTime.now().difference(cachedAt) > _ttl) {
      return null; // stale, force a refetch
    }
    return PlantCareInfo.fromCacheJson(
        jsonDecode(row['care_json'] as String) as Map<String, dynamic>);
  }

  Future<void> put(String scientificName, PlantCareInfo info) async {
    final db = await _database;
    await db.insert(
      'cached_species',
      {
        'scientific_name': scientificName.toLowerCase(),
        'care_json': jsonEncode(info.toCacheJson()),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes all cached entries. Use during development to force a
  /// fresh Perenual fetch. Remove the call site once confirmed working.
  Future<void> clearAll() async {
    final db = await _database;
    await db.delete('cached_species');
  }
}
