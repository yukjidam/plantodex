import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/home_provider.dart';
import '../models/caught_plant.dart';

// ─────────────────────────────────────────────────────────────────────────────
// home_screen.dart  —  Phase 9 · PlantoDex  (LIVE)
//
// All data sourced from HomeProvider → PlantRepository → Floor DB.
// Stubs still in place: streak, daily quest, next-badge
// (no model exists yet — clearly marked with TODO).
// ─────────────────────────────────────────────────────────────────────────────

String _greetingSubtitle() {
  final h = DateTime.now().hour;
  if (h >= 6 && h < 10) return 'Early light — great time to spot flowers.';
  if (h >= 10 && h < 14) return 'Peak light — colours are vivid right now.';
  if (h >= 14 && h < 18) return 'Golden hour approaches. Head outside?';
  if (h >= 18 && h < 21) return 'Dusk — some plants only bloom at night.';
  return 'Late night. Even fungi count as a find.';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load on first mount. Use addPostFrameCallback so the provider is already
    // in the tree before we call notifyListeners().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, home, _) {
        return Scaffold(
          backgroundColor: surface,
          body: home.loading
              ? const Center(
                  child: CircularProgressIndicator(color: green600),
                )
              : CustomScrollView(
                  slivers: [
                    // ── Header ──────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Home',
                                      style: GoogleFonts.spaceMono(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      _greetingSubtitle(),
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 13,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: amberLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  home.currentStreak == 0
                                      ? '🔥 No streak'
                                      : '🔥 ${home.currentStreak} day${home.currentStreak == 1 ? '' : 's'}',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 12),
                          _TodayRow(home: home),
                          const SizedBox(height: 14),
                          const _DailyQuestCard(), // TODO: real quest model
                          const SizedBox(height: 14),
                          _LastCatchTrophy(plant: home.lastCatch),
                          const SizedBox(height: 14),
                          _CollectionSnapshot(home: home),
                          const SizedBox(height: 14),
                          _NextBadgeNudge(home: home),
                          const SizedBox(height: 14),
                          _RecentSpots(home: home),
                        ]),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ── Today at a glance ─────────────────────────────────────────────────────────

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.home});
  final HomeProvider home;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatPill(
          emoji: '🌿',
          label: 'Today',
          value: '${home.todayCatchCount} catches',
        ),
        const SizedBox(width: 8),
        _StatPill(
          emoji: '⚡',
          label: 'XP today',
          value: '+${home.todayXp} XP',
        ),
        const SizedBox(width: 8),
        _StatPill(
          emoji: '📦',
          label: 'Total',
          value: '${home.totalCatchCount} plants',
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _StatPill({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 3),
            Text(
              value,
              style: GoogleFonts.spaceMono(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Daily quest card ─────────────────────────────────────────────────────────
// TODO: Replace with a real DailyQuest model + QuestProvider (Phase 10+).
// Keeping static for now so the layout stays intact.

class _DailyQuestCard extends StatelessWidget {
  const _DailyQuestCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: amberLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '🎯  DAILY QUEST',
                  style: GoogleFonts.spaceGrotesk(
                    color: amber,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Resets in 6h 42m',
                style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Catch 1 Epic or higher plant',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Find a plant with fewer than 20,000 global occurrences.',
            style: GoogleFonts.spaceGrotesk(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.0,
              minHeight: 7,
              backgroundColor: grayLight,
              valueColor: AlwaysStoppedAnimation(amber),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 / 1 completed',
                style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 11),
              ),
              Text(
                'Reward: +50 XP',
                style: GoogleFonts.spaceGrotesk(
                  color: amber,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/scan'),
              style: FilledButton.styleFrom(
                backgroundColor: green600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(
                'Go Scan',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Last catch trophy ─────────────────────────────────────────────────────────

class _LastCatchTrophy extends StatelessWidget {
  const _LastCatchTrophy({required this.plant});
  final CaughtPlant? plant;

  @override
  Widget build(BuildContext context) {
    if (plant == null) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text('🌱', style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text(
                  'No catches yet — head outside!',
                  style:
                      GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final photoFile = File(plant!.photoPath);

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              '🏆  Last Catch',
              style: GoogleFonts.spaceGrotesk(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Stack(
              children: [
                // ── Plant photo ──
                SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: photoFile.existsSync()
                      ? Image.file(photoFile, fit: BoxFit.cover)
                      : Container(
                          color: green100,
                          child: Center(
                            child: Text('🌺',
                                style: const TextStyle(fontSize: 48)),
                          ),
                        ),
                ),
                // ── Gradient overlay ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 32, 14, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.72),
                        ],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plant!.commonName,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                plant!.scientificName,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 11, color: Colors.white54),
                                  const SizedBox(width: 2),
                                  Text(
                                    _caughtLabel(plant!),
                                    style: GoogleFonts.spaceGrotesk(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RarityBadge(rarity: plant!.rarity),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _caughtLabel(CaughtPlant p) {
    final ago = _timeAgo(p.caughtAtDate);
    if (p.latitude != null && p.longitude != null) {
      return '${p.latitude!.toStringAsFixed(2)}, ${p.longitude!.toStringAsFixed(2)} · $ago';
    }
    return ago;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Collection snapshot ───────────────────────────────────────────────────────

class _CollectionSnapshot extends StatelessWidget {
  const _CollectionSnapshot({required this.home});
  final HomeProvider home;

  @override
  Widget build(BuildContext context) {
    final total = home.totalCatchCount;
    // Avoid division by zero when the collection is empty.
    final safeTotal = total == 0 ? 1 : total;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊  My Collection',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          // Stacked rarity bar — proportional to real counts.
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  if (home.commonCount > 0)
                    _BarSegment(
                        flex: home.commonCount * 100 ~/ safeTotal,
                        color: green400),
                  if (home.epicCount > 0)
                    _BarSegment(
                        flex: home.epicCount * 100 ~/ safeTotal,
                        color: const Color(0xFFE879B0)),
                  if (home.rareCount > 0)
                    _BarSegment(
                        flex: home.rareCount * 100 ~/ safeTotal, color: purple),
                  if (home.legendaryCount > 0)
                    _BarSegment(
                        flex: home.legendaryCount * 100 ~/ safeTotal,
                        color: amber),
                  // Always keep at least a 1-flex spacer so the row has height.
                  if (home.commonCount == 0 &&
                      home.epicCount == 0 &&
                      home.rareCount == 0 &&
                      home.legendaryCount == 0)
                    _BarSegment(flex: 1, color: grayLight),
                ],
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [_BarSegment(flex: 1, color: grayLight)],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RarityCount(
                  emoji: '🌿',
                  label: 'Common',
                  count: home.commonCount,
                  color: green500),
              _RarityCount(
                  emoji: '🌸',
                  label: 'Epic',
                  count: home.epicCount,
                  color: const Color(0xFFD946A0)),
              _RarityCount(
                  emoji: '💜',
                  label: 'Rare',
                  count: home.rareCount,
                  color: purple),
              _RarityCount(
                  emoji: '🔥',
                  label: 'Legendary',
                  count: home.legendaryCount,
                  color: amber),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.grass_outlined, size: 13, color: textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  total == 0
                      ? 'No plants yet — go catch something!'
                      : '$total plants · ${home.families.length} families'
                          '${home.topFamily.isNotEmpty ? ' · Most caught: ${home.topFamily}' : ''}',
                  style: GoogleFonts.spaceGrotesk(
                      color: textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Next badge nudge ──────────────────────────────────────────────────────────

class _NextBadgeNudge extends StatelessWidget {
  const _NextBadgeNudge({required this.home});
  final HomeProvider home;

  @override
  Widget build(BuildContext context) {
    final allUnlocked = home.nextBadgeTarget == 1 &&
        home.nextBadgeName == 'All badges unlocked!';

    return _Card(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: purpleLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(home.nextBadgeEmoji,
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'NEXT BADGE',
                      style: GoogleFonts.spaceGrotesk(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    if (!allUnlocked)
                      Text(
                        '${home.nextBadgeCurrent} / ${home.nextBadgeTarget}',
                        style: GoogleFonts.spaceMono(
                          color: purple,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  home.nextBadgeName,
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (!allUnlocked) ...[
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: home.nextBadgeProgress,
                      minHeight: 6,
                      backgroundColor: purpleLight,
                      valueColor: AlwaysStoppedAnimation(purple),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    home.nextBadgeHint,
                    style: GoogleFonts.spaceGrotesk(
                        color: textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent spots ──────────────────────────────────────────────────────────────

class _RecentSpots extends StatelessWidget {
  const _RecentSpots({required this.home});
  final HomeProvider home;

  @override
  Widget build(BuildContext context) {
    final spots = home.recentSpots;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🗺️  Recent Spots',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          if (spots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Your catch locations will appear here.',
                style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 12),
              ),
            )
          else
            ...spots.map(
              (spot) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: green100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('📍', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        spot.label,
                        style: GoogleFonts.spaceGrotesk(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${spot.plantCount} plant${spot.plantCount == 1 ? '' : 's'}',
                      style:
                          GoogleFonts.spaceMono(color: textMuted, fontSize: 11),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, color: textMuted, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared primitives ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _BarSegment extends StatelessWidget {
  final int flex;
  final Color color;
  const _BarSegment({required this.flex, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex < 1 ? 1 : flex,
      child: Container(height: 9, color: color),
    );
  }
}

class _RarityCount extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final Color color;
  const _RarityCount({
    required this.emoji,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: GoogleFonts.spaceMono(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  final String rarity;
  const _RarityBadge({required this.rarity});

  @override
  Widget build(BuildContext context) {
    final (emoji, label, color, bg) = switch (rarity.toLowerCase()) {
      'legendary' => ('🔥', 'Legendary', amber, amberLight),
      'rare' => ('💜', 'Rare', purple, purpleLight),
      'epic' => (
          '🌸',
          'Epic',
          const Color(0xFFD946A0),
          const Color(0xFFFCE7F3)
        ),
      _ => ('🌿', 'Common', green500, green100),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$emoji  $label',
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
