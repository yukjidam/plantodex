// ─────────────────────────────────────────────────────────────────────────────
// seasonal_quest.dart  —  PlantoDex
//
// Data model + hardcoded episode catalogue.
//
// How it works:
//   • One SeasonalEpisode per calendar month, keyed by month number (1–12).
//   • Each episode has a list of SeasonalQuests.
//   • Quests unlock one at a time: complete quest N → quest N+1 becomes active.
//   • Progress is measured against CaughtPlant data passed in from HomeProvider.
//   • QuestProgress is a computed view — nothing is persisted separately;
//     the source of truth is always the plant repository.
// ─────────────────────────────────────────────────────────────────────────────

import '../models/caught_plant.dart';

// ── Quest filter types ────────────────────────────────────────────────────────

/// What kind of catch satisfies this quest.
enum QuestFilter {
  /// Any plant counts.
  any,

  /// Only plants whose rarity matches [rarity].
  rarity,

  /// Only plants whose family contains [familyFragment] (case-insensitive).
  family,

  /// Only plants caught at distinct GPS cells (~1 km grid).
  distinctLocations,
}

// ── Core model ────────────────────────────────────────────────────────────────

class SeasonalQuest {
  const SeasonalQuest({
    required this.title,
    required this.description,
    required this.count,
    required this.badgeEmoji,
    required this.badgeName,
    required this.bonusXp,
    this.filter = QuestFilter.any,
    this.rarity,
    this.familyFragment,
  });

  /// Short headline shown in the card (e.g. "Catch 5 Plants").
  final String title;

  /// Longer hint shown below the title.
  final String description;

  /// How many qualifying catches are needed.
  final int count;

  /// Emoji shown next to the reward badge name.
  final String badgeEmoji;

  /// Name of the reward badge.
  final String badgeName;

  /// Bonus XP awarded on completion (display only — award in your XP logic).
  final int bonusXp;

  /// How to filter catches when counting progress.
  final QuestFilter filter;

  /// Required when [filter] == QuestFilter.rarity. Case-insensitive.
  final String? rarity;

  /// Required when [filter] == QuestFilter.family. Matched with contains().
  final String? familyFragment;
}

// ── Episode (one per month) ───────────────────────────────────────────────────

class SeasonalEpisode {
  const SeasonalEpisode({
    required this.month,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.quests,
  });

  /// Calendar month number (1 = January … 12 = December).
  final int month;
  final String emoji;

  /// Bold headline in the card header (e.g. "Episode 1 · Sprout Season").
  final String title;

  /// Smaller tagline below the title.
  final String subtitle;

  /// Ordered list of quests; they unlock sequentially.
  final List<SeasonalQuest> quests;
}

// ── Progress view ─────────────────────────────────────────────────────────────

class QuestProgress {
  const QuestProgress({
    required this.quest,
    required this.current,
  });

  final SeasonalQuest quest;

  /// How many qualifying catches the user already has this month.
  final int current;

  bool get completed => current >= quest.count;

  /// 0.0 – 1.0 clamped fraction for the progress bar.
  double get fraction => (current / quest.count).clamp(0.0, 1.0);
}

// ── Episode catalogue ─────────────────────────────────────────────────────────
//
// Add or edit episodes freely. The UI reads whatever is here.
// To add a new month: copy an entry, change `month`, and fill in fresh quests.

