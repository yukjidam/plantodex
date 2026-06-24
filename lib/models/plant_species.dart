import 'package:flutter/material.dart';
import '../theme/rarity.dart';

/// A catchable species in the Dex — static reference data describing
/// every plant the user *could* catch, independent of whether they have.
///
/// This is the master list. Whether a given species has been caught is
/// determined separately by matching [scientificName] against rows in
/// the `caught_plants` table (see [DexEntry] / [DexRepository]).
class PlantSpecies {
  const PlantSpecies({
    required this.scientificName,
    required this.commonName,
    required this.rarity,
    required this.gradient,
  });

  /// Stable identifier for matching against [CaughtPlant.scientificName].
  final String scientificName;
  final String commonName;
  final Rarity rarity;

  /// Used for the locked/placeholder card art before a real photo exists.
  final List<Color> gradient;
}

/// The full catalog of catchable species.
///
/// NOTE: this is a starter seed list. Extend freely — nothing else in the
/// Dex screen needs to change when you add entries here.
const allSpecies = <PlantSpecies>[
  // ── Legendary ────────────────────────────────────────────────────────
  PlantSpecies(
    scientificName: 'Rafflesia arnoldii',
    commonName: 'Rafflesia',
    rarity: Rarity.legendary,
    gradient: [Color(0xFF2A0A00), Color(0xFF8B2500)],
  ),
  PlantSpecies(
    scientificName: 'Amorphophallus titanum',
    commonName: 'Corpse Flower',
    rarity: Rarity.legendary,
    gradient: [Color(0xFF1A0A00), Color(0xFF5A2A00)],
  ),

  // ── Epic ─────────────────────────────────────────────────────────────
  PlantSpecies(
    scientificName: 'Nelumbo nucifera',
    commonName: 'Sacred Lotus',
    rarity: Rarity.epic,
    gradient: [Color(0xFF1F0A14), Color(0xFF6E1A3D)],
  ),
  PlantSpecies(
    scientificName: 'Wolffia globosa',
    commonName: 'Watermeal',
    rarity: Rarity.epic,
    gradient: [Color(0xFF0A1F14), Color(0xFF1A6E4D)],
  ),

  // ── Rare ─────────────────────────────────────────────────────────────
  PlantSpecies(
    scientificName: 'Vanda coerulea',
    commonName: 'Blue Vanda Orchid',
    rarity: Rarity.rare,
    gradient: [Color(0xFF1A0A28), Color(0xFF3D1A6E)],
  ),
  PlantSpecies(
    scientificName: 'Dionaea muscipula',
    commonName: 'Venus Flytrap',
    rarity: Rarity.rare,
    gradient: [Color(0xFF0A1F0F), Color(0xFF1A6E33)],
  ),
  PlantSpecies(
    scientificName: 'Welwitschia mirabilis',
    commonName: 'Welwitschia',
    rarity: Rarity.rare,
    gradient: [Color(0xFF1F1A0A), Color(0xFF6E5A1A)],
  ),

  // ── Common ───────────────────────────────────────────────────────────
  PlantSpecies(
    scientificName: 'Nephrolepis exaltata',
    commonName: 'Boston Fern',
    rarity: Rarity.common,
    gradient: [Color(0xFF1A3010), Color(0xFF2D5A1B)],
  ),
  PlantSpecies(
    scientificName: 'Dracaena sanderiana',
    commonName: 'Lucky Bamboo',
    rarity: Rarity.common,
    gradient: [Color(0xFF0F1F08), Color(0xFF3D7A24)],
  ),
  PlantSpecies(
    scientificName: 'Epipremnum aureum',
    commonName: 'Golden Pothos',
    rarity: Rarity.common,
    gradient: [Color(0xFF0D2010), Color(0xFF2A5520)],
  ),
  PlantSpecies(
    scientificName: 'Chlorophytum comosum',
    commonName: 'Spider Plant',
    rarity: Rarity.common,
    gradient: [Color(0xFF142010), Color(0xFF3D6E2A)],
  ),
  PlantSpecies(
    scientificName: 'Sansevieria trifasciata',
    commonName: "Snake Plant",
    rarity: Rarity.common,
    gradient: [Color(0xFF0A1F1A), Color(0xFF1A5A4D)],
  ),
  PlantSpecies(
    scientificName: 'Zamioculcas zamiifolia',
    commonName: 'ZZ Plant',
    rarity: Rarity.common,
    gradient: [Color(0xFF101F0A), Color(0xFF2D5A1A)],
  ),
  // … add the rest of your ~100 species here.
];
