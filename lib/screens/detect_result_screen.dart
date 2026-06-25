import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/colors.dart';
import '../theme/rarity.dart';
import '../widgets/rarity_pill.dart';
import '../providers/detection_provider.dart';
import '../repositories/plant_repository.dart';
import '../services/gbif_service.dart';
import '../widgets/nature_loader.dart';
import 'catch_success_args.dart';

class DetectResultScreen extends StatefulWidget {
  const DetectResultScreen({super.key, required this.photo});
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
            case DetectionStatus.noMatch:
              return _MessageScaffold(
                emoji: '🔍',
                title: "Couldn't identify this one",
                subtitle:
                    "Pl\u0040ntNet didn't find a confident match. Try a clearer or closer shot.",
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

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.status});
  final DetectionStatus status;

  String get _message {
    switch (status) {
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
            const NatureLoader(size: 96),
            const SizedBox(height: 18),
            Text(_message,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, color: textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Error / message states ────────────────────────────────────────────────────

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
                Text(title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textPrimary)),
                const SizedBox(height: 8),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14, color: textSecondary, height: 1.5)),
                const SizedBox(height: 26),
                SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(primaryLabel,
                        style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w600)),
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

class _ResultScaffold extends StatefulWidget {
  const _ResultScaffold({required this.photo, required this.result});
  final File photo;
  final PlantResult result;

  @override
  State<_ResultScaffold> createState() => _ResultScaffoldState();
}

class _ResultScaffoldState extends State<_ResultScaffold> {
  late final Future<Rarity> _rarityFuture;

  @override
  void initState() {
    super.initState();
    _rarityFuture =
        GbifService().rarityFor(widget.result.identification.scientificName);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.result.identification;
    final care = widget.result.careInfo;

    final tags = <String>[
      if (care.family != 'Unknown') care.family,
      if (care.duration.isNotEmpty) care.duration.first,
      if (care.edible) 'Edible',
      if (care.toxicity == 'medium' || care.toxicity == 'high')
        'Toxic (${care.toxicity})',
    ];

    return FutureBuilder<Rarity>(
      future: _rarityFuture,
      builder: (context, snapshot) {
        // Keep showing loading until rarity is ready — pill appears correct
        // on first render, no flicker.
        if (!snapshot.hasData) {
          return const _LoadingScaffold(status: DetectionStatus.fetchingInfo);
        }
        return _ResultScaffoldBody(
          photo: widget.photo,
          result: widget.result,
          rarity: snapshot.data!,
          tags: tags,
        );
      },
    );
  }
}

class _ResultScaffoldBody extends StatelessWidget {
  const _ResultScaffoldBody({
    required this.photo,
    required this.result,
    required this.rarity,
    required this.tags,
  });

  final File photo;
  final PlantResult result;
  final Rarity rarity;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final id = result.identification;
    final care = result.careInfo;