const List<SeasonalEpisode> kSeasonalEpisodes = [
  // ── January ──────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 1,
    emoji: '❄️',
    title: 'Episode 1 · Frost Walkers',
    subtitle: 'Cold mornings hide the rarest finds.',
    quests: [
      SeasonalQuest(
        title: 'First Steps',
        description: 'Catch any 3 plants this month to get started.',
        count: 3,
        badgeEmoji: '🌱',
        badgeName: 'Frost Starter',
        bonusXp: 50,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Winter Explorer',
        description: 'Scan plants in 2 different locations.',
        count: 2,
        badgeEmoji: '🗺️',
        badgeName: 'Winter Roamer',
        bonusXp: 80,
        filter: QuestFilter.distinctLocations,
      ),
      SeasonalQuest(
        title: 'Rare in the Cold',
        description: 'Find 1 Rare or better plant braving the frost.',
        count: 1,
        badgeEmoji: '💜',
        badgeName: 'Frost Rare',
        bonusXp: 120,
        filter: QuestFilter.rarity,
        rarity: 'rare',
      ),
    ],
  ),

  // ── February ─────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 2,
    emoji: '🌸',
    title: 'Episode 2 · Bloom Seekers',
    subtitle: 'Early blossoms are appearing — go find them.',
    quests: [
      SeasonalQuest(
        title: 'Petal Patrol',
        description: 'Catch any 5 plants this month.',
        count: 5,
        badgeEmoji: '🌸',
        badgeName: 'Petal Scout',
        bonusXp: 60,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Orchid Hunter',
        description: 'Find a plant from the Orchidaceae family.',
        count: 1,
        badgeEmoji: '🌺',
        badgeName: 'Orchid Badge',
        bonusXp: 100,
        filter: QuestFilter.family,
        familyFragment: 'orchid',
      ),
      SeasonalQuest(
        title: 'Epic February',
        description: 'Catch 1 Epic or better plant.',
        count: 1,
        badgeEmoji: '🌸',
        badgeName: 'Epic Bloom',
        bonusXp: 150,
        filter: QuestFilter.rarity,
        rarity: 'epic',
      ),
    ],
  ),

  // ── March ────────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 3,
    emoji: '🌿',
    title: 'Episode 3 · Green Surge',
    subtitle: 'Spring is pushing through everywhere.',
    quests: [
      SeasonalQuest(
        title: 'Spring Sprinter',
        description: 'Catch 7 plants this month.',
        count: 7,
        badgeEmoji: '🌿',
        badgeName: 'Green Surge',
        bonusXp: 70,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Fern Finder',
        description: 'Find a fern (Polypodiaceae, Pteridaceae, etc.).',
        count: 1,
        badgeEmoji: '🌿',
        badgeName: 'Spore Badge',
        bonusXp: 90,
        filter: QuestFilter.family,
        familyFragment: 'polypodiaceae',
      ),
      SeasonalQuest(
        title: 'Tri-Hunter',
        description: 'Catch plants from 3 different locations.',
        count: 3,
        badgeEmoji: '🗺️',
        badgeName: 'Spring Explorer',
        bonusXp: 130,
        filter: QuestFilter.distinctLocations,
      ),
    ],
  ),

  // ── April ────────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 4,
    emoji: '🌦️',
    title: 'Episode 4 · April Showers',
    subtitle: 'Rain brings out the best specimens.',
    quests: [
      SeasonalQuest(
        title: 'Rainy Day Run',
        description: 'Catch any 5 plants this month.',
        count: 5,
        badgeEmoji: '🌦️',
        badgeName: 'Rain Scout',
        bonusXp: 60,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Rare Rain',
        description: 'Spot 2 Rare plants hiding in the wet.',
        count: 2,
        badgeEmoji: '💜',
        badgeName: 'Rain Rare',
        bonusXp: 110,
        filter: QuestFilter.rarity,
        rarity: 'rare',
      ),
      SeasonalQuest(
        title: 'Storm Chaser',
        description: 'Catch plants across 4 different locations.',
        count: 4,
        badgeEmoji: '🗺️',
        badgeName: 'Storm Badge',
        bonusXp: 160,
        filter: QuestFilter.distinctLocations,
      ),
    ],
  ),

  // ── May ──────────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 5,
    emoji: '☀️',
    title: 'Episode 5 · Solar Scouts',
    subtitle: 'Long days mean longer hunts.',
    quests: [
      SeasonalQuest(
        title: 'Sun Seeker',
        description: 'Catch any 8 plants this month.',
        count: 8,
        badgeEmoji: '☀️',
        badgeName: 'Solar Scout',
        bonusXp: 80,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Rose Ranger',
        description: 'Find a plant from the Rosaceae family.',
        count: 1,
        badgeEmoji: '🌹',
        badgeName: 'Rose Badge',
        bonusXp: 100,
        filter: QuestFilter.family,
        familyFragment: 'rosaceae',
      ),
      SeasonalQuest(
        title: 'Legendary Noon',
        description: 'Catch 1 Legendary plant under the summer sun.',
        count: 1,
        badgeEmoji: '🔥',
        badgeName: 'Solar Legend',
        bonusXp: 200,
        filter: QuestFilter.rarity,
        rarity: 'legendary',
      ),
    ],
  ),

  // ── June ─────────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 6,
    emoji: '🌻',
    title: 'Episode 6 · Midsummer Hunt',
    subtitle: 'Peak growing season — everything is out.',
    quests: [
      SeasonalQuest(
        title: 'High Noon',
        description: 'Catch any 10 plants this month.',
        count: 10,
        badgeEmoji: '🌻',
        badgeName: 'Midsummer Scout',
        bonusXp: 90,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Daisy Dash',
        description: 'Find a plant from the Asteraceae (daisy) family.',
        count: 1,
        badgeEmoji: '🌼',
        badgeName: 'Daisy Badge',
        bonusXp: 110,
        filter: QuestFilter.family,
        familyFragment: 'asteraceae',
      ),
      SeasonalQuest(
        title: 'Epic Summer',
        description: 'Catch 2 Epic plants this month.',
        count: 2,
        badgeEmoji: '🌸',
        badgeName: 'Summer Epic',
        bonusXp: 180,
        filter: QuestFilter.rarity,
        rarity: 'epic',
      ),
    ],
  ),

  // ── July ─────────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 7,
    emoji: '🔥',
    title: 'Episode 7 · Heatwave',
    subtitle: 'Only the bold venture out in the heat.',
    quests: [
      SeasonalQuest(
        title: 'Heat Endurance',
        description: 'Catch any 8 plants despite the heat.',
        count: 8,
        badgeEmoji: '🔥',
        badgeName: 'Heat Seeker',
        bonusXp: 80,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Desert Rose',
        description: 'Catch plants in 5 different locations.',
        count: 5,
        badgeEmoji: '🗺️',
        badgeName: 'Heatwave Roamer',
        bonusXp: 140,
        filter: QuestFilter.distinctLocations,
      ),
      SeasonalQuest(
        title: 'Legendary Heat',
        description: 'Find a Legendary plant in the summer blaze.',
        count: 1,
        badgeEmoji: '🔥',
        badgeName: 'Heatwave Legend',
        bonusXp: 220,
        filter: QuestFilter.rarity,
        rarity: 'legendary',
      ),
    ],
  ),

  // ── August ───────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 8,
    emoji: '🍃',
    title: 'Episode 8 · Late Harvest',
    subtitle: 'The last big bloom before autumn.',
    quests: [
      SeasonalQuest(
        title: 'Harvest Rush',
        description: 'Catch any 10 plants this month.',
        count: 10,
        badgeEmoji: '🍃',
        badgeName: 'Harvest Scout',
        bonusXp: 90,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Legume Legacy',
        description: 'Find a plant from the Fabaceae (legume) family.',
        count: 1,
        badgeEmoji: '🌱',
        badgeName: 'Legume Badge',
        bonusXp: 110,
        filter: QuestFilter.family,
        familyFragment: 'fabaceae',
      ),
      SeasonalQuest(
        title: 'Rare Harvest',
        description: 'Catch 3 Rare plants before summer ends.',
        count: 3,
        badgeEmoji: '💜',
        badgeName: 'Harvest Rare',
        bonusXp: 170,
        filter: QuestFilter.rarity,
        rarity: 'rare',
      ),
    ],
  ),

  // ── September ─────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 9,
    emoji: '🍂',
    title: 'Episode 9 · Autumn Drift',
    subtitle: 'Colours are changing — so are the plants.',
    quests: [
      SeasonalQuest(
        title: 'Leaf Peeper',
        description: 'Catch any 7 plants this month.',
        count: 7,
        badgeEmoji: '🍂',
        badgeName: 'Autumn Scout',
        bonusXp: 70,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Maple Seeker',
        description: 'Find a plant from the Sapindaceae (maple) family.',
        count: 1,
        badgeEmoji: '🍁',
        badgeName: 'Maple Badge',
        bonusXp: 100,
        filter: QuestFilter.family,
        familyFragment: 'sapindaceae',
      ),
      SeasonalQuest(
        title: 'Fall Expedition',
        description: 'Catch plants across 4 different locations.',
        count: 4,
        badgeEmoji: '🗺️',
        badgeName: 'Autumn Explorer',
        bonusXp: 150,
        filter: QuestFilter.distinctLocations,
      ),
    ],
  ),

  // ── October ───────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 10,
    emoji: '🎃',
    title: 'Episode 10 · Witching Weeds',
    subtitle: 'Spooky season, spooky plants.',
    quests: [
      SeasonalQuest(
        title: 'Trick or Treat',
        description: 'Catch any 5 plants this month.',
        count: 5,
        badgeEmoji: '🎃',
        badgeName: 'Witching Scout',
        bonusXp: 60,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Nightshade Seeker',
        description: 'Find a plant from the Solanaceae (nightshade) family.',
        count: 1,
        badgeEmoji: '🌑',
        badgeName: 'Nightshade Badge',
        bonusXp: 120,
        filter: QuestFilter.family,
        familyFragment: 'solanaceae',
      ),
      SeasonalQuest(
        title: 'Legendary Haunt',
        description: 'Catch 1 Legendary plant under the harvest moon.',
        count: 1,
        badgeEmoji: '🔥',
        badgeName: 'Haunt Legend',
        bonusXp: 200,
        filter: QuestFilter.rarity,
        rarity: 'legendary',
      ),
    ],
  ),

  // ── November ──────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 11,
    emoji: '🍁',
    title: 'Episode 11 · Last Leaves',
    subtitle: 'Bare branches reveal what was hidden.',
    quests: [
      SeasonalQuest(
        title: 'Last Harvest',
        description: 'Catch any 6 plants before winter.',
        count: 6,
        badgeEmoji: '🍁',
        badgeName: 'Last Leaf',
        bonusXp: 65,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Fungi Seeker',
        description: 'Find a plant from the Agaricaceae (mushroom) family.',
        count: 1,
        badgeEmoji: '🍄',
        badgeName: 'Fungi Badge',
        bonusXp: 110,
        filter: QuestFilter.family,
        familyFragment: 'agaricaceae',
      ),
      SeasonalQuest(
        title: 'Epic November',
        description: 'Catch 2 Epic plants in the fading light.',
        count: 2,
        badgeEmoji: '🌸',
        badgeName: 'November Epic',
        bonusXp: 160,
        filter: QuestFilter.rarity,
        rarity: 'epic',
      ),
    ],
  ),

  // ── December ──────────────────────────────────────────────────────────────
  SeasonalEpisode(
    month: 12,
    emoji: '🎄',
    title: 'Episode 12 · Winter Finale',
    subtitle: 'End the year with your rarest find yet.',
    quests: [
      SeasonalQuest(
        title: 'Year-End Rush',
        description: 'Catch any 5 plants to close the year.',
        count: 5,
        badgeEmoji: '🎄',
        badgeName: 'Year-End Scout',
        bonusXp: 60,
        filter: QuestFilter.any,
      ),
      SeasonalQuest(
        title: 'Holly Hunter',
        description: 'Find a plant from the Aquifoliaceae (holly) family.',
        count: 1,
        badgeEmoji: '🎋',
        badgeName: 'Holly Badge',
        bonusXp: 100,
        filter: QuestFilter.family,
        familyFragment: 'aquifoliaceae',
      ),
      SeasonalQuest(
        title: 'Legendary Finale',
        description: 'End the year with a Legendary catch.',
        count: 1,
        badgeEmoji: '🔥',
        badgeName: 'Finale Legend',
        bonusXp: 250,
        filter: QuestFilter.rarity,
        rarity: 'legendary',
      ),
    ],
  ),
];

