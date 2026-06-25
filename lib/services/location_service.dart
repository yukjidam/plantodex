import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Device GPS wrapper for the map feature.
///
/// Permissions required in android/app/src/main/AndroidManifest.xml:
///   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
///   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
///
/// iOS: add NSLocationWhenInUseUsageDescription to Info.plist.
class LocationService {
  /// Returns the device's current [LatLng], or null if:
  ///   - permission is denied / permanently denied
  ///   - GPS cannot get a fix within [timeout]
  ///
  /// Never throws — callers treat null as "location unavailable".
  Future<LatLng?> getCurrentLocation({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
