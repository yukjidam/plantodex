import '../models/caught_plant.dart';
import '../models/map_catch_marker.dart';
import '../repositories/plant_repository.dart';
import 'package:latlong2/latlong.dart';

/// Surfaces caught plants as map markers by adapting the [PlantRepository]
/// stream — no need to inject the DAO directly.
class MapRepository {
  MapRepository({PlantRepository? repository})
      : _repo = repository ?? PlantRepository.instance;

  final PlantRepository _repo;

  /// Stream of all caught plants that have a recorded location.
  /// Emits a new list whenever the Floor DB changes.
  /// Plants without lat/lng (caught before Phase 7) are silently skipped.
  Stream<List<MapCatchMarker>> watchAll() {
    return _repo.watchAllCatches().map((plants) => plants
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) => MapCatchMarker(
              plantId: p.id!,
              commonName: p.commonName,
              scientificName: p.scientificName,
              location: LatLng(p.latitude!, p.longitude!),
              rarity: MarkerRarity.fromString(p.rarity),
              caughtAt: p.caughtAtDate,
              imagePath: p.photoPath,
            ))
        .toList());
  }
}
