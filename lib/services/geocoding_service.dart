import 'package:geocoding/geocoding.dart';

/// Reverse-geocodes lat/lng to a human-readable place name.
///
/// Results are cached in memory so repeated calls for the same coordinates
/// (e.g. scrolling the Dex grid) never hit the platform geocoder twice.
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  final _cache = <String, String>{};

  /// Returns a place name like "Poblacion, Tarlac City" or null if the
  /// coordinates can't be resolved (no network, no fix, etc.).
  /// Never throws.
  Future<String?> getPlaceName(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;

      final p = placemarks.first;
      final parts = [
        if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
        if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
          p.administrativeArea!,
      ];

      if (parts.isEmpty) return null;
      final name = parts.take(2).join(', ');
      _cache[key] = name;
      return name;
    } catch (_) {
      return null;
    }
  }
}
