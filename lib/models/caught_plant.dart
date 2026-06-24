import 'package:floor/floor.dart';

/// A plant the user has successfully caught and saved.
/// [photoPath] is an absolute path to a copy of the scanned image stored
/// in the app's documents directory — we never store raw bytes in SQLite.
@Entity(tableName: 'caught_plants')
class CaughtPlant {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  // ── Identification ─────────────────────────────────────────────────
  final String commonName;
  final String scientificName;
  final double confidence; // 0.0–1.0
  final String rarity; // "common" | "rare"

  // ── Wikipedia / care info ──────────────────────────────────────────
  final String description;
  final String family;
  final String genus;
  final String toxicity;
  final bool edible;
  final String? thumbnailUrl;
  final String? habitat;
  final String? careTips;
  final String? propagation;
  final String? floweringSeason;
  final String? conservationStatus;
  final String? funFacts;

  // Stored as comma-separated values  e.g. "Perennial,Evergreen"
  final String durationRaw;

  final int? lightLevel;
  final int? atmosphericHumidity;

  // ── Photo ──────────────────────────────────────────────────────────
  /// Absolute path to the saved copy of the scanned photo.
  final String photoPath;

  // ── Meta ───────────────────────────────────────────────────────────
  /// Unix milliseconds since epoch.
  final int caughtAt;

  const CaughtPlant({
    this.id,
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    required this.rarity,
    required this.description,
    required this.family,
    required this.genus,
    required this.toxicity,
    required this.edible,
    this.thumbnailUrl,
    this.habitat,
    this.careTips,
    this.propagation,
    this.floweringSeason,
    this.conservationStatus,
    this.funFacts,
    required this.durationRaw,
    this.lightLevel,
    this.atmosphericHumidity,
    required this.photoPath,
    required this.caughtAt,
  });

  // ── Helpers ────────────────────────────────────────────────────────

  List<String> get duration =>
      durationRaw.isEmpty ? [] : durationRaw.split(',');

  int get confidencePercent => (confidence * 100).round();

  DateTime get caughtAtDate => DateTime.fromMillisecondsSinceEpoch(caughtAt);
}
