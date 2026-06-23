import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/rarity.dart';
import '../widgets/rarity_pill.dart';
import '../providers/detection_provider.dart';
import '../repositories/plant_repository.dart'; // PlantResult

class DetectResultScreen extends StatefulWidget {
  const DetectResultScreen({super.key, required this.photo});

  /// Captured/selected photo, passed in via `context.push('/detect', extra: file)`.
  final File photo;

  @override
  State<DetectResultScreen> createState() => _DetectResultScreenState();
}

class _DetectResultScreenState extends State<DetectResultScreen> {
  late final DetectionProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = DetectionProvider();
    _provider.identify(widget.photo);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<DetectionProvider>(
        builder: (context, provider, _) {
          switch (provider.status) {
            case DetectionStatus.idle:
            case DetectionStatus.checkingPlant:
            case DetectionStatus.identifying:
            case DetectionStatus.fetchingInfo:
              return _LoadingScaffold(status: provider.status);
            case DetectionStatus.notAPlant:
              return _MessageScaffold(
                emoji: '🤔',
                title: "That doesn't look like a plant",
                subtitle: 'Try framing a leaf, flower, or stem more closely.',
                primaryLabel: 'Scan again',
                onPrimary: () => context.pop(),
              );
            case DetectionStatus.poorImageQuality:
              return _MessageScaffold(
                emoji: '📷',
                title: 'Photo needs improvement',
                subtitle: provider.errorMessage ??
                    'Try getting closer and making sure the plant is in focus.',
                primaryLabel: 'Scan again',
                onPrimary: () => context.pop(),
              );
            case DetectionStatus.noMatch:
              return _MessageScaffold(
                emoji: '🔍',
                title: "Couldn't identify this one",
                subtitle:
                    'Pl@ntNet didn\'t find a confident match. Try a clearer or closer shot.',
                primaryLabel: 'Scan again',
                onPrimary: () => context.pop(),
              );
            case DetectionStatus.quotaExceeded:
              return _MessageScaffold(
                emoji: '⏳',
                title: 'Daily scan limit reached',
                subtitle:
                    'The identification service hit its daily quota. Please try again tomorrow.',
                primaryLabel: 'Go back',
                onPrimary: () => context.pop(),
              );
            case DetectionStatus.error:
              return _MessageScaffold(
                emoji: '⚠️',
                title: 'Something went wrong',
                subtitle: provider.errorMessage ?? 'Please try again.',
                primaryLabel: 'Try again',
                onPrimary: () => provider.identify(widget.photo),
              );
            case DetectionStatus.success:
              return _ResultScaffold(
                photo: widget.photo,
                result: provider.result!,
              );
          }
        },
      ),
    );
  }
}

// ── Loading state ────────────────────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.status});
  final DetectionStatus status;

  String get _message {
    switch (status) {
      case DetectionStatus.checkingPlant:
        return 'Checking your photo…';
      case DetectionStatus.identifying:
        return 'Identifying the species…';
      case DetectionStatus.fetchingInfo:
        return 'Fetching plant details…';
      default:
        return 'Working on it…';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: green600, strokeWidth: 2.5),
            const SizedBox(height: 18),
            Text(
              _message,
              style:
                  GoogleFonts.spaceGrotesk(fontSize: 14, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error / not-a-plant / no-match / quota / quality states ─────────────────

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      primaryLabel,
                      style:
                          GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Success state ─────────────────────────────────────────────────────────────

class _ResultScaffold extends StatelessWidget {
  const _ResultScaffold({required this.photo, required this.result});
  final File photo;
  final PlantResult result;

  @override
  Widget build(BuildContext context) {
    final id = result.identification;
    final care = result.careInfo;

    final rarity = id.confidencePercent >= 85 ? Rarity.rare : Rarity.common;

    final tags = <String>[
      id.family,
      if (care.indoor) 'Indoor' else 'Outdoor',
      if (care.poisonousToPets) 'Toxic to pets',
      care.cycle,
    ];

    return Scaffold(
      backgroundColor: surface,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Hero ───────────────────────────────────────────────────
              SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0D1F0A),
                            Color(0xFF1E4012),
                            Color(0xFF0A180A),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
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
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text('NEW FIND',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 1,
                            )),
                      ),
                    ),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          photo,
                          width: 130,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
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
                        child: Text('${id.confidencePercent}% match',
                            style: GoogleFonts.spaceMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            )),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable content ────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RarityPill(rarity),
                      const SizedBox(height: 10),
                      Text(id.commonName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          )),
                      Text(id.scientificName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            color: textSecondary,
                            fontStyle: FontStyle.italic,
                          )),
                      const SizedBox(height: 14),
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
                                        color: green600,
                                      )),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StatBox(label: 'Watering', value: care.watering),
                          const SizedBox(width: 8),
                          _StatBox(
                              label: 'Sunlight',
                              value: care.sunlight.isNotEmpty
                                  ? care.sunlight.first.replaceAll('_', ' ')
                                  : 'Unknown'),
                          const SizedBox(width: 8),
                          const _StatBox(
                              label: 'XP reward',
                              value: '+120',
                              valueGreen: true),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('ID confidence',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12, color: textMuted)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: id.confidence.clamp(0, 1),
                                backgroundColor: borderColor,
                                valueColor:
                                    const AlwaysStoppedAnimation(green400),
                                minHeight: 5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${id.confidencePercent}%',
                              style: GoogleFonts.spaceMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: green600,
                              )),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: borderColor),
                      const SizedBox(height: 14),
                      Text(
                        care.description.isNotEmpty
                            ? care.description
                            : 'No additional description available for this species yet.',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          color: textSecondary,
                          height: 1.65,
                        ),
                      ),
                      if (care.poisonousToHumans) ...[
                        const SizedBox(height: 14),
                        Text(
                          '⚠️ This plant is potentially toxic to humans if ingested.',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: amber,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── CTA bar ──────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, surface.withOpacity(1)],
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).padding.bottom + 14),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/catch', extra: result),
                      icon: const Text('🌱', style: TextStyle(fontSize: 18)),
                      label: Text('Pick this plant!',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          )),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green600,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Skip', 'Save for later', 'Share']
                        .map((lbl) => Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: OutlinedButton(
                                  onPressed: lbl == 'Skip'
                                      ? () => context.pop()
                                      : () {},
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: textSecondary,
                                    side: const BorderSide(color: borderColor),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                  ),
                                  child: Text(lbl,
                                      style: GoogleFonts.spaceGrotesk(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat box ──────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.label, required this.value, this.valueGreen = false});
  final String label;
  final String value;
  final bool valueGreen;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text(label,
              style: GoogleFonts.spaceGrotesk(fontSize: 10, color: textMuted)),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueGreen ? green600 : textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
