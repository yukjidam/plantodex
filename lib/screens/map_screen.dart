import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../theme/colors.dart';
import '../models/caught_plant.dart';
import '../models/map_catch_marker.dart';
import '../repositories/plant_repository.dart';
import '../services/geocoding_service.dart';
import '../services/map_repository.dart';
import '../services/location_service.dart';
import '../widgets/catch_marker_widget.dart';
import '../widgets/map_legend_widget.dart';

/// Phase 7 — Map Screen (live)
///
/// Markers stream from [MapRepository] → Floor DB → live updates.
/// Initial center + recenter come from [LocationService] (GPS).
/// Falls back gracefully when GPS is unavailable.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final _mapRepo = MapRepository();
  final _locationService = LocationService();

  // Fallback center (Tarlac City) used when GPS is unavailable.
  static const LatLng _fallbackCenter = LatLng(15.4817, 120.5979);

  LatLng _initialCenter = _fallbackCenter;
  bool _gpsAvailable = false;
  LatLng? _userLocation; // live dot on the map

  List<MapCatchMarker> _markers = [];
  bool _markersLoaded = false; // true after first DB emission
  StreamSubscription<List<MapCatchMarker>>? _markerSub;

  MapCatchMarker? _selectedMarker;
  String? _selectedPlaceName;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _subscribeMarkers();
  }

  /// Asks GPS for the current position and updates the initial center.
  /// Silently falls back to [_fallbackCenter] if unavailable.
  Future<void> _initLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (pos != null && mounted) {
      setState(() {
        _initialCenter = pos;
        _userLocation = pos;
        _gpsAvailable = true;
      });
    }
  }

  /// Subscribes to the live Floor stream via [MapRepository].
  void _subscribeMarkers() {
    _markerSub = _mapRepo.watchAll().listen((markers) {
      if (!mounted) return;
      setState(() {
        _markers = markers;
        if (!_markersLoaded) {
          _markersLoaded = true;
          // Center on the cluster of pins if any exist, otherwise fall back
          // to GPS / fallback center. Delay slightly so FlutterMap is ready.
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _mapReady = true);
            if (markers.isNotEmpty) {
              final center = _clusterCenter(markers);
              Future.delayed(const Duration(milliseconds: 350), () {
                if (mounted) _mapController.move(center, 14.5);
              });
            }
          });
        }
      });
    });

    // Safety fallback: if DB takes too long (e.g. empty collection),
    // show the map after 2s anyway so the screen isn't stuck loading.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_markersLoaded) {
        setState(() {
          _markersLoaded = true;
          _mapReady = true;
        });
      }
    });
  }

  /// Returns the geographic centroid of all marker locations.
  LatLng _clusterCenter(List<MapCatchMarker> markers) {
    final lat =
        markers.map((m) => m.location.latitude).reduce((a, b) => a + b) /
            markers.length;
    final lng =
        markers.map((m) => m.location.longitude).reduce((a, b) => a + b) /
            markers.length;
    return LatLng(lat, lng);
  }

  Future<CaughtPlant?> _fetchPlant(int plantId) async {
    return PlantRepository.instance.getCatchById(plantId);
  }

  @override
  void dispose() {
    _markerSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: surface,
      body: Column(
        children: [
          _buildHeader(topPad),
          Expanded(
            child: Stack(
              children: [
                if (_mapReady) _buildMap(),
                if (_mapReady && _selectedMarker != null)
                  _buildInfoCard(_selectedMarker!),
                // #3 — empty state when map is ready but no pins exist
                if (_mapReady && _markers.isEmpty) _buildEmptyState(),
                const Positioned(
                  bottom: 24,
                  left: 16,
                  child: MapLegendWidget(),
                ),
                _buildRecenterFab(),
                _buildLoadingOverlay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(double topPad) {
    final caught = _markers.length;
    final legendary =
        _markers.where((m) => m.rarity == MarkerRarity.legendary).length;
    final rarePlus = _markers
        .where((m) =>
            m.rarity == MarkerRarity.rare ||
            m.rarity == MarkerRarity.epic ||
            m.rarity == MarkerRarity.legendary)
        .length;

    return Container(
      color: surface,
      padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plant Map',
                    style: GoogleFonts.spaceMono(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Where your catches were found',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              // Live indicator dot
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: green100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: green600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Live',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: green600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stat pills — same pattern as Dex screen
          Row(
            children: [
              _StatPill('$caught', 'Pinned'),
              const SizedBox(width: 8),
              _StatPill('$rarePlus', 'Rare+'),
              const SizedBox(width: 8),
              _StatPill('$legendary', 'Legendary'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    final spread = _spreadMarkers(_markers);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: 14.5,
        minZoom: 4.0, // #2 — allow zooming out to see catches across regions
        maxZoom: 18.0,
        onTap: (_, __) => setState(() {
          _selectedMarker = null;
          _selectedPlaceName = null;
        }),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.plantodex',
          maxNativeZoom: 19,
        ),
        MarkerLayer(
          markers: spread.map((e) => _toMarker(e.$1, e.$2)).toList(),
        ),
        // #4 — live user location dot
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Groups markers that are within [_stackThreshold] degrees of each other
  /// and arranges each group in a small circle so every pin is visible and
  /// tappable without zooming in.
  ///
  /// Markers that aren't near anything else are returned unchanged.
  static const double _stackThreshold = 0.0002; // ~22m at equator
  static const double _spreadRadius = 0.0003; // ~33m — tight but readable

  List<(MapCatchMarker, LatLng)> _spreadMarkers(List<MapCatchMarker> markers) {
    // Build a list of (marker, displayPoint) pairs.
    final result = <(MapCatchMarker, LatLng)>[];
    final assigned = <int>{}; // indices already placed in a group

    for (int i = 0; i < markers.length; i++) {
      if (assigned.contains(i)) continue;

      // Find all markers within threshold of markers[i]
      final group = <int>[i];
      for (int j = i + 1; j < markers.length; j++) {
        if (assigned.contains(j)) continue;
        final dlat =
            (markers[i].location.latitude - markers[j].location.latitude).abs();
        final dlng =
            (markers[i].location.longitude - markers[j].location.longitude)
                .abs();
        if (dlat < _stackThreshold && dlng < _stackThreshold) {
          group.add(j);
        }
      }

      if (group.length == 1) {
        // Solo pin — no offset needed
        result.add((markers[i], markers[i].location));
      } else {
        // Spread group in a circle around the centroid
        final clat = group
                .map((k) => markers[k].location.latitude)
                .reduce((a, b) => a + b) /
            group.length;
        final clng = group
                .map((k) => markers[k].location.longitude)
                .reduce((a, b) => a + b) /
            group.length;

        for (int g = 0; g < group.length; g++) {
          final angle = (2 * pi / group.length) * g - pi / 2;
          final offsetLat = clat + _spreadRadius * cos(angle);
          final offsetLng = clng + _spreadRadius * sin(angle);
          result.add((markers[group[g]], LatLng(offsetLat, offsetLng)));
        }
        assigned.addAll(group);
      }
    }

    return result;
  }

  Marker _toMarker(MapCatchMarker catch_, LatLng displayPoint) {
    final selected = _selectedMarker?.plantId == catch_.plantId;
    return Marker(
      point: displayPoint,
      width: 48,
      height: 54,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMarker = catch_;
            _selectedPlaceName = null;
          });
          _mapController.move(displayPoint, 16.0);
          GeocodingService.instance
              .getPlaceName(catch_.location.latitude, catch_.location.longitude)
              .then((name) {
            if (mounted && _selectedMarker?.plantId == catch_.plantId) {
              setState(() => _selectedPlaceName = name);
            }
          });
        },
        child: CatchMarkerWidget(marker: catch_, isSelected: selected),
      ),
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────────

  Widget _buildInfoCard(MapCatchMarker marker) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Dark card to match the map vibe
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: marker.rarity.color.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: marker.rarity.color.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Plant image — shows marker.imageUrl if available, falls
                  // back to a rarity-tinted emoji tile (pre-wiring placeholder).
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: marker.rarity.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: marker.rarity.color.withOpacity(0.45),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: marker.imagePath != null
                          ? Image.file(
                              File(marker.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _rarityEmojiFallback(marker),
                            )
                          : _rarityEmojiFallback(marker),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          marker.commonName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          marker.scientificName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Rarity pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: marker.rarity.color.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${marker.rarity.emoji} ${marker.rarity.label}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: marker.rarity.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Close & detail arrow
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedMarker = null;
                          _selectedPlaceName = null;
                        }),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: textMuted),
                      ),
                      const SizedBox(height: 10),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final plant = await _fetchPlant(marker.plantId);
                          if (plant != null && context.mounted) {
                            context.push('/dex/detail', extra: plant);
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 1, color: borderColor),
              const SizedBox(height: 10),

              // ── Stats row: date caught + coordinates ─────────────────────
              Row(
                children: [
                  _InfoStat(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date caught',
                    value: marker.caughtAtLabel,
                  ),
                  const SizedBox(width: 12),
                  _InfoStat(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    value: _selectedPlaceName ??
                        '${marker.location.latitude.toStringAsFixed(4)}, '
                            '${marker.location.longitude.toStringAsFixed(4)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Info-card helpers ─────────────────────────────────────────────────────

  /// Fallback shown inside the image box when marker.imageUrl is null or
  /// fails to load — keeps the card looking intentional, not broken.
  Widget _rarityEmojiFallback(MapCatchMarker marker) {
    return Container(
      color: marker.rarity.color.withOpacity(0.12),
      child: Center(
        child: Text(marker.rarity.emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      'No plants on the map yet',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scan a plant to drop your first pin',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Re-center FAB ─────────────────────────────────────────────────────────

  Widget _buildRecenterFab() {
    // #5 — recenter on pins if any exist, otherwise fall back to user GPS
    final hasPins = _markers.isNotEmpty;
    final canRecenter = hasPins || _gpsAvailable;
    return Positioned(
      bottom: 24,
      right: 16,
      child: Tooltip(
        message: hasPins
            ? 'Re-center on catches'
            : _gpsAvailable
                ? 'Re-center on my location'
                : 'GPS unavailable',
        child: FloatingActionButton.small(
          heroTag: 'map_recenter',
          backgroundColor: canRecenter ? surface : surface2,
          foregroundColor: canRecenter ? green200 : textMuted,
          elevation: 6,
          onPressed: canRecenter ? _recenter : null,
          child: Icon(
            canRecenter
                ? Icons.my_location_rounded
                : Icons.location_disabled_rounded,
          ),
        ),
      ),
    );
  }

  // #5 — recenter prefers pin cluster; falls back to live GPS
  Future<void> _recenter() async {
    if (_markers.isNotEmpty) {
      final center = _clusterCenter(_markers);
      _mapController.move(center, 14.5);
      return;
    }
    final pos = await _locationService.getCurrentLocation();
    if (pos != null && mounted) {
      setState(() => _userLocation = pos);
      _mapController.move(pos, 14.5);
    }
  }

  // ── Loading overlay ──────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    // FlutterMap genuinely isn't built while !_mapReady (see build()), so
    // this can just be a plain conditional — no opacity/IgnorePointer
    // dance needed, since there's no live map underneath competing for
    // gestures or paint time.
    if (_mapReady) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: green600,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 14),
              Text(
                'Loading map…',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat pill — matches Dex screen _StatPill exactly ─────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill(this.number, this.label);
  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              number,
              style: GoogleFonts.spaceMono(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info stat tile — used inside the tap info card ───────────────────────────

class _InfoStat extends StatelessWidget {
  const _InfoStat({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 13, color: textMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    color: textMuted,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