    return Scaffold(
      backgroundColor: surface,
      body: Stack(
        children: [
          // ── Scrollable body ───────────────────────────────────────
          CustomScrollView(
            slivers: [
              // ── Hero image ────────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 380,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(photo,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity),

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

                      // NEW FIND badge
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
                          child: Text('NEW FIND',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 1)),
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
                          child: Text('${id.confidencePercent}% match',
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

              // ── Content ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RarityPill(rarity),
                      const SizedBox(height: 10),

                      // Common name + scientific name
                      Text(id.commonName,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: textPrimary)),
                      Text(id.scientificName,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              color: textSecondary,
                              fontStyle: FontStyle.italic)),

                      const SizedBox(height: 14),

                      // Tags
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

                      // Genus-level fallback notice
                      if (care.isGenusLevel) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: green100,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: green600.withOpacity(0.25)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('🌿', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  care.genusName != null
                                      ? 'Showing general info for the ${care.genusName} genus — no dedicated page found for this specific species.'
                                      : 'Showing general genus-level info — no dedicated page found for this specific species.',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    color: green600,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Stat boxes
                      Row(
                        children: [
                          _StatBox(label: 'Light', value: care.lightLabel),
                          const SizedBox(width: 8),
                          _StatBox(
                              label: 'Humidity', value: care.humidityLabel),
                          const SizedBox(width: 8),
                          const _StatBox(
                              label: 'XP reward',
                              value: '+120',
                              valueGreen: true),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ID confidence bar
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
                                  color: green600)),
                        ],
                      ),

                      const SizedBox(height: 18),
                      const Divider(color: borderColor),
                      const SizedBox(height: 6),

                      // ── Expandable info sections ──────────────────

                      // Overview (always shown, not collapsible — it's short)
                      _InfoSection(
                        icon: '🌿',
                        title: 'Overview',
                        body: care.description.isNotEmpty
                            ? care.description
                            : 'No description available for this species yet.',
                        initiallyExpanded: true,
                      ),

                      // Toxicity warning inline under overview when severe
                      if (care.toxicity == 'medium' ||
                          care.toxicity == 'high') ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '⚠️ This plant has ${care.toxicity} toxicity — use caution around pets and children.',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 13, color: amber, height: 1.5),
                          ),
                        ),
                      ],

                      if (care.habitat != null)
                        _InfoSection(
                          icon: '🗺️',
                          title: 'Habitat & Distribution',
                          body: care.habitat!,
                        ),

                      if (care.careTips != null)
                        _InfoSection(
                          icon: '🪴',
                          title: 'Care Tips',
                          body: care.careTips!,
                        ),

                      if (care.propagation != null)
                        _InfoSection(
                          icon: '🌱',
                          title: 'Propagation',
                          body: care.propagation!,
                        ),

                      if (care.floweringSeason != null)
                        _InfoSection(
                          icon: '🌸',
                          title: 'Flowering & Season',
                          body: care.floweringSeason!,
                        ),

                      if (care.conservationStatus != null)
                        _InfoSection(
                          icon: '🛡️',
                          title: 'Conservation',
                          body: care.conservationStatus!,
                        ),

                      if (care.funFacts != null)
                        _InfoSection(
                          icon: '✨',
                          title: 'Fun Facts',
                          body: care.funFacts!,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── CTA bar ──────────────────────────────────────────────
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
                  _SaveCatchButton(
                      photo: photo, result: result, rarity: rarity),
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

// ── Save button (handles duplicate-catch validation) ──────────────────────────

class _SaveCatchButton extends StatefulWidget {
  const _SaveCatchButton({
    required this.photo,
    required this.result,
    required this.rarity,
  });
  final File photo;
  final PlantResult result;
  final Rarity rarity;

  @override
  State<_SaveCatchButton> createState() => _SaveCatchButtonState();
}

class _SaveCatchButtonState extends State<_SaveCatchButton> {
  bool _saving = false;

  Future<void> _handleSave() async {
    if (_saving) return; // guard against double-taps
    setState(() => _saving = true);

    try {
      // ── 1. Grab GPS ──────────────────────────────────────────────────────
      double? latitude;
      double? longitude;

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 8),
          );
          latitude = position.latitude;
          longitude = position.longitude;
        }
      } catch (e) {
        debugPrint('[SaveCatch] GPS failed: $e');
        // Non-fatal — save continues without coordinates
      }

      // ── 2. Save with GPS ─────────────────────────────────────────────────
      await PlantRepository.instance.saveCatch(
        photo: widget.photo,
        identification: widget.result.identification,
        careInfo: widget.result.careInfo,
        latitude: latitude,
        longitude: longitude,
      );

      if (context.mounted) {
        context.push(
          '/catch',
          extra: CatchSuccessArgs(result: widget.result, rarity: widget.rarity),
        );
      }
    } on DuplicateCatchException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already in your Dex')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _handleSave,
        icon: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text('🌱', style: TextStyle(fontSize: 18)),
        label: Text(_saving ? 'Saving…' : 'Pick this plant!',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: green600,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }
}

// ── Expandable info section tile ──────────────────────────────────────────────

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
