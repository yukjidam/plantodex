import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/caught_plant.dart';
import '../theme/colors.dart';
import '../theme/rarity.dart';
import '../models/plant_rarity_lookup.dart';
import '../widgets/rarity_pill.dart';

/// Read-only detail view for an already-caught plant, opened from the Dex.
///
/// Visually mirrors DetectResultScreen's success state (hero photo, rarity
/// pill, tags, stat boxes, expandable info sections) but reads everything
/// synchronously from the saved [CaughtPlant] — no network calls, no
/// FutureBuilder, so it opens instantly.
class PlantDetailScreen extends StatelessWidget {
  const PlantDetailScreen({super.key, required this.plant});

  final CaughtPlant plant;

  void _openFullScreenPhoto(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) =>
            _FullScreenPhotoViewer(photoPath: plant.photoPath),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rarity = parseRarity(plant.rarity);

    final tags = <String>[
      if (plant.family.isNotEmpty && plant.family != 'Unknown') plant.family,
      if (plant.duration.isNotEmpty) plant.duration.first,
      if (plant.edible) 'Edible',
      if (plant.toxicity == 'medium' || plant.toxicity == 'high')
        'Toxic (${plant.toxicity})',
    ];

    return Scaffold(
      backgroundColor: surface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Hero image ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 380,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      plant.photoPath.isNotEmpty
                          ? GestureDetector(
                              onTap: () => _openFullScreenPhoto(context),
                              child: Image.file(
                                File(plant.photoPath),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                // Capped well above the 380px display
                                // height to stay sharp, but still far
                                // below a raw camera photo's resolution.
                                cacheWidth: 900,
                                errorBuilder: (_, __, ___) => Container(
                                  color: rarity.background,
                                ),
                              ),
                            )
                          : Container(color: rarity.background),

                      // Top scrim
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 120,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom scrim
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 100,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [surface, Colors.transparent],
                            ),
                          ),
                        ),
                      ),

                      // Back button
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 16,
                        child: GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),

                      // Caught date badge
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Text(_formatDate(plant.caughtAtDate),
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.5)),
                        ),
                      ),

                      // Confidence badge
                      Positioned(
                        bottom: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: green600.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${plant.confidencePercent}% match',
                              style: GoogleFonts.spaceMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Content ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RarityPill(rarity),
                      const SizedBox(height: 10),

                      Text(plant.commonName,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: textPrimary)),
                      Text(plant.scientificName,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              color: textSecondary,
                              fontStyle: FontStyle.italic)),

                      const SizedBox(height: 14),

                      if (tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: tags
                              .map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 11, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: green100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(tag,
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: green600)),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Toxicity warning, same as detect screen
                      if (plant.toxicity == 'medium' ||
                          plant.toxicity == 'high') ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            '⚠️ This plant has ${plant.toxicity} toxicity — use caution around pets and children.',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 13, color: amber, height: 1.5),
                          ),
                        ),
                      ],

                      const Divider(color: borderColor),
                      const SizedBox(height: 6),

                      // ── Info sections — only shown when present ────
                      _InfoSection(
                        icon: '🌿',
                        title: 'Overview',
                        body: plant.description.isNotEmpty
                            ? plant.description
                            : 'No description available for this species yet.',
                        initiallyExpanded: true,
                      ),

                      if (plant.habitat != null && plant.habitat!.isNotEmpty)
                        _InfoSection(
                          icon: '🗺️',
                          title: 'Habitat & Distribution',
                          body: plant.habitat!,
                        ),

                      if (plant.careTips != null && plant.careTips!.isNotEmpty)
                        _InfoSection(
                          icon: '🪴',
                          title: 'Care Tips',
                          body: plant.careTips!,
                        ),

                      if (plant.propagation != null &&
                          plant.propagation!.isNotEmpty)
                        _InfoSection(
                          icon: '🌱',
                          title: 'Propagation',
                          body: plant.propagation!,
                        ),

                      if (plant.floweringSeason != null &&
                          plant.floweringSeason!.isNotEmpty)
                        _InfoSection(
                          icon: '🌸',
                          title: 'Flowering & Season',
                          body: plant.floweringSeason!,
                        ),

                      if (plant.conservationStatus != null &&
                          plant.conservationStatus!.isNotEmpty)
                        _InfoSection(
                          icon: '🛡️',
                          title: 'Conservation',
                          body: plant.conservationStatus!,
                        ),

                      if (plant.funFacts != null && plant.funFacts!.isNotEmpty)
                        _InfoSection(
                          icon: '✨',
                          title: 'Fun Facts',
                          body: plant.funFacts!,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
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
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

// ── Full-screen photo viewer ─────────────────────────────────────────────

class _FullScreenPhotoViewer extends StatelessWidget {
  const _FullScreenPhotoViewer({required this.photoPath});

  final String photoPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.file(
                File(photoPath),
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expandable info section tile (same as detect screen) ────────────────────

class _InfoSection extends StatefulWidget {
  const _InfoSection({
    required this.icon,
    required this.title,
    required this.body,
    this.initiallyExpanded = false,
  });

  final String icon;
  final String title;
  final String body;
  final bool initiallyExpanded;

  @override
  State<_InfoSection> createState() => _InfoSectionState();
}

class _InfoSectionState extends State<_InfoSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _ctrl;
  late final Animation<double> _rotate;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: _expanded ? 1.0 : 0.0,
    );
    _rotate = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                RotationTransition(
                  turns: _rotate,
                  child: const Icon(Icons.keyboard_arrow_down,
                      size: 20, color: textSecondary),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _fade,
          axisAlignment: -1,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
            child: Text(
              widget.body,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: textSecondary,
                height: 1.65,
              ),
            ),
          ),
        ),
        const Divider(color: borderColor, height: 1),
      ],
    );
  }
}
