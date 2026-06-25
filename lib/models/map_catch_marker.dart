import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Display model for a single pin on the map.
///
/// Constructed from your existing CaughtPlant Floor entity.
/// Requires latitude + longitude columns on CaughtPlant (Phase 7 migration).
class MapCatchMarker {
  const MapCatchMarker({
    required this.plantId,
    required this.commonName,
    required this.scientificName,
    required this.location,
    required this.rarity,
    required this.caughtAt,
    this.imagePath,
  });

  final int plantId;
  final String commonName;
  final String scientificName;
  final LatLng location;
  final MarkerRarity rarity;
  final DateTime caughtAt;
  final String? imagePath; // local file path from CaughtPlant.imagePath

  String get caughtAtLabel {
    final d = caughtAt;
    return '${_month(d.month)} ${d.day}, ${d.year}';
  }

  static String _month(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m];
}

/// Mirror of your existing rarity tiers.
/// Keep colors in sync with your RarityBadge / Dex card theming.
enum MarkerRarity {
  common(label: 'Common', emoji: '🌿', color: Color(0xFF4CAF50)),
  epic(label: 'Epic', emoji: '🌸', color: Color(0xFFE91E8C)),
  rare(label: 'Rare', emoji: '💜', color: Color(0xFF9C27B0)),
  legendary(label: 'Legendary', emoji: '🔥', color: Color(0xFFFF6D00));

  const MarkerRarity({
    required this.label,
    required this.emoji,
    required this.color,
  });

  final String label;
  final String emoji;
  final Color color;

  bool get isHighRarity => this == rare || this == legendary;

  /// Parse the rarity string stored in your Floor DB.
  static MarkerRarity fromString(String value) =>
      MarkerRarity.values.firstWhere(
        (r) => r.label.toLowerCase() == value.toLowerCase(),
        orElse: () => MarkerRarity.common,
      );
}
