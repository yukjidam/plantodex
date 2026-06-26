import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/app_database.dart';
import '../models/dex_card_data.dart';
import '../models/dex_repository.dart';
import '../repositories/plant_repository.dart';
import '../services/geocoding_service.dart';
import '../theme/colors.dart';
import '../theme/rarity.dart';
import '../widgets/rarity_pill.dart';

class DexScreen extends StatefulWidget {
  const DexScreen({super.key});

  @override
  State<DexScreen> createState() => _DexScreenState();
}

enum DexSortOrder { dateNewest, nameAZ, rarity }

class _DexScreenState extends State<DexScreen> {
  Stream<DexSections>? _sectionsStream;
  PlantRepository? _repository;
  final _searchController = TextEditingController();
  String _query = '';
  Rarity? _rarityFilter; // null = All
  DexSortOrder _sortOrder = DexSortOrder.dateNewest;

  @override
  void initState() {
    super.initState();
    _init();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                  query: _query,
                  searchController: _searchController,
                  rarityFilter: _rarityFilter,
                  onRarityFilterChanged: (r) =>
                      setState(() => _rarityFilter = r),
                  sortOrder: _sortOrder,
                  onSortOrderChanged: (s) => setState(() => _sortOrder = s),
                  onDelete: (card) => _deleteCatch(context, card),
                );
              },
            ),
    );
  }
}

List<DexCardData> _filterCards(
  List<DexCardData> cards,
  String query,
  Rarity? rarityFilter,
) {
  var result = cards;
  if (rarityFilter != null) {
    result = result.where((c) => c.rarity == rarityFilter).toList();
  }
  if (query.isNotEmpty) {
    final q = query.toLowerCase();
    result = result.where((c) {
      return c.commonName.toLowerCase().contains(q) ||
          c.scientificName.toLowerCase().contains(q) ||
          c.family.toLowerCase().contains(q);
    }).toList();
  }
  return result;
}

/// Accent color per rarity, matching the palette already used by
/// _PlantMiniIcon — kept as solid (non-opacity) colors here since chips/
/// glows need a true accent, not a translucent overlay tint.
Color _rarityAccent(Rarity rarity) => switch (rarity) {
      Rarity.common => textMuted,
      Rarity.rare => const Color(0xFF9A60D0),
      Rarity.epic => const Color(0xFFC04080),
      Rarity.legendary => const Color(0xFFFF6432),
    };

int _rarityRank(Rarity r) => switch (r) {
      Rarity.legendary => 0,
      Rarity.epic => 1,
      Rarity.rare => 2,
      Rarity.common => 3,
    };

List<DexCardData> _sortCards(List<DexCardData> cards, DexSortOrder order) {
  final sorted = [...cards];
  switch (order) {
    case DexSortOrder.dateNewest:
      sorted.sort((a, b) => b.caughtAt.compareTo(a.caughtAt));
    case DexSortOrder.nameAZ:
      sorted.sort((a, b) =>
          a.commonName.toLowerCase().compareTo(b.commonName.toLowerCase()));
    case DexSortOrder.rarity:
      sorted.sort(
          (a, b) => _rarityRank(a.rarity).compareTo(_rarityRank(b.rarity)));
  }
  return sorted;
}

/// Groups already-filtered/sorted cards into rarity sections, ordered
/// Legendary → Epic → Rare → Common. Empty groups are omitted by the caller.
Map<Rarity, List<DexCardData>> _groupByRarity(List<DexCardData> cards) {
  final groups = <Rarity, List<DexCardData>>{
    Rarity.legendary: [],
    Rarity.epic: [],
    Rarity.rare: [],
    Rarity.common: [],
  };
  for (final c in cards) {
    groups[c.rarity]!.add(c);
  }
  return groups;
}

class _DexScreenBody extends StatelessWidget {
  const _DexScreenBody({
    required this.sections,
    required this.query,
    required this.searchController,
    required this.rarityFilter,
    required this.onRarityFilterChanged,
    required this.sortOrder,
    required this.onSortOrderChanged,
    required this.onDelete,
  });

  final DexSections sections;
  final String query;
  final TextEditingController searchController;
  final Rarity? rarityFilter;
  final ValueChanged<Rarity?> onRarityFilterChanged;
  final DexSortOrder sortOrder;
  final ValueChanged<DexSortOrder> onSortOrderChanged;
  final Future<void> Function(DexCardData) onDelete;

