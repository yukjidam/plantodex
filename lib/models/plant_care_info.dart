/// Plant reference info, sourced from the Wikipedia REST API.
///
/// All rich-text section fields are nullable — when Wikipedia has no
/// matching section they stay null and the UI hides that tile.
class PlantCareInfo {
  const PlantCareInfo({
    required this.wikiPageId,
    required this.family,
    required this.genus,
    required this.duration,
    required this.lightLevel,
    required this.atmosphericHumidity,
    required this.toxicity,
    required this.edible,
    required this.description,
    required this.thumbnailUrl,
    this.habitat,
    this.careTips,
    this.propagation,
    this.floweringSeason,
    this.conservationStatus,
    this.funFacts,
    this.isGenusLevel = false,
    this.genusName,
  });

  // ── Core fields ────────────────────────────────────────────────────

  final int? wikiPageId;
  final String family;
  final String genus;
  final List<String> duration;
  final int? lightLevel; // 0 (dark) .. 10 (full sun)
  final int? atmosphericHumidity; // 0 (dry)  .. 10 (very humid)
  final String toxicity; // "none"|"low"|"medium"|"high"|"unknown"
  final bool edible;
  final String description; // Wikipedia first-paragraph extract
  final String? thumbnailUrl;

  // ── Rich-text section fields ───────────────────────────────────────

  /// Native range, ecosystem, and ecological notes.
  final String? habitat;

  /// Cultivation guidance: soil, watering, light.
  final String? careTips;

  /// How the plant is reproduced.
  final String? propagation;

  /// Bloom period, fruiting season, or phenological notes.
  final String? floweringSeason;

  /// IUCN status or conservation notes.
  final String? conservationStatus;

  /// Interesting facts from uses/history/cultural sections.
  final String? funFacts;

  // ── Genus fallback ────────────────────────────────────────────────

  /// True when info came from the genus page, not the exact species page.
  final bool isGenusLevel;

  /// The genus name used for the fallback lookup, e.g. "Taraxacum".
  /// Null when [isGenusLevel] is false.
  final String? genusName;

  // ── Sentinel ───────────────────────────────────────────────────────

  static const empty = PlantCareInfo(
    wikiPageId: null,
    family: 'Unknown',
    genus: 'Unknown',
    duration: [],
    lightLevel: null,
    atmosphericHumidity: null,
    toxicity: 'unknown',
    edible: false,
    description: '',
    thumbnailUrl: null,
  );

  // ── Computed labels ────────────────────────────────────────────────

  String get lightLabel {
    if (lightLevel == null) return 'Unknown';
    if (lightLevel! <= 2) return 'Low light';
    if (lightLevel! <= 5) return 'Part shade';
    if (lightLevel! <= 8) return 'Bright light';
    return 'Full sun';
  }

  String get humidityLabel {
    if (atmosphericHumidity == null) return 'Unknown';
    if (atmosphericHumidity! <= 3) return 'Low humidity';
    if (atmosphericHumidity! <= 6) return 'Moderate humidity';
    return 'High humidity';
  }

  // ── Factory ────────────────────────────────────────────────────────

  /// [summaryJson]   — `/page/summary/{title}` response.
  /// [sectionTexts]  — map of { fieldKey → plain-text content } built
  ///                   by [WikipediaService._fetchMatchedSections].
  ///                   Keys: habitat, careTips, propagation,
  ///                         floweringSeason, conservationStatus, funFacts.
  /// [scientificName] — binomial from Pl@ntNet; genus is its first word.
  factory PlantCareInfo.fromWikipediaJson({
    required Map<String, dynamic> summaryJson,
    Map<String, String> sectionTexts = const {},
    String scientificName = '',
    bool isGenusLevel = false,
    String? genusName,
  }) {
    final rawExtract = summaryJson['extract'] as String? ?? '';
    final extract = rawExtract.toLowerCase();

    final thumbnail = summaryJson['thumbnail'] as Map<String, dynamic>?;
    final originalImage = summaryJson['originalimage'] as Map<String, dynamic>?;
    final thumbnailUrl =
        (originalImage?['source'] ?? thumbnail?['source']) as String?;

    final wikiPageId = summaryJson['pageid'] as int?;

    final genus = scientificName.isNotEmpty
        ? scientificName.trim().split(' ').first
        : 'Unknown';

    final description = rawExtract
        .replaceAll(RegExp(r'\s*\(listen\)\s*', caseSensitive: false), ' ')
        .trim();

    // Family: try infobox pattern in extract, else 'Unknown'.
    final family = _extractFamilyFromProse(extract) ?? 'Unknown';

    // Duration: best-effort keyword scan of extract.
    final duration = _inferDuration(extract);

    return PlantCareInfo(
      wikiPageId: wikiPageId,
      family: family,
      genus: genus,
      duration: duration,
      lightLevel: _inferLight(extract),
      atmosphericHumidity: _inferHumidity(extract),
      toxicity: _inferToxicity(extract),
      edible: _inferEdible(extract),
      description: description,
      thumbnailUrl: thumbnailUrl,
      // Section texts are already cleaned plain-text strings from the service.
      habitat: sectionTexts['habitat'],
      careTips: sectionTexts['careTips'],
      propagation: sectionTexts['propagation'],
      floweringSeason: sectionTexts['floweringSeason'],
      conservationStatus: sectionTexts['conservationStatus'],
      funFacts: sectionTexts['funFacts'],
      isGenusLevel: isGenusLevel,
      genusName: genusName,
    );
  }

