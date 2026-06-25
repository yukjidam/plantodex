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

  /// Where this plant was caught. Left blank until the location feature
  /// is wired up — UI should render this even when empty.
  String get location => '';
}