  @override
  Widget build(BuildContext context) {
    final stats = sections.stats;
    final totalXp = sections.all.fold<int>(0, (sum, c) => sum + c.xpReward);
    final isEmpty = sections.all.isEmpty;
    final filtered = _filterCards(sections.all, query, rarityFilter);
    final sorted = _sortCards(filtered, sortOrder);
    final noMatches = !isEmpty &&
        (query.isNotEmpty || rarityFilter != null) &&
        sorted.isEmpty;
    final grouped = _groupByRarity(sorted);

    return CustomScrollView(
      slivers: [
        // ── Title + stat pills (scrolls away) ───────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
                          child: Text('$totalXp XP',
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
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Sticky: search + filter chips + sort ────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickySearchHeader(
            searchController: searchController,
            query: query,
            rarityFilter: rarityFilter,
            onRarityFilterChanged: onRarityFilterChanged,
            sortOrder: sortOrder,
            onSortOrderChanged: onSortOrderChanged,
          ),
        ),

        // ── Album grid ────────────────────────────────────────────────────
        if (isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else if (noMatches)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _NoMatchesState(query: query, rarityFilter: rarityFilter),
          )
        else ...[
          for (final rarity in [
            Rarity.legendary,
            Rarity.epic,
            Rarity.rare,
            Rarity.common,
          ])
            if (grouped[rarity]!.isNotEmpty)
              _DexSection(
                rarity: rarity,
                cards: grouped[rarity]!,
                onTap: (c) {
                  context.push('/dex/detail', extra: c.caught);
                },
                onDelete: onDelete,
              ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

class _StickySearchHeader extends SliverPersistentHeaderDelegate {
  _StickySearchHeader({
    required this.searchController,
    required this.query,
    required this.rarityFilter,
    required this.onRarityFilterChanged,
    required this.sortOrder,
    required this.onSortOrderChanged,
  });

  final TextEditingController searchController;
  final String query;
  final Rarity? rarityFilter;
  final ValueChanged<Rarity?> onRarityFilterChanged;
  final DexSortOrder sortOrder;
  final ValueChanged<DexSortOrder> onSortOrderChanged;

  static const double _height = 116;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 16, color: textMuted),
                      const SizedBox(width: 9),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            color: textPrimary,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Search plants…',
                            hintStyle: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              color: textMuted,
                            ),
                          ),
                        ),
                      ),
                      if (query.isNotEmpty)
                        GestureDetector(
                          onTap: searchController.clear,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 9),
                            child:
                                Icon(Icons.close, size: 16, color: textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SortButton(
                sortOrder: sortOrder,
                onChanged: onSortOrderChanged,
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _RarityChip(
                  label: 'All',
                  selected: rarityFilter == null,
                  onTap: () => onRarityFilterChanged(null),
                ),
                const SizedBox(width: 7),
                for (final r in [
                  Rarity.common,
                  Rarity.rare,
                  Rarity.epic,
                  Rarity.legendary,
                ]) ...[
                  _RarityChip(
                    label: r.name[0].toUpperCase() + r.name.substring(1),
                    selected: rarityFilter == r,
                    color: _rarityAccent(r),
                    onTap: () =>
                        onRarityFilterChanged(rarityFilter == r ? null : r),
                  ),
                  const SizedBox(width: 7),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchHeader oldDelegate) {
    return oldDelegate.query != query ||
        oldDelegate.rarityFilter != rarityFilter ||
        oldDelegate.sortOrder != sortOrder ||
        oldDelegate.searchController != searchController;
  }
}

class _RarityChip extends StatelessWidget {
  const _RarityChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? green600;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? chipColor.withOpacity(0.15) : surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : borderColor,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? chipColor : textMuted,
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sortOrder, required this.onChanged});

  final DexSortOrder sortOrder;
  final ValueChanged<DexSortOrder> onChanged;

  String _label(DexSortOrder o) => switch (o) {
        DexSortOrder.dateNewest => 'Newest',
        DexSortOrder.nameAZ => 'A–Z',
        DexSortOrder.rarity => 'Rarity',
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DexSortOrder>(
      initialValue: sortOrder,
      onSelected: onChanged,
      color: surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (context) => DexSortOrder.values
          .map((o) => PopupMenuItem(
                value: o,
                child: Text(_label(o),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: textPrimary,
                      fontWeight:
                          o == sortOrder ? FontWeight.w700 : FontWeight.w400,
                    )),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.swap_vert, size: 16, color: textMuted),
            const SizedBox(width: 5),
            Text(_label(sortOrder),
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, color: textSecondary)),
          ],
        ),
      ),
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

