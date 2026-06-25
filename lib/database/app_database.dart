// GENERATED CODE ANNOTATION — run build_runner after any schema change:
//   flutter pub run build_runner build --delete-conflicting-outputs

import 'dart:async';
import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../models/caught_plant.dart';
import '../dao/caught_plant_dao.dart';

part 'app_database.g.dart';

// ── Migration: v1 → v2 ────────────────────────────────────────────────────────
// Adds latitude + longitude to caught_plants. Nullable so existing rows
// don't need backfilling — plants caught before Phase 7 simply won't appear
// on the map.
final _migration1to2 = Migration(1, 2, (db) async {
  await db.execute(
    'ALTER TABLE caught_plants ADD COLUMN latitude REAL',
  );
  await db.execute(
    'ALTER TABLE caught_plants ADD COLUMN longitude REAL',
  );
});

@Database(version: 2, entities: [CaughtPlant])
abstract class AppDatabase extends FloorDatabase {
  CaughtPlantDao get caughtPlantDao;

  // ── Singleton ──────────────────────────────────────────────────────

  static AppDatabase? _instance;

  static Future<AppDatabase> getInstance() async {
    _instance ??= await $FloorAppDatabase
        .databaseBuilder('app_database.db')
        .addMigrations([_migration1to2]).build();
    return _instance!;
  }
}
