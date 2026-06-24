import '../theme/rarity.dart';

/// Parses a stored [CaughtPlant.rarity] string back into the [Rarity] enum.
/// Falls back to [Rarity.common] if unrecognised.
Rarity parseRarity(String stored) {
  return Rarity.values.firstWhere(
    (r) => r.name == stored.toLowerCase(),
    orElse: () => Rarity.common,
  );
}
