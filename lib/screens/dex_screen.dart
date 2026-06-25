import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/app_database.dart';
import '../models/dex_card_data.dart';
import '../models/dex_repository.dart';
import '../repositories/plant_repository.dart';
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
  PlantRepository? _repository;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final db = await AppDatabase.getInstance();
    if (!mounted) return;
    final repository = PlantRepository();
    final dexRepository = DexRepository(db.caughtPlantDao);
    setState(() {
      _repository = repository;
      _sectionsStream = dexRepository.watchSections();
    });
  }

  Future<void> _deleteCatch(BuildContext context, DexCardData card) async {
    if (card.caught == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove from Dex?',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        content: Text(
          '${card.commonName} will be removed from your collection. This cannot be undone.',
          style: GoogleFonts.spaceGrotesk(fontSize: 14, color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );

    if (confirmed == true && _repository != null) {
      await _repository!.deleteCatch(card.caught!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${card.commonName} removed.',
              style: GoogleFonts.spaceGrotesk(color: textPrimary),
            ),
            backgroundColor: surface2,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
                return _DexScreenBody(
                  sections: sections,
                  onDelete: (card) => _deleteCatch(context, card),
                );
              },
            ),
    );
  }
}

class _DexScreenBody extends StatelessWidget {
  const _DexScreenBody({required this.sections, required this.onDelete});

  final DexSections sections;
  final Future<void> Function(DexCardData) onDelete;

  @override
  Widget build(BuildContext context) {
    final stats = sections.stats;
    final isEmpty = sections.all.isEmpty;

    return CustomScrollView(
      slivers: [
        // ── Top bar ──────────────────────────────────────────────────────
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

        // ── Album grid ────────────────────────────────────────────────────
        if (isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else
          _DexSection(
            title: 'My Collection',
            cards: sections.all,
            onTap: (c) {
              context.push('/detect');
            },
            onDelete: onDelete,
          ),

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
  const _DexSection({
    required this.title,
    required this.cards,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final List<DexCardData> cards;
  final void Function(DexCardData) onTap;
  final Future<void> Function(DexCardData) onDelete;

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
            childAspectRatio: 0.74,
            children: cards
                .map((c) => _DexCard(
                      card: c,
                      onTap: () => onTap(c),
                      onDelete: () => onDelete(c),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _DexCard extends StatelessWidget {
  const _DexCard({
    required this.card,
    required this.onTap,
    required this.onDelete,
  });

  final DexCardData card;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rarity = card.rarity;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
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
                    child: (card.photoPath?.isNotEmpty ?? false)
                        ? Image.file(
                            File(card.photoPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _CardFallback(rarity: rarity),
                          )
                        : _CardFallback(rarity: rarity),
                  ),
                  // Rarity pill — top right
                  Positioned(
                    top: 7,
                    right: 7,
                    child: RarityBadge(rarity),
                  ),
                  // Delete button — top left
                  Positioned(
                    top: 7,
                    left: 7,
                    child: GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.delete_outline,
                            size: 14, color: Colors.white),
                      ),
                    ),
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
                  Text(
                    card.commonName,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.scientificName ?? '',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 10, color: textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatDate(card.caughtAt),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            color: textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 10, color: textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          card.location.isNotEmpty
                              ? card.location
                              : 'Location unavailable',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            color: textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