  // ── Cache serialisation ────────────────────────────────────────────

  Map<String, dynamic> toCacheJson() => {
        'wikiPageId': wikiPageId,
        'family': family,
        'genus': genus,
        'duration': duration,
        'lightLevel': lightLevel,
        'atmosphericHumidity': atmosphericHumidity,
        'toxicity': toxicity,
        'edible': edible,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'habitat': habitat,
        'careTips': careTips,
        'propagation': propagation,
        'floweringSeason': floweringSeason,
        'conservationStatus': conservationStatus,
        'funFacts': funFacts,
        'isGenusLevel': isGenusLevel,
        'genusName': genusName,
      };

  factory PlantCareInfo.fromCacheJson(Map<String, dynamic> json) {
    return PlantCareInfo(
      wikiPageId: json['wikiPageId'] as int?,
      family: json['family'] as String? ?? 'Unknown',
      genus: json['genus'] as String? ?? 'Unknown',
      duration: (json['duration'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      lightLevel: json['lightLevel'] as int?,
      atmosphericHumidity: json['atmosphericHumidity'] as int?,
      toxicity: json['toxicity'] as String? ?? 'unknown',
      edible: json['edible'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      habitat: json['habitat'] as String?,
      careTips: json['careTips'] as String?,
      propagation: json['propagation'] as String?,
      floweringSeason: json['floweringSeason'] as String?,
      conservationStatus: json['conservationStatus'] as String?,
      funFacts: json['funFacts'] as String?,
      isGenusLevel: json['isGenusLevel'] as bool? ?? false,
      genusName: json['genusName'] as String?,
    );
  }

  // ── Private inference helpers ──────────────────────────────────────

  static List<String> _inferDuration(String extract) {
    final durations = <String>[];
    if (extract.contains('perennial')) durations.add('Perennial');
    if (extract.contains('annual')) durations.add('Annual');
    if (extract.contains('biennial')) durations.add('Biennial');
    if (extract.contains('evergreen')) durations.add('Evergreen');
    if (extract.contains('deciduous')) durations.add('Deciduous');
    return durations;
  }

  static int? _inferLight(String extract) {
    if (_anyMatch(extract, [
      'full sun',
      'direct sunlight',
      'thrives in sun',
      'sun-loving',
      'desert',
      'arid',
      'mediterranean climate',
    ])) return 9;
    if (_anyMatch(extract, [
      'bright indirect',
      'bright light',
      'partial sun',
      'light shade',
      'well-lit',
    ])) return 7;
    if (_anyMatch(extract, [
      'partial shade',
      'dappled light',
      'filtered light',
      'part shade',
      'semi-shade',
    ])) return 5;
    if (_anyMatch(extract, [
      'deep shade',
      'full shade',
      'low light',
      'shade-tolerant',
      'shady',
      'forest floor',
      'understory',
    ])) return 2;
    return null;
  }

  static int? _inferHumidity(String extract) {
    if (_anyMatch(extract, [
      'tropical',
      'rainforest',
      'high humidity',
      'humid environment',
      'moist air',
      'swamp',
      'wetland',
    ])) return 8;
    if (_anyMatch(extract, [
      'moderate humidity',
      'temperate',
      'woodland',
      'garden',
    ])) return 5;
    if (_anyMatch(extract, [
      'drought-tolerant',
      'dry climate',
      'arid',
      'desert',
      'succulent',
      'cactus',
      'xeric',
    ])) return 2;
    return null;
  }

  static String _inferToxicity(String extract) {
    if (_anyMatch(extract, [
      'highly toxic',
      'extremely poisonous',
      'deadly',
      'lethal',
      'fatal if ingested',
    ])) return 'high';
    if (_anyMatch(extract, [
      'toxic',
      'poisonous',
      'harmful if ingested',
      'skin irritant',
      'causes irritation',
    ])) return 'medium';
    if (_anyMatch(extract, [
      'mildly toxic',
      'slightly poisonous',
      'may cause discomfort',
    ])) return 'low';
    if (_anyMatch(extract, [
      'non-toxic',
      'safe for pets',
      'edible',
      'not poisonous',
    ])) return 'none';
    return 'unknown';
  }

  static bool _inferEdible(String extract) => _anyMatch(extract, [
        'edible',
        'eaten',
        'culinary',
        'food source',
        'consumed',
        'fruit is eaten',
        'leaves are eaten',
      ]);

  static bool _anyMatch(String text, List<String> keywords) =>
      keywords.any((kw) => text.contains(kw));

  static String? _extractFamilyFromProse(String extract) {
    final match = RegExp(
      r'(?:family|familia)\s*[:\-]?\s*([A-Z][a-z]+(?:eae|aceae|idae))',
      caseSensitive: false,
    ).firstMatch(extract);
    return match?.group(1);
  }
}
