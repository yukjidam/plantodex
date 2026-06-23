/// Result of a Pl@ntNet species identification call.
class PlantIdentification {
  const PlantIdentification({
    required this.scientificName,
    required this.commonName,
    required this.family,
    required this.confidence, // 0.0 - 1.0
    required this.imageUrls,
  });

  final String scientificName;
  final String commonName;
  final String family;
  final double confidence;
  final List<String> imageUrls;

  int get confidencePercent => (confidence * 100).round();

  factory PlantIdentification.fromPlantNetJson(Map<String, dynamic> json) {
    final results = json['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) {
      throw const PlantIdNoMatchException();
    }
    final best = results.first as Map<String, dynamic>;
    final species = best['species'] as Map<String, dynamic>? ?? {};
    final commonNames = (species['commonNames'] as List<dynamic>? ?? []);
    final images = (best['images'] as List<dynamic>? ?? [])
        .map((img) => (img as Map<String, dynamic>)['url']?['o'] as String?)
        .whereType<String>()
        .toList();

    return PlantIdentification(
      scientificName: species['scientificNameWithoutAuthor'] as String? ??
          species['scientificName'] as String? ??
          'Unknown species',
      commonName: commonNames.isNotEmpty
          ? commonNames.first as String
          : (species['scientificNameWithoutAuthor'] as String? ?? 'Unknown'),
      family: (species['family']
                  as Map<String, dynamic>?)?['scientificNameWithoutAuthor']
              as String? ??
          'Unknown family',
      confidence: (best['score'] as num?)?.toDouble() ?? 0.0,
      imageUrls: images,
    );
  }
}

/// Thrown when Pl@ntNet returns zero candidate matches.
class PlantIdNoMatchException implements Exception {
  const PlantIdNoMatchException();
  @override
  String toString() => 'No matching species found.';
}