class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState({required this.query, required this.rarityFilter});

  final String query;
  final Rarity? rarityFilter;

  String get _rarityLabel => switch (rarityFilter) {
        Rarity.common => 'Common',
        Rarity.rare => 'Rare',
        Rarity.epic => 'Epic',
        Rarity.legendary => 'Legendary',
        null => '',
      };

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.isNotEmpty;
    final hasRarity = rarityFilter != null;

    final String title;
    final String subtitle;
    if (hasQuery && hasRarity) {
      title = 'No $_rarityLabel matches for "$query"';
      subtitle = 'Try a different name, or clear the rarity filter';
    } else if (hasRarity) {
      title = 'No $_rarityLabel plants yet';
      subtitle = 'Catch one to see it here';
    } else {
      title = 'No matches for "$query"';
      subtitle = 'Try a different name or family';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasRarity && !hasQuery ? Icons.eco_outlined : Icons.search_off,
              size: 40,
              color: textMuted,
            ),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: textMuted,
                ),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _DexSection extends StatelessWidget {
  const _DexSection({
    required this.rarity,
    required this.cards,
    required this.onTap,
    required this.onDelete,
  });

  final Rarity rarity;
  final List<DexCardData> cards;
  final void Function(DexCardData) onTap;
  final Future<void> Function(DexCardData) onDelete;

  String get _title => switch (rarity) {
        Rarity.common => 'Common',
        Rarity.rare => 'Rare',
        Rarity.epic => 'Epic',
        Rarity.legendary => 'Legendary',
      };

  bool get _isSpecial => rarity == Rarity.rare || rarity == Rarity.legendary;

  @override
  Widget build(BuildContext context) {
    final accent = _rarityAccent(rarity);

    // SliverMainAxisGroup lets this widget contribute multiple slivers
    // (header + grid) as one logical unit inside the parent
    // CustomScrollView, while keeping the grid itself a real SliverGrid
    // — built lazily, only as cards scroll into view — rather than the
    // previous GridView.count(shrinkWrap: true), which eagerly built
    // every card (including its image decode) up front regardless of
    // whether it was visible. That eager build was a real cost for
    // anyone with a large collection, especially on lower-end devices.
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 10),
              child: _isSpecial
                  ? Row(
                      children: [
                        Icon(
                          rarity == Rarity.legendary
                              ? Icons.auto_awesome
                              : Icons.diamond_outlined,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [accent, accent.withOpacity(0.55)],
                          ).createShader(bounds),
                          child: Text(
                            '$_title (${cards.length})'.toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text('$_title (${cards.length})'.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                        letterSpacing: 1,
                      )),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.74,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final c = cards[index];
                return _DexCard(
                  card: c,
                  onTap: () => onTap(c),
                  onDelete: () => onDelete(c),
                );
              },
              childCount: cards.length,
            ),
          ),
        ),
      ],
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

    if (rarity == Rarity.legendary) {
      return _LegendaryCard(card: card, onTap: onTap, onDelete: onDelete);
    }
    if (rarity == Rarity.rare) {
      return _RareCard(card: card, onTap: onTap, onDelete: onDelete);
    }

    // Common / Epic: plain card.
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
        child: _DexCardContent(card: card, onDelete: onDelete),
      ),
    );
  }
}

// ─── Rare card — sweeping shimmer border ───────────────────────────────────────────

class _RareCard extends StatefulWidget {
  const _RareCard({
    required this.card,
    required this.onTap,
    required this.onDelete,
  });
  final DexCardData card;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_RareCard> createState() => _RareCardState();
}

class _RareCardState extends State<_RareCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF9A60D0);
    const radius = BorderRadius.all(Radius.circular(12));

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onDelete,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.25 + 0.15 * _ctrl.value),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CustomPaint(
              painter: _ShimmerBorderPainter(
                progress: _ctrl.value,
                baseColor: accent.withOpacity(0.55),
                shimmerColor: Colors.white,
                borderRadius: 12,
                strokeWidth: 1.8,
              ),
              child: child,
            ),
          );
        },
        child: ClipRRect(
          borderRadius: radius,
          child: _DexCardContent(card: widget.card, onDelete: widget.onDelete),
        ),
      ),
    );
  }
}

// ─── Legendary card — pulsing glow + shimmer border + corner sparkles ────────────

class _LegendaryCard extends StatefulWidget {
  const _LegendaryCard({
    required this.card,
    required this.onTap,
    required this.onDelete,
  });
  final DexCardData card;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_LegendaryCard> createState() => _LegendaryCardState();
}

class _LegendaryCardState extends State<_LegendaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF6432);
    const gold = Color(0xFFFFBB33);
    const radius = BorderRadius.all(Radius.circular(12));

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onDelete,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final pulse = (sin(_ctrl.value * 2 * pi) * 0.5 + 0.5);

          return Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.20 + 0.20 * pulse),
                  blurRadius: 12 + 6 * pulse,
                  spreadRadius: 1 + pulse,
                ),
                BoxShadow(
                  color: gold.withOpacity(0.10 + 0.12 * pulse),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CustomPaint(
              foregroundPainter: _SparklesPainter(
                progress: _ctrl.value,
                color: gold,
              ),
              painter: _ShimmerBorderPainter(
                progress: _ctrl.value,
                baseColor: accent.withOpacity(0.7),
                shimmerColor: gold,
                borderRadius: 12,
                strokeWidth: 2.2,
              ),
              child: child,
            ),
          );
        },
        child: ClipRRect(
          borderRadius: radius,
          child: _DexCardContent(card: widget.card, onDelete: widget.onDelete),
        ),
      ),
    );
  }
}

