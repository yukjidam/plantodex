/// lib/models/plant_result.dart
///
/// The single result object that flows from DetectionProvider → DetectResultScreen.
/// PlantNetService populates [identification]; PerenualService populates [careInfo].
///

class PlantResult {
  const PlantResult({
    required this.identification,
    required this.careInfo,
  });

  final PlantIdentification identification;
  final PlantCareInfo careInfo;
}

// ── Identification (from PlantNet) ────────────────────────────────────────────

class PlantIdentification {
  const PlantIdentification({
    required this.commonName,
    required this.scientificName,
    required this.family,
    required this.confidence,
  });

  /// e.g. "Peace Lily"
  final String commonName;

  /// e.g. "Spathiphyllum wallisii"
  final String scientificName;

  /// e.g. "Araceae"
  final String family;

  /// 0.0 – 1.0 score returned by PlantNet
  final double confidence;

  /// Convenience: rounded percentage for display ("87%")
  int get confidencePercent => (confidence * 100).round();
}

// ── Care info (from Perenual) ─────────────────────────────────────────────────

class PlantCareInfo {
  const PlantCareInfo({
    required this.description,
    required this.watering,
    required this.sunlight,
    required this.cycle,
    required this.indoor,
    required this.poisonousToHumans,
    required this.poisonousToPets,
  });

  /// Long-form description shown in the detail card.
  final String description;

  /// e.g. "Frequent", "Average", "Minimum"
  final String watering;

  /// e.g. ["full_sun", "part_shade"] — displayed as chips after replacing '_' → ' '
  final List<String> sunlight;

  /// e.g. "Perennial", "Annual"
  final String cycle;

  /// Whether the plant can be kept indoors.
  final bool indoor;

  /// Triggers the ⚠️ banner in the UI.
  final bool poisonousToHumans;

  /// Triggers the "Toxic to pets" tag chip.
  final bool poisonousToPets;

  /// A sensible empty state so the UI never crashes on a cache miss.
  static const PlantCareInfo empty = PlantCareInfo(
    description: '',
    watering: 'Unknown',
    sunlight: [],
    cycle: 'Unknown',
    indoor: false,
    poisonousToHumans: false,
    poisonousToPets: false,
  );
}