// ── Episode + progress helpers ─────────────────────────────────────────────────

/// Returns the episode for the current calendar month.
/// Falls back to January if somehow nothing matches (should never happen).
SeasonalEpisode currentEpisode() {
  final month = DateTime.now().month;
  return kSeasonalEpisodes.firstWhere(
    (e) => e.month == month,
    orElse: () => kSeasonalEpisodes.first,
  );
}

/// Computes [QuestProgress] for every quest in [episode], given the catches
/// that happened **this month** and a set of distinct location keys.
///
/// [monthlyCatches]     — catches where caughtAtDate is in the current month.
/// [distinctLocKeys]    — set of '${lat*100},${lng*100}' strings (all-time or
///                        monthly — pass monthly for a fair monthly challenge).
List<QuestProgress> computeQuestProgress({
  required SeasonalEpisode episode,
  required List<CaughtPlant> monthlyCatches,
  required Set<String> distinctLocKeys,
}) {
  final result = <QuestProgress>[];
  bool previousCompleted = true; // first quest is always unlocked

  for (final quest in episode.quests) {
    // If the previous quest isn't done, this one shows 0 progress (locked).
    if (!previousCompleted) {
      result.add(QuestProgress(quest: quest, current: 0));
      continue;
    }

    final int current;

    switch (quest.filter) {
      case QuestFilter.any:
        current = monthlyCatches.length.clamp(0, quest.count);

      case QuestFilter.rarity:
        // For 'rare' quests, count rare + epic + legendary (cumulative).
        // For 'epic', count epic + legendary. For 'legendary', only legendary.
        final rarityRank = _rarityRank(quest.rarity ?? '');
        current = monthlyCatches
            .where((p) => _rarityRank(p.rarity) >= rarityRank)
            .length
            .clamp(0, quest.count);

      case QuestFilter.family:
        final fragment = (quest.familyFragment ?? '').toLowerCase();
        current = monthlyCatches
            .where((p) => p.family.toLowerCase().contains(fragment))
            .length
            .clamp(0, quest.count);

      case QuestFilter.distinctLocations:
        current = distinctLocKeys.length.clamp(0, quest.count);
    }

    final progress = QuestProgress(quest: quest, current: current);
    result.add(progress);
    previousCompleted = progress.completed;
  }

  return result;
}

int _rarityRank(String rarity) => switch (rarity.toLowerCase()) {
      'legendary' => 3,
      'epic' => 2,
      'rare' => 1,
      _ => 0,
    };