// ─── Painters ────────────────────────────────────────────────────────────────

/// Draws a rounded-rect border with a bright shimmer dot sweeping around it.
class _ShimmerBorderPainter extends CustomPainter {
  const _ShimmerBorderPainter({
    required this.progress,
    required this.baseColor,
    required this.shimmerColor,
    required this.borderRadius,
    required this.strokeWidth,
  });

  final double progress;
  final Color baseColor;
  final Color shimmerColor;
  final double borderRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth,
          size.height - strokeWidth),
      Radius.circular(borderRadius),
    );

    // Base border
    canvas.drawRRect(
      rRect,
      Paint()
        ..color = baseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Sweeping shimmer arc (~18% of perimeter)
    final path = Path()..addRRect(rRect);
    final pm = path.computeMetrics().first;
    final total = pm.length;
    const arcFraction = 0.18;
    final arcLen = total * arcFraction;
    final start = total * progress;

    for (int i = 0; i < 3; i++) {
      final pos = (start + i * arcLen * 0.2).remainder(total);
      final end = pos + arcLen;
      final segPath = pm.extractPath(pos, end.clamp(0, total));
      final opacity = 1.0 - i * 0.35;

      canvas.drawPath(
        segPath,
        Paint()
          ..color = shimmerColor.withOpacity(opacity * 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 1.0 - i * 0.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ShimmerBorderPainter old) => old.progress != progress;
}

/// Four tiny sparkle crosses that twinkle at the corners for legendary cards.
class _SparklesPainter extends CustomPainter {
  const _SparklesPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final corners = [
      Offset(0, 0),
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height),
    ];

    for (int i = 0; i < corners.length; i++) {
      final phase = (progress + i * 0.25).remainder(1.0);
      final twinkle = sin(phase * 2 * pi) * 0.5 + 0.5;
      if (twinkle < 0.1) continue;

      final paint = Paint()
        ..color = color.withOpacity(twinkle * 0.9)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final c = corners[i];
      final s = 5.0 + 3.0 * twinkle;
      final dx = i == 0 || i == 3 ? -8.0 : 8.0;
      final dy = i == 0 || i == 1 ? -8.0 : 8.0;
      final sc = Offset(c.dx + dx, c.dy + dy);

      canvas.drawLine(sc.translate(-s, 0), sc.translate(s, 0), paint);
      canvas.drawLine(sc.translate(0, -s), sc.translate(0, s), paint);
      canvas.drawLine(sc.translate(-s * 0.6, -s * 0.6),
          sc.translate(s * 0.6, s * 0.6), paint);
      canvas.drawLine(sc.translate(s * 0.6, -s * 0.6),
          sc.translate(-s * 0.6, s * 0.6), paint);
    }
  }

  @override
  bool shouldRepaint(_SparklesPainter old) => old.progress != progress;
}

class _DexCardContent extends StatefulWidget {
  const _DexCardContent({required this.card, required this.onDelete});

  final DexCardData card;
  final VoidCallback onDelete;

  @override
  State<_DexCardContent> createState() => _DexCardContentState();
}

class _DexCardContentState extends State<_DexCardContent> {
  String? _placeName;

  @override
  void initState() {
    super.initState();
    _reverseGeocode();
  }

  Future<void> _reverseGeocode() async {
    final lat = widget.card.caught.latitude;
    final lng = widget.card.caught.longitude;
    if (lat == null || lng == null) return;
    final name = await GeocodingService.instance.getPlaceName(lat, lng);
    if (name != null && mounted) setState(() => _placeName = name);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final rarity = card.rarity;

    return Column(
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
                        // Card thumbnail is ~90px tall — decoding the full
                        // multi-megapixel camera photo here is pure waste
                        // and is the main source of grid scroll jank,
                        // especially on lower-end devices. Capping the
                        // decode target size means the image decoder does
                        // far less work per card, while still looking
                        // sharp at this display size (2x for device
                        // pixel ratio headroom).
                        cacheWidth: 220,
                        cacheHeight: 220,
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
                  onTap: widget.onDelete,
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
        Expanded(
          child: Padding(
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
                        _placeName ?? 'Location unavailable',
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
                const Spacer(),
                const Divider(color: borderColor, height: 1),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.track_changes,
                        label: '${card.confidencePercent}%',
                        color: green600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.bolt,
                        label: '+${card.xpReward} XP',
                        color: amber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: surface2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
