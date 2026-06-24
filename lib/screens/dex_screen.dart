import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/app_database.dart';
import '../models/dex_card_data.dart';
import '../models/dex_repository.dart';
import '../theme/colors.dart';
import '../theme/rarity.dart';
import '../widgets/rarity_pill.dart';

class DexScreen extends StatefulWidget {
  const DexScreen({super.key});

  @override
  State<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends State<DexScreen> {
  Stream<DexSections>? _sectionsStream;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final db = await AppDatabase.getInstance();
    if (!mounted) return; // screen was popped before the DB finished opening
    final repository = DexRepository(db.caughtPlantDao);
    setState(() {
      _sectionsStream = repository.watchSections();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: _sectionsStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DexSections>(
              stream: _sectionsStream,
              builder: (context, snapshot) {
                final sections = snapshot.data ?? DexSections.empty;
                return _DexScreenBody(sections: sections);
              },
            ),
    );
  }
}

class _DexScreenBody extends StatelessWidget {
  const _DexScreenBody({required this.sections});

  final DexSections sections;

  @override
  Widget build(BuildContext context) {
    final stats = sections.stats;
    final isEmpty = stats.caughtCount == 0;

    return CustomScrollView(
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
                    Row(
                      children: [
                        _StatPill('${stats.caughtCount}', 'Caught'),
                        const SizedBox(width: 8),
                        _StatPill('${stats.rarePlusCount}', 'Rare+'),
                        const SizedBox(width: 8),
                        _StatPill('${stats.legendaryCount}', 'Legendary'),
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
        if (isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else
          _DexSection(
            title: 'Recent catches',
            cards: sections.recent,
            onTap: (c) => context.push('/detect'),
          ),
        if (sections.legendary.isNotEmpty)
          _DexSection(
            title: 'Legendary',
            cards: sections.legendary,
            onTap: (c) => !c.isLocked ? context.push('/detect') : null,
          ),
        if (sections.rare.isNotEmpty)
          _DexSection(
            title: 'Rare',
            cards: sections.rare,
            onTap: (c) => !c.isLocked ? context.push('/detect') : null,
          ),

        // Bottom padding for nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.eco_outlined, size: 40, color: textMuted),
            const SizedBox(height: 12),
            Text('No plants caught yet',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                )),
            const SizedBox(height: 4),
            Text('Scan a plant to start your collection',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: textMuted,
                )),
          ],
        ),
      ),
    );
  }
}

class _DexSection extends StatelessWidget {
  const _DexSection(
      {required this.title, required this.cards, required this.onTap});
  final String title;
  final List<DexCardData> cards;
  final void Function(DexCardData) onTap;

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
            children: cards
                .map((c) => _DexCard(card: c, onTap: () => onTap(c)))
                .toList(),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _DexCard extends StatelessWidget {
  const _DexCard({required this.card, required this.onTap});
  final DexCardData card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rarity = card.rarity;

    return GestureDetector(
      onTap: card.isLocked ? null : onTap,
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
                  Positioned.fill(
                    child: card.isLocked
                        ? _LockedFallback(rarity: rarity)
                        : (card.photoPath?.isNotEmpty ?? false)
                            ? Image.file(
                                File(card.photoPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _CardFallback(rarity: rarity),
                              )
                            : _CardFallback(rarity: rarity),
                  ),
                  if (!card.isLocked)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: RarityBadge(rarity),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(card.commonName,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: card.isLocked ? textMuted : textPrimary,
                              height: 1.2,
                            )),
                      ),
                      if (card.isLocked)
                        const Icon(Icons.lock_outline,
                            size: 13, color: textMuted),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.isLocked
                        ? 'Not yet found'
                        : (card.scientificName ?? ''),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown for a locked target card — a hint that something is out there
/// without revealing what it looks like.
class _LockedFallback extends StatelessWidget {
  const _LockedFallback({required this.rarity});
  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: surface2,
      child: const Center(
        child: Icon(Icons.lock_outline, size: 30, color: textMuted),
      ),
    );
  }
}

/// Shown when a caught plant has no usable photo (missing/broken path).
class _CardFallback extends StatelessWidget {
  const _CardFallback({required this.rarity});
  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: rarity.background,
      child: Center(child: _PlantMiniIcon(rarity)),
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
