// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

abstract class $AppDatabaseBuilderContract {
  /// Adds migrations to the builder.
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations);

  /// Adds a database [Callback] to the builder.
  $AppDatabaseBuilderContract addCallback(Callback callback);

  /// Creates the database and initializes it.
  Future<AppDatabase> build();
}

// ignore: avoid_classes_with_only_static_members
class $FloorAppDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract databaseBuilder(String name) =>
      _$AppDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract inMemoryDatabaseBuilder() =>
      _$AppDatabaseBuilder(null);
}

class _$AppDatabaseBuilder implements $AppDatabaseBuilderContract {
  _$AppDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  @override
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  @override
  $AppDatabaseBuilderContract addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  @override
  Future<AppDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$AppDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$AppDatabase extends AppDatabase {
  _$AppDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  CaughtPlantDao? _caughtPlantDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `caught_plants` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `commonName` TEXT NOT NULL, `scientificName` TEXT NOT NULL, `confidence` REAL NOT NULL, `rarity` TEXT NOT NULL, `description` TEXT NOT NULL, `family` TEXT NOT NULL, `genus` TEXT NOT NULL, `toxicity` TEXT NOT NULL, `edible` INTEGER NOT NULL, `thumbnailUrl` TEXT, `habitat` TEXT, `careTips` TEXT, `propagation` TEXT, `floweringSeason` TEXT, `conservationStatus` TEXT, `funFacts` TEXT, `durationRaw` TEXT NOT NULL, `lightLevel` INTEGER, `atmosphericHumidity` INTEGER, `photoPath` TEXT NOT NULL, `latitude` REAL, `longitude` REAL, `caughtAt` INTEGER NOT NULL)');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  CaughtPlantDao get caughtPlantDao {
    return _caughtPlantDaoInstance ??=
        _$CaughtPlantDao(database, changeListener);
  }
}

