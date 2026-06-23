import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../theme/rarity.dart';
import '../widgets/rarity_pill.dart';

class _Plant {
  const _Plant({
    required this.name,
    required this.scientific,
    required this.rarity,
    required this.gradient,
    this.locked = false,
  });
  final String name;
  final String scientific;
  final Rarity rarity;
  final List<Color> gradient;
  final bool locked;
}

const _recent = [
  _Plant(
      name: 'Blue Vanda Orchid',
      scientific: 'Vanda coerulea',
      rarity: Rarity.rare,
      gradient: [Color(0xFF1A0A28), Color(0xFF3D1A6E)]),
  _Plant(
      name: 'Boston Fern',
      scientific: 'Nephrolepis exaltata',
      rarity: Rarity.common,
      gradient: [Color(0xFF1A3010), Color(0xFF2D5A1B)]),
  _Plant(
      name: 'Sacred Lotus',
      scientific: 'Nelumbo nucifera',
      rarity: Rarity.epic,
      gradient: [Color(0xFF1F0A14), Color(0xFF6E1A3D)]),
  _Plant(
      name: 'Lucky Bamboo',
      scientific: 'Dracaena sanderiana',
      rarity: Rarity.common,
      gradient: [Color(0xFF0F1F08), Color(0xFF3D7A24)]),
];

const _legendary = [
  _Plant(
      name: 'Rafflesia',
      scientific: 'Rafflesia arnoldii',
      rarity: Rarity.legendary,
      gradient: [Color(0xFF2A0A00), Color(0xFF8B2500)]),
  _Plant(
      name: '???',
      scientific: 'Not yet found',
      rarity: Rarity.legendary,
      gradient: [surface2, surface2],
      locked: true),
];

final _undiscovered = List.generate(
  4,
  (_) => const _Plant(
      name: '???',
      scientific: 'Not yet found',
      rarity: Rarity.common,
      gradient: [surface2, surface2],
      locked: true),
);

class DexScreen extends StatelessWidget {
  const DexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: CustomScrollView(
        slivers: [
          // ── Top bar ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: surface,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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
                              Text('PlantoDex',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  )),
                              Text('Your botanical collection',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 13,
                                    color: textSecondary,
                                  )),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: green100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('248 XP',
                                style: GoogleFonts.spaceMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: green600,
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stat pills
                      const Row(
                        children: [
                          _StatPill('12', 'Caught'),
                          SizedBox(width: 8),
                          _StatPill('3', 'Rare+'),
                          SizedBox(width: 8),
                          _StatPill('1', 'Legendary'),
                          SizedBox(width: 8),
                          _StatPill('88', 'Left'),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Search bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(children: [
                          const Icon(Icons.search, size: 16, color: textMuted),
                          const SizedBox(width: 9),
                          Text('Search plants…',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14, color: textMuted)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Grid sections ──────────────────────────────────────────────────
          _DexSection(
              title: 'Recent catches',
              plants: _recent,
              onTap: (p) => context.push('/detect')),
          _DexSection(
              title: 'Legendary',
              plants: _legendary,
              onTap: (p) => !p.locked ? context.push('/detect') : null),
          _DexSection(
              title: 'Undiscovered', plants: _undiscovered, onTap: (_) {}),

          // Bottom padding for nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _DexSection extends StatelessWidget {
  const _DexSection(
      {required this.title, required this.plants, required this.onTap});
  final String title;
  final List<_Plant> plants;
  final void Function(_Plant) onTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 10),
            child: Text(title.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                  letterSpacing: 1,
                )),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.88,
            children: plants
                .map((p) => _DexCard(plant: p, onTap: () => onTap(p)))
                .toList(),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _DexCard extends StatelessWidget {
  const _DexCard({required this.plant, required this.onTap});
  final _Plant plant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: plant.locked ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            SizedBox(
              height: 90,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: plant.locked ? surface2 : null,
                      gradient: plant.locked
                          ? null
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: plant.gradient,
                            ),
                    ),
                    child: plant.locked
                        ? const Center(
                            child: Icon(Icons.lock_outline,
                                size: 30, color: textMuted))
                        : Center(child: _PlantMiniIcon(plant.rarity)),
                  ),
                  if (!plant.locked)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: RarityBadge(plant.rarity),
                    ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plant.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: plant.locked ? textMuted : textPrimary,
                        height: 1.2,
                      )),
                  const SizedBox(height: 2),
                  Text(plant.scientific,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: textMuted,
                        fontStyle: FontStyle.italic,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantMiniIcon extends StatelessWidget {
  const _PlantMiniIcon(this.rarity);
  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final color = switch (rarity) {
      Rarity.common => Colors.white.withOpacity(0.3),
      Rarity.rare => const Color(0xFF9A60D0).withOpacity(0.7),
      Rarity.epic => const Color(0xFFC04080).withOpacity(0.7),
      Rarity.legendary => const Color(0xFFFF6432).withOpacity(0.4),
    };
    return Container(
      width: 30,
      height: 45,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(999),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(999),
          bottomRight: Radius.circular(8),
        ),
      ),
    );
  }
}

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
        child: Column(children: [
          Text(number,
              style: GoogleFonts.spaceMono(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              )),
          Text(label,
              style: GoogleFonts.spaceGrotesk(fontSize: 11, color: textMuted)),
        ]),
      ),
    );
  }
}
