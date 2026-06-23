/// Care / reference info for a species, sourced from Perenual
/// (falls back to defaults if a field isn't available).
class PlantCareInfo {
  const PlantCareInfo({
    required this.perenualId,
    required this.watering,
    required this.sunlight,
    required this.cycle,
    required this.indoor,
    required this.poisonousToHumans,
    required this.poisonousToPets,
    required this.description,
    required this.thumbnailUrl,
  });

  final int? perenualId;
  final String watering; // e.g. "Average", "Frequent", "Minimum"
  final List<String> sunlight; // e.g. ["full_sun", "part_shade"]
  final String cycle; // e.g. "Perennial", "Annual"
  final bool indoor;
  final bool poisonousToHumans;
  final bool poisonousToPets;
  final String description;
  final String? thumbnailUrl;

  static const empty = PlantCareInfo(
    perenualId: null,
    watering: 'Unknown',
    sunlight: [],
    cycle: 'Unknown',
    indoor: false,
    poisonousToHumans: false,
    poisonousToPets: false,
    description: '',
    thumbnailUrl: null,
  );

  factory PlantCareInfo.fromPerenualDetailJson(Map<String, dynamic> json) {
    return PlantCareInfo(
      perenualId: json['id'] as int?,
      watering: json['watering'] as String? ?? 'Unknown',
      sunlight: (json['sunlight'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      cycle: json['cycle'] as String? ?? 'Unknown',
      indoor: json['indoor'] as bool? ?? false,
      poisonousToHumans: _truthy(json['poisonous_to_humans']),
      poisonousToPets: _truthy(json['poisonous_to_pets']),
      description: json['description'] as String? ?? '',
      thumbnailUrl: (json['default_image']
          as Map<String, dynamic>?)?['medium_url'] as String?,
    );
  }

  static bool _truthy(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return false;
  }

  Map<String, dynamic> toCacheJson() => {
        'perenualId': perenualId,
        'watering': watering,
        'sunlight': sunlight,
        'cycle': cycle,
        'indoor': indoor,
        'poisonousToHumans': poisonousToHumans,
        'poisonousToPets': poisonousToPets,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
      };

  factory PlantCareInfo.fromCacheJson(Map<String, dynamic> json) {
    return PlantCareInfo(
      perenualId: json['perenualId'] as int?,
      watering: json['watering'] as String? ?? 'Unknown',
      sunlight: (json['sunlight'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      cycle: json['cycle'] as String? ?? 'Unknown',
      indoor: json['indoor'] as bool? ?? false,
      poisonousToHumans: json['poisonousToHumans'] as bool? ?? false,
      poisonousToPets: json['poisonousToPets'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}
