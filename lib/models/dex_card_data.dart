import '../theme/rarity.dart';
import 'caught_plant.dart';
import 'plant_rarity_lookup.dart';

/// What a single Dex grid card displays — always a real catch now that
/// locked/undiscovered cards have been removed.
class DexCardData {
  const DexCardData.caught(CaughtPlant plant) : caught = plant;

  final CaughtPlant caught;

  Rarity get rarity => parseRarity(caught.rarity);

  String get commonName => caught.commonName;

  String get scientificName => caught.scientificName;

  String? get photoPath => caught.photoPath;

  /// When this plant was caught.
  DateTime get caughtAt => caught.caughtAtDate;

  /// Where this plant was caught, formatted as "lat, lng" to 4 decimal
  /// places. Empty when no GPS was recorded (permission denied or no fix).
  String get location {
    final lat = caught.latitude;
    final lng = caught.longitude;
    if (lat == null || lng == null) return '';
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// Identification confidence, 0-100.
  int get confidencePercent => caught.confidencePercent;

  /// Taxonomic family, used for search filtering.
  String get family => caught.family;

  /// XP reward for this catch. Placeholder values until the profile/XP
  /// module is implemented — safe to swap out later without touching
  /// callers.
  int get xpReward => switch (rarity) {
        Rarity.common => 40,
        Rarity.rare => 120,
        Rarity.epic => 200,
        Rarity.legendary => 350,
      };
}
