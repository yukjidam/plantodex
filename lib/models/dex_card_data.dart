import '../theme/rarity.dart';
import 'caught_plant.dart';
import 'plant_rarity_lookup.dart';

/// What a single Dex grid card displays — either a real catch, or a
/// locked rare/legendary target the user hasn't found yet.
///
/// This lets [DexRepository] hand the screen one uniform list per
/// section without the widget needing to branch on two unrelated types.
class DexCardData {
  const DexCardData.caught(CaughtPlant plant)
      : caught = plant,
        lockedTarget = null;

  const DexCardData.locked(TargetSpecies target)
      : caught = null,
        lockedTarget = target;

  final CaughtPlant? caught;
  final TargetSpecies? lockedTarget;

  bool get isLocked => caught == null;

  Rarity get rarity =>
      isLocked ? lockedTarget!.rarity : parseRarity(caught!.rarity);

  String get commonName =>
      isLocked ? lockedTarget!.commonName : caught!.commonName;

  /// Hidden for locked cards — the whole point is the user hasn't seen it.
  String? get scientificName => isLocked ? null : caught!.scientificName;

  String? get photoPath => isLocked ? null : caught!.photoPath;
}
