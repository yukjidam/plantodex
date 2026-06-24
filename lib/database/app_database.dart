// GENERATED CODE ANNOTATION — run build_runner after any schema change:
//   flutter pub run build_runner build --delete-conflicting-outputs

import 'dart:async';
import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../models/caught_plant.dart';
import '../dao/caught_plant_dao.dart';

part 'app_database.g.dart';

@Database(version: 1, entities: [CaughtPlant])
abstract class AppDatabase extends FloorDatabase {
  CaughtPlantDao get caughtPlantDao;

  // ── Singleton ──────────────────────────────────────────────────────

  static AppDatabase? _instance;

  static Future<AppDatabase> getInstance() async {
    _instance ??=
        await $FloorAppDatabase.databaseBuilder('app_database.db').build();
    return _instance!;
  }
}
