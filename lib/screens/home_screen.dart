import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// home_screen.dart  —  Phase 9 · PlantoDex
//
// Placeholder layout — all data is static mock values for design review.
// ─────────────────────────────────────────────────────────────────────────────

String _greetingSubtitle() {
  final h = DateTime.now().hour;
  if (h >= 6 && h < 10) return 'Early light — great time to spot flowers.';
  if (h >= 10 && h < 14) return 'Peak light — colours are vivid right now.';
  if (h >= 14 && h < 18) return 'Golden hour approaches. Head outside?';
  if (h >= 18 && h < 21) return 'Dusk — some plants only bloom at night.';
  return 'Late night. Even fungi count as a find.';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: CustomScrollView(
        slivers: [
          // ── Header — matches Profile screen style exactly ──────────
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
                    // Streak pill — mirrors the XP pill in Profile
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: amberLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🔥 5 days',
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
                const _TodayRow(),
                const SizedBox(height: 14),
                const _DailyQuestCard(),
                const SizedBox(height: 14),
                const _LastCatchTrophy(),
                const SizedBox(height: 14),
                const _CollectionSnapshot(),
                const SizedBox(height: 14),
                const _NextBadgeNudge(),
                const SizedBox(height: 14),
                const _RecentSpots(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Today at a glance ─────────────────────────────────────────────────────────

class _TodayRow extends StatelessWidget {
  const _TodayRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatPill(emoji: '🌿', label: 'Today', value: '3 catches'),
        const SizedBox(width: 8),
        _StatPill(emoji: '⚡', label: 'XP today', value: '+90 XP'),
        const SizedBox(width: 8),
        _StatPill(emoji: '📦', label: 'Total', value: '24 plants'),
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

// ── Daily quest card ──────────────────────────────────────────────────────────

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
              onPressed: () {},
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
  const _LastCatchTrophy();

  @override
  Widget build(BuildContext context) {
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
                // Placeholder photo area
                Container(
                  height: 170,
                  width: double.infinity,
                  color: green100,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🌺', style: const TextStyle(fontSize: 48)),
                        const SizedBox(height: 6),
                        Text(
                          'Photo goes here',
                          style: GoogleFonts.spaceGrotesk(
                              color: textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                // Gradient info overlay
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
                                'Waling-waling Orchid',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Vanda sanderiana',
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
                                    'Poblacion, Tarlac City · 2h ago',
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
                        _RarityBadge(rarity: 'legendary'),
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
}

// ── Collection snapshot ───────────────────────────────────────────────────────

class _CollectionSnapshot extends StatelessWidget {
  const _CollectionSnapshot();

  @override
  Widget build(BuildContext context) {
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
          // Stacked rarity bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                _BarSegment(flex: 14, color: green400),
                _BarSegment(flex: 6, color: const Color(0xFFE879B0)),
                _BarSegment(flex: 3, color: purple),
                _BarSegment(flex: 1, color: amber),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RarityCount(
                  emoji: '🌿', label: 'Common', count: 14, color: green500),
              _RarityCount(
                  emoji: '🌸',
                  label: 'Epic',
                  count: 6,
                  color: const Color(0xFFD946A0)),
              _RarityCount(emoji: '💜', label: 'Rare', count: 3, color: purple),
              _RarityCount(
                  emoji: '🔥', label: 'Legendary', count: 1, color: amber),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.grass_outlined, size: 13, color: textMuted),
              const SizedBox(width: 5),
              Text(
                '24 plants · 11 families · Most caught: Orchidaceae',
                style: GoogleFonts.spaceGrotesk(
                    color: textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
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
      flex: flex,
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

// ── Next badge nudge ──────────────────────────────────────────────────────────

class _NextBadgeNudge extends StatelessWidget {
  const _NextBadgeNudge();

  @override
  Widget build(BuildContext context) {
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
            child: const Center(
              child: Text('🏅', style: TextStyle(fontSize: 24)),
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
                    Text(
                      '24 / 50',
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
                  'Naturalist',
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.48,
                    minHeight: 6,
                    backgroundColor: purpleLight,
                    valueColor: AlwaysStoppedAnimation(purple),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '26 more catches to unlock',
                  style:
                      GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 11),
                ),
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
  const _RecentSpots();

  static const _spots = [
    ('Poblacion, Tarlac City', '8 plants'),
    ('SM City Tarlac', '5 plants'),
    ('Urdaneta, Pangasinan', '3 plants'),
  ];

  @override
  Widget build(BuildContext context) {
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
          ..._spots.map(
            (s) => Padding(
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
                      s.$1,
                      style: GoogleFonts.spaceGrotesk(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    s.$2,
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
