import 'package:flutter/material.dart';
import '../theme/rarity.dart';
import 'caught_plant.dart';
import 'plant_species.dart';

/// A single Dex grid cell's worth of data: a species from the master
/// catalog, joined with the user's caught row for that species (if any).
///
/// This is what [DexScreen] actually renders — it never touches
/// [PlantSpecies] or [CaughtPlant] directly.
class DexEntry {
  const DexEntry({required this.species, required this.caught});

  final PlantSpecies species;

  /// Null if the user hasn't caught this species yet.
  final CaughtPlant? caught;

  bool get isLocked => caught == null;

  String get displayName => isLocked ? '???' : species.commonName;

  String get displayScientific =>
      isLocked ? 'Not yet found' : species.scientificName;

  Rarity get rarity => species.rarity;

  List<Color> get gradient => species.gradient;

  /// Caught timestamp, for sorting "Recent catches". Null when locked.
  int? get caughtAt => caught?.caughtAt;
}