class _$CaughtPlantDao extends CaughtPlantDao {
  _$CaughtPlantDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database, changeListener),
        _caughtPlantInsertionAdapter = InsertionAdapter(
            database,
            'caught_plants',
            (CaughtPlant item) => <String, Object?>{
                  'id': item.id,
                  'commonName': item.commonName,
                  'scientificName': item.scientificName,
                  'confidence': item.confidence,
                  'rarity': item.rarity,
                  'description': item.description,
                  'family': item.family,
                  'genus': item.genus,
                  'toxicity': item.toxicity,
                  'edible': item.edible ? 1 : 0,
                  'thumbnailUrl': item.thumbnailUrl,
                  'habitat': item.habitat,
                  'careTips': item.careTips,
                  'propagation': item.propagation,
                  'floweringSeason': item.floweringSeason,
                  'conservationStatus': item.conservationStatus,
                  'funFacts': item.funFacts,
                  'durationRaw': item.durationRaw,
                  'lightLevel': item.lightLevel,
                  'atmosphericHumidity': item.atmosphericHumidity,
                  'photoPath': item.photoPath,
                  'latitude': item.latitude,
                  'longitude': item.longitude,
                  'caughtAt': item.caughtAt
                },
            changeListener),
        _caughtPlantDeletionAdapter = DeletionAdapter(
            database,
            'caught_plants',
            ['id'],
            (CaughtPlant item) => <String, Object?>{
                  'id': item.id,
                  'commonName': item.commonName,
                  'scientificName': item.scientificName,
                  'confidence': item.confidence,
                  'rarity': item.rarity,
                  'description': item.description,
                  'family': item.family,
                  'genus': item.genus,
                  'toxicity': item.toxicity,
                  'edible': item.edible ? 1 : 0,
                  'thumbnailUrl': item.thumbnailUrl,
                  'habitat': item.habitat,
                  'careTips': item.careTips,
                  'propagation': item.propagation,
                  'floweringSeason': item.floweringSeason,
                  'conservationStatus': item.conservationStatus,
                  'funFacts': item.funFacts,
                  'durationRaw': item.durationRaw,
                  'lightLevel': item.lightLevel,
                  'atmosphericHumidity': item.atmosphericHumidity,
                  'photoPath': item.photoPath,
                  'latitude': item.latitude,
                  'longitude': item.longitude,
                  'caughtAt': item.caughtAt
                },
            changeListener);

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<CaughtPlant> _caughtPlantInsertionAdapter;

  final DeletionAdapter<CaughtPlant> _caughtPlantDeletionAdapter;

  @override
  Future<List<CaughtPlant>> getAllPlants() async {
    return _queryAdapter.queryList(
        'SELECT * FROM caught_plants ORDER BY caughtAt DESC',
        mapper: (Map<String, Object?> row) => CaughtPlant(
            id: row['id'] as int?,
            commonName: row['commonName'] as String,
            scientificName: row['scientificName'] as String,
            confidence: row['confidence'] as double,
            rarity: row['rarity'] as String,
            description: row['description'] as String,
            family: row['family'] as String,
            genus: row['genus'] as String,
            toxicity: row['toxicity'] as String,
            edible: (row['edible'] as int) != 0,
            thumbnailUrl: row['thumbnailUrl'] as String?,
            habitat: row['habitat'] as String?,
            careTips: row['careTips'] as String?,
            propagation: row['propagation'] as String?,
            floweringSeason: row['floweringSeason'] as String?,
            conservationStatus: row['conservationStatus'] as String?,
            funFacts: row['funFacts'] as String?,
            durationRaw: row['durationRaw'] as String,
            lightLevel: row['lightLevel'] as int?,
            atmosphericHumidity: row['atmosphericHumidity'] as int?,
            photoPath: row['photoPath'] as String,
            latitude: row['latitude'] as double?,
            longitude: row['longitude'] as double?,
            caughtAt: row['caughtAt'] as int));
  }

  @override
  Future<CaughtPlant?> getPlantById(int id) async {
    return _queryAdapter.query('SELECT * FROM caught_plants WHERE id = ?1',
        mapper: (Map<String, Object?> row) => CaughtPlant(
            id: row['id'] as int?,
            commonName: row['commonName'] as String,
            scientificName: row['scientificName'] as String,
            confidence: row['confidence'] as double,
            rarity: row['rarity'] as String,
            description: row['description'] as String,
            family: row['family'] as String,
            genus: row['genus'] as String,
            toxicity: row['toxicity'] as String,
            edible: (row['edible'] as int) != 0,
            thumbnailUrl: row['thumbnailUrl'] as String?,
            habitat: row['habitat'] as String?,
            careTips: row['careTips'] as String?,
            propagation: row['propagation'] as String?,
            floweringSeason: row['floweringSeason'] as String?,
            conservationStatus: row['conservationStatus'] as String?,
            funFacts: row['funFacts'] as String?,
            durationRaw: row['durationRaw'] as String,
            lightLevel: row['lightLevel'] as int?,
            atmosphericHumidity: row['atmosphericHumidity'] as int?,
            photoPath: row['photoPath'] as String,
            latitude: row['latitude'] as double?,
            longitude: row['longitude'] as double?,
            caughtAt: row['caughtAt'] as int),
        arguments: [id]);
  }

  @override
  Future<CaughtPlant?> getPlantByScientificName(String scientificName) async {
    return _queryAdapter.query(
        'SELECT * FROM caught_plants WHERE scientificName = ?1 LIMIT 1',
        mapper: (Map<String, Object?> row) => CaughtPlant(
            id: row['id'] as int?,
            commonName: row['commonName'] as String,
            scientificName: row['scientificName'] as String,
            confidence: row['confidence'] as double,
            rarity: row['rarity'] as String,
            description: row['description'] as String,
            family: row['family'] as String,
            genus: row['genus'] as String,
            toxicity: row['toxicity'] as String,
            edible: (row['edible'] as int) != 0,
            thumbnailUrl: row['thumbnailUrl'] as String?,
            habitat: row['habitat'] as String?,
            careTips: row['careTips'] as String?,
            propagation: row['propagation'] as String?,
            floweringSeason: row['floweringSeason'] as String?,
            conservationStatus: row['conservationStatus'] as String?,
            funFacts: row['funFacts'] as String?,
            durationRaw: row['durationRaw'] as String,
            lightLevel: row['lightLevel'] as int?,
            atmosphericHumidity: row['atmosphericHumidity'] as int?,
            photoPath: row['photoPath'] as String,
            latitude: row['latitude'] as double?,
            longitude: row['longitude'] as double?,
            caughtAt: row['caughtAt'] as int),
        arguments: [scientificName]);
  }

  @override
  Future<int?> countByScientificName(String scientificName) async {
    return _queryAdapter.query(
        'SELECT COUNT(*) FROM caught_plants WHERE scientificName = ?1',
        mapper: (Map<String, Object?> row) => row.values.first as int,
        arguments: [scientificName]);
  }

  @override
  Future<int?> getTotalCount() async {
    return _queryAdapter.query('SELECT COUNT(*) FROM caught_plants',
        mapper: (Map<String, Object?> row) => row.values.first as int);
  }

  @override
  Stream<List<CaughtPlant>> watchAllPlants() {
    return _queryAdapter.queryListStream(
        'SELECT * FROM caught_plants ORDER BY caughtAt DESC',
        mapper: (Map<String, Object?> row) => CaughtPlant(
            id: row['id'] as int?,
            commonName: row['commonName'] as String,
            scientificName: row['scientificName'] as String,
            confidence: row['confidence'] as double,
            rarity: row['rarity'] as String,
            description: row['description'] as String,
            family: row['family'] as String,
            genus: row['genus'] as String,
            toxicity: row['toxicity'] as String,
            edible: (row['edible'] as int) != 0,
            thumbnailUrl: row['thumbnailUrl'] as String?,
            habitat: row['habitat'] as String?,
            careTips: row['careTips'] as String?,
            propagation: row['propagation'] as String?,
            floweringSeason: row['floweringSeason'] as String?,
            conservationStatus: row['conservationStatus'] as String?,
            funFacts: row['funFacts'] as String?,
            durationRaw: row['durationRaw'] as String,
            lightLevel: row['lightLevel'] as int?,
            atmosphericHumidity: row['atmosphericHumidity'] as int?,
            photoPath: row['photoPath'] as String,
            latitude: row['latitude'] as double?,
            longitude: row['longitude'] as double?,
            caughtAt: row['caughtAt'] as int),
        queryableName: 'caught_plants',
        isView: false);
  }

  @override
  Stream<int?> watchTotalCount() {
    return _queryAdapter.queryStream('SELECT COUNT(*) FROM caught_plants',
        mapper: (Map<String, Object?> row) => row.values.first as int,
        queryableName: 'caught_plants',
        isView: false);
  }

  @override
  Future<void> deletePlantById(int id) async {
    await _queryAdapter.queryNoReturn('DELETE FROM caught_plants WHERE id = ?1',
        arguments: [id]);
  }

  @override
  Future<int> insertPlant(CaughtPlant plant) {
    return _caughtPlantInsertionAdapter.insertAndReturnId(
        plant, OnConflictStrategy.abort);
  }

  @override
  Future<void> deletePlant(CaughtPlant plant) async {
    await _caughtPlantDeletionAdapter.delete(plant);
  }
}
