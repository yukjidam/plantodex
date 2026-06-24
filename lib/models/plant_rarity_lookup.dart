import '../theme/rarity.dart';

import '../theme/rarity.dart';

/// A species in the fixed rare/legendary target list — shown as a
/// locked "undiscovered" card until the user actually catches it.
class TargetSpecies {
  const TargetSpecies({
    required this.scientificName,
    required this.commonName,
    required this.rarity,
  });
  final String scientificName;
  final String commonName;
  final Rarity rarity;
}

/// Critically rare, highly localized, or iconic Philippine endemics —
/// species most users will never encounter in the wild. Shown as locked
/// "Legendary" cards in the Dex until caught.
const legendaryTargets = <TargetSpecies>[
  TargetSpecies(
      scientificName: 'Rafflesia magnifica',
      commonName: 'Rafflesia Magnifica',
      rarity: Rarity.legendary),
  TargetSpecies(
      scientificName: 'Rafflesia manillana',
      commonName: 'Rafflesia Manillana',
      rarity: Rarity.legendary),
  TargetSpecies(
      scientificName: 'Rafflesia philippensis',
      commonName: 'Rafflesia Philippensis',
      rarity: Rarity.legendary),
  TargetSpecies(
      scientificName: 'Euanthe sanderiana',
      commonName: 'Waling-waling',
      rarity: Rarity.legendary),
  TargetSpecies(
      scientificName: 'Nepenthes sibuyanensis',
      commonName: 'Sibuyan Pitcher Plant',
      rarity: Rarity.legendary),
  TargetSpecies(
      scientificName: 'Nepenthes peltata',
      commonName: 'Hamiguitan Pitcher Plant',
      rarity: Rarity.legendary),
  TargetSpecies(
      scientificName: 'Cynometra cebuensis',
      commonName: 'Nipot-nipot',
      rarity: Rarity.legendary),
  TargetSpecies(
      scientificName: 'Paphiopedilum adductum',
      commonName: "Adductum's Slipper Orchid",
      rarity: Rarity.legendary),
];

/// Notable Philippine endemics that are uncommon but more findable than
/// the legendary tier. Shown as locked "Rare" cards in the Dex until
/// caught.
const rareTargets = <TargetSpecies>[
  TargetSpecies(
      scientificName: 'Strongylodon macrobotrys',
      commonName: 'Jade Vine',
      rarity: Rarity.rare),
  TargetSpecies(
      scientificName: 'Cinnamomum cebuense',
      commonName: 'Cebu Cinnamon',
      rarity: Rarity.rare),
  TargetSpecies(
      scientificName: 'Tectona philippinensis',
      commonName: 'Philippine Teak',
      rarity: Rarity.rare),
  TargetSpecies(
      scientificName: 'Nepenthes ventricosa',
      commonName: 'Kako Pitcher Plant',
      rarity: Rarity.rare),
  TargetSpecies(
      scientificName: 'Phalaenopsis lindenii',
      commonName: "Linden's Orchid",
      rarity: Rarity.rare),
  TargetSpecies(
      scientificName: 'Phalaenopsis hieroglyphica',
      commonName: 'Hieroglyphic Orchid',
      rarity: Rarity.rare),
  TargetSpecies(
      scientificName: 'Lilium philippinense',
      commonName: 'Philippine Lily',
      rarity: Rarity.rare),
  TargetSpecies(
      scientificName: 'Areca ipot',
      commonName: 'Bungang-ipot',
      rarity: Rarity.rare),
  TargetSpecies(
      scientificName: 'Kibatalia puberula',
      commonName: 'Kibatalia',
      rarity: Rarity.rare),
];

/// Scientific names only, derived from the target lists above — used for
/// fast rarity lookup at catch time.
final legendaryScientificNames =
    legendaryTargets.map((t) => t.scientificName).toSet();

final rareScientificNames = rareTargets.map((t) => t.scientificName).toSet();

/// Parses a stored `CaughtPlant.rarity` string (e.g. `'legendary'`) back
/// into the [Rarity] enum for display. Falls back to [Rarity.common] if
/// the stored value doesn't match any known rarity.
Rarity parseRarity(String stored) {
  return Rarity.values.firstWhere(
    (r) => r.name == stored.toLowerCase(),
    orElse: () => Rarity.common,
  );
}

/// Looks up the rarity for a scientific name caught by the user.
///
/// Call this when building a [CaughtPlant] right before inserting it,
/// e.g.:
/// ```dart
/// final plant = CaughtPlant(
///   ...,
///   rarity: rarityFor(scientificName).name, // store as string
/// );
/// await dao.insertPlant(plant);
/// ```
///
/// Matching is case-insensitive and ignores leading/trailing whitespace,
/// since identification results may vary in casing.
Rarity rarityFor(String scientificName) {
  final normalized = scientificName.trim().toLowerCase();

  if (legendaryScientificNames.any((s) => s.toLowerCase() == normalized)) {
    return Rarity.legendary;
  }
  if (rareScientificNames.any((s) => s.toLowerCase() == normalized)) {
    return Rarity.rare;
  }
  return Rarity.common;
}
