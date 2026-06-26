// ─────────────────────────────────────────────────────────────────────────────
// daily_quest.dart  —  PlantoDex
//
// Data model + hardcoded pool of daily quests.
//
// How it works:
//   • A small pool of DailyQuest definitions (kDailyQuestPool).
//   • One quest is picked deterministically for "today" based on the date,
//     so it's stable for everyone all day and rotates day to day.
//   • Progress is measured only against today's catches (passed in from
//     HomeProvider) — it resets naturally at midnight since "today" changes.
//   • Reuses QuestFilter from seasonal_quest.dart so progress-counting logic
//     stays in one place.
// ─────────────────────────────────────────────────────────────────────────────

import '../models/caught_plant.dart';
import '../models/seasonal_quest.dart' show QuestFilter;

// ── Core model ────────────────────────────────────────────────────────────────

class DailyQuest {
  const DailyQuest({
    required this.title,
    required this.description,
    required this.count,
    required this.badgeEmoji,
    required this.bonusXp,
    this.filter = QuestFilter.any,
    this.rarity,
    this.familyFragment,
  });

  /// Short headline shown in the card (e.g. "Catch 3 Plants").
  final String title;

  /// Longer hint shown below the title.
  final String description;

  /// How many qualifying catches today are needed.
  final int count;

  /// Emoji shown next to the quest.
  final String badgeEmoji;

  /// Bonus XP awarded on completion (display only — award in your XP logic).
  final int bonusXp;

  /// How to filter catches when counting progress.
  final QuestFilter filter;

  /// Required when [filter] == QuestFilter.rarity. Case-insensitive.
  final String? rarity;

  /// Required when [filter] == QuestFilter.family. Matched with contains().
  final String? familyFragment;
}

// ── Progress view ─────────────────────────────────────────────────────────────

class DailyQuestProgress {
  const DailyQuestProgress({
    required this.quest,
    required this.current,
  });

  final DailyQuest quest;

  /// How many qualifying catches the user already has today.
  final int current;

  bool get completed => current >= quest.count;

  /// 0.0 – 1.0 clamped fraction for the progress bar.
  double get fraction => (current / quest.count).clamp(0.0, 1.0);
}

// ── Quest pool ─────────────────────────────────────────────────────────────────
//
// Add or edit quests freely. One is picked per day based on the date, so the
// pool size doesn't need to divide evenly into anything — it just rotates.

const List<DailyQuest> kDailyQuestPool = [
  DailyQuest(
    title: 'Quick Scan',
    description: 'Catch any 3 plants today.',
    count: 3,
    badgeEmoji: '🌿',
    bonusXp: 20,
    filter: QuestFilter.any,
  ),
  DailyQuest(
    title: 'Double Up',
    description: 'Catch any 5 plants today.',
    count: 5,
    badgeEmoji: '🌱',
    bonusXp: 35,
    filter: QuestFilter.any,
  ),
  DailyQuest(
    title: 'On the Move',
    description: 'Catch plants in 2 different locations today.',
    count: 2,
    badgeEmoji: '🗺️',
    bonusXp: 30,
    filter: QuestFilter.distinctLocations,
  ),
  DailyQuest(
    title: 'Spread Out',
    description: 'Catch plants in 3 different locations today.',
    count: 3,
    badgeEmoji: '🗺️',
    bonusXp: 45,
    filter: QuestFilter.distinctLocations,
  ),
  DailyQuest(
    title: 'Rare Sighting',
    description: 'Find 1 Rare or better plant today.',
    count: 1,
    badgeEmoji: '💜',
    bonusXp: 40,
    filter: QuestFilter.rarity,
    rarity: 'rare',
  ),
  DailyQuest(
    title: 'Epic Effort',
    description: 'Find 1 Epic or better plant today.',
    count: 1,
    badgeEmoji: '🌸',
    bonusXp: 60,
    filter: QuestFilter.rarity,
    rarity: 'epic',
  ),
  DailyQuest(
    title: 'Orchid Check',
    description: 'Find a plant from the Orchidaceae family today.',
    count: 1,
    badgeEmoji: '🌺',
    bonusXp: 35,
    filter: QuestFilter.family,
    familyFragment: 'orchid',
  ),
];

// ── Today's quest + progress helpers ───────────────────────────────────────────

/// Returns the quest for "today", picked deterministically from the pool
/// so it's stable across the whole day and rotates day to day.
DailyQuest dailyQuestForToday() {
  final now = DateTime.now();
  // Day-of-year is a simple, stable seed — doesn't depend on month length
  // quirks and naturally rotates every single day.
  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
  final index = dayOfYear % kDailyQuestPool.length;
  return kDailyQuestPool[index];
}

/// Computes [DailyQuestProgress] for [quest], given today's catches and a
/// set of distinct location keys for today.
///
/// [todayCatches]    — catches where caughtAtDate is today.
/// [distinctLocKeys] — set of '${lat*100},${lng*100}' strings for today.
DailyQuestProgress computeDailyQuestProgress({
  required DailyQuest quest,
  required List<CaughtPlant> todayCatches,
  required Set<String> distinctLocKeys,
}) {
  final int current;

  switch (quest.filter) {
    case QuestFilter.any:
      current = todayCatches.length.clamp(0, quest.count);

    case QuestFilter.rarity:
      final rarityRank = _rarityRank(quest.rarity ?? '');
      current = todayCatches
          .where((p) => _rarityRank(p.rarity) >= rarityRank)
          .length
          .clamp(0, quest.count);

    case QuestFilter.family:
      final fragment = (quest.familyFragment ?? '').toLowerCase();
      current = todayCatches
          .where((p) => p.family.toLowerCase().contains(fragment))
          .length
          .clamp(0, quest.count);

    case QuestFilter.distinctLocations:
      current = distinctLocKeys.length.clamp(0, quest.count);
  }

  return DailyQuestProgress(quest: quest, current: current);
}

int _rarityRank(String rarity) => switch (rarity.toLowerCase()) {
      'legendary' => 3,
      'epic' => 2,
      'rare' => 1,
      _ => 0,
    };
