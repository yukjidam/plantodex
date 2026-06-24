import 'package:floor/floor.dart';
import '../models/caught_plant.dart';

@dao
abstract class CaughtPlantDao {
  // ── Insert ─────────────────────────────────────────────────────────

  @insert
  Future<int> insertPlant(CaughtPlant plant);

  // ── Queries ────────────────────────────────────────────────────────

  @Query('SELECT * FROM caught_plants ORDER BY caughtAt DESC')
  Future<List<CaughtPlant>> getAllPlants();

  @Query('SELECT * FROM caught_plants WHERE id = :id')
  Future<CaughtPlant?> getPlantById(int id);

  @Query(
      'SELECT * FROM caught_plants WHERE scientificName = :scientificName LIMIT 1')
  Future<CaughtPlant?> getPlantByScientificName(String scientificName);

  /// Returns true if this species has already been caught.
  @Query(
      'SELECT COUNT(*) FROM caught_plants WHERE scientificName = :scientificName')
  Future<int?> countByScientificName(String scientificName);

  @Query('SELECT COUNT(*) FROM caught_plants')
  Future<int?> getTotalCount();

  // ── Streams (for reactive UI) ──────────────────────────────────────

  @Query('SELECT * FROM caught_plants ORDER BY caughtAt DESC')
  Stream<List<CaughtPlant>> watchAllPlants();

  @Query('SELECT COUNT(*) FROM caught_plants')
  Stream<int?> watchTotalCount();

  // ── Delete ─────────────────────────────────────────────────────────

  @delete
  Future<void> deletePlant(CaughtPlant plant);

  @Query('DELETE FROM caught_plants WHERE id = :id')
  Future<void> deletePlantById(int id);
}
