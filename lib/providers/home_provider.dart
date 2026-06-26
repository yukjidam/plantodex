import 'package:flutter/foundation.dart';
import '../models/caught_plant.dart';
import '../models/daily_quest.dart';
import '../models/seasonal_quest.dart';
import '../repositories/plant_repository.dart';
import '../services/geocoding_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// home_provider.dart  —  PlantoDex
//
// XP weights and streak logic mirror profile_screen.dart exactly.
// Badge logic uses the same _badges list & predicates via a shared import
// — if you later extract those to a separate file, update the import here.
// ─────────────────────────────────────────────────────────────────────────────

// ── XP weights (must stay in sync with profile_screen.dart) ──────────────────
int _xpForRarity(String rarity) => switch (rarity) {
      'legendary' => 150,
      'rare' => 60,
      'epic' => 30,
      _ => 10,
    };

// ── Level thresholds (must stay in sync with profile_screen.dart) ─────────────
const _levelThresholds = [
  0,
  100,
  250,
  500,
  1000,
  1800,
  3000,
  4500,
  6500,
  9000,
];

const _levelTitles = [
  'Seedling',
  'Sprout',
  'Tender',
  'Herbalist',
  'Field Scout',
  'Naturalist',
  'Botanist',
  'Flora Sage',
  'Grove Keeper',
  'Legendary Warden',
];

int _computeLevel(int totalXp) {
  int level = 1;
  for (int i = 1; i < _levelThresholds.length; i++) {
    if (totalXp >= _levelThresholds[i]) {
      level = i + 1;
    } else {
      break;
    }
  }
  return level.clamp(1, 10);
}

// ── Streak (must stay in sync with profile_screen.dart) ───────────────────────
({int current, int best}) _computeStreaks(List<DateTime> dates) {
  if (dates.isEmpty) return (current: 0, best: 0);

  final days = dates
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet()
      .toList()
    ..sort();

  int best = 1;
  int run = 1;
  for (int i = 1; i < days.length; i++) {
    final diff = days[i].difference(days[i - 1]).inDays;
    if (diff == 1) {
      run++;
      if (run > best) best = run;
    } else if (diff > 1) {
      run = 1;
    }
  }

  final today = DateTime.now();
  final todayDay = DateTime(today.year, today.month, today.day);
  final yesterdayDay = todayDay.subtract(const Duration(days: 1));

  int current = 0;
  if (days.last == todayDay || days.last == yesterdayDay) {
    current = 1;
    for (int i = days.length - 2; i >= 0; i--) {
      if (days[i + 1].difference(days[i]).inDays == 1) {
        current++;
      } else {
        break;
      }
    }
  }

  return (current: current, best: best);
}

// ── Badge definitions (subset used for "next badge" nudge) ────────────────────
// Mirrors the order in profile_screen.dart so the "next" badge is the same
// one the user would see as locked first in the Profile badge grid.

class _BadgeCheck {
  const _BadgeCheck({
    required this.emoji,
    required this.name,
    required this.hintText,
    required this.unlocked,
    required this.current,
    required this.target,
  });
  final String emoji;
  final String name;
  final String hintText;
  final bool unlocked;
  final int current;
  final int target;
}

List<_BadgeCheck> _evaluateBadges({
  required int totalCaught,
  required int rareCount,
  required int epicCount,
  required int legendaryCount,
  required int currentStreak,
  required int bestStreak,
  required Set<String> families,
  required int distinctLocationCount,
}) {
  int clamp(int v, int t) => v.clamp(0, t);

  return [
    _BadgeCheck(
      emoji: '🌱',
      name: 'First Catch',
      hintText: 'Catch your first plant',
      unlocked: totalCaught >= 1,
      current: clamp(totalCaught, 1),
      target: 1,
    ),
    _BadgeCheck(
      emoji: '🌿',
      name: 'Collector',
      hintText: 'Catch 10 plants',
      unlocked: totalCaught >= 10,
      current: clamp(totalCaught, 10),
      target: 10,
    ),
    _BadgeCheck(
      emoji: '🌿',
      name: 'Botanist',
      hintText: 'Catch 50 plants',
      unlocked: totalCaught >= 50,
      current: clamp(totalCaught, 50),
      target: 50,
    ),
    _BadgeCheck(
      emoji: '🌿',
      name: 'Centurion',
      hintText: 'Catch 100 plants',
      unlocked: totalCaught >= 100,
      current: clamp(totalCaught, 100),
      target: 100,
    ),
    _BadgeCheck(
      emoji: '💜',
      name: 'Rare Find',
      hintText: 'Catch your first Rare plant',
      unlocked: rareCount >= 1,
      current: clamp(rareCount, 1),
      target: 1,
    ),
    _BadgeCheck(
      emoji: '🔥',
      name: 'Legendary',
      hintText: 'Catch your first Legendary plant',
      unlocked: legendaryCount >= 1,
      current: clamp(legendaryCount, 1),
      target: 1,
    ),
    _BadgeCheck(
      emoji: '🔥',
      name: 'Legend Keeper',
      hintText: 'Catch 5 Legendary plants',
      unlocked: legendaryCount >= 5,
      current: clamp(legendaryCount, 5),
      target: 5,
    ),
    _BadgeCheck(
      emoji: '🗓️',
      name: '3-Day Streak',
      hintText: 'Scan plants 3 days in a row',
      unlocked: bestStreak >= 3,
      current: clamp(bestStreak, 3),
      target: 3,
    ),
    _BadgeCheck(
      emoji: '🗓️',
      name: '7-Day Streak',
      hintText: 'Scan plants 7 days in a row',
      unlocked: bestStreak >= 7,
      current: clamp(bestStreak, 7),
      target: 7,
    ),
    _BadgeCheck(
      emoji: '🗓️',
      name: '30-Day Streak',
      hintText: 'Scan plants 30 days in a row',
      unlocked: bestStreak >= 30,
      current: clamp(bestStreak, 30),
      target: 30,
    ),
    _BadgeCheck(
      emoji: '🌸',
      name: 'Orchid Badge',
      hintText: 'Catch a plant from the Orchidaceae family',
      unlocked: families.any((f) => f.toLowerCase().contains('orchid')),
      current: families.any((f) => f.toLowerCase().contains('orchid')) ? 1 : 0,
      target: 1,
    ),
    _BadgeCheck(
      emoji: '🌿',
      name: 'Spore Badge',
      hintText: 'Catch a fern',
      unlocked: families.any((f) {
        final l = f.toLowerCase();
        return l.contains('polypodiaceae') ||
            l.contains('pteridaceae') ||
            l.contains('aspleniaceae') ||
            l.contains('dennstaedtiaceae');
      }),
      current: 0,
      target: 1,
    ),
    _BadgeCheck(
      emoji: '🌍',
      name: 'World Badge',
      hintText: 'Catch plants from 3 different families',
      unlocked: families.length >= 3,
      current: clamp(families.length, 3),
      target: 3,
    ),
    _BadgeCheck(
      emoji: '🗺️',
      name: 'Explorer',
      hintText: 'Catch plants in 3 different locations',
      unlocked: distinctLocationCount >= 3,
      current: clamp(distinctLocationCount, 3),
      target: 3,
    ),
  ];
}

// ── Recent spot model ─────────────────────────────────────────────────────────

class RecentSpot {
  RecentSpot({required this.label, required this.plantCount});
  final String label;
  final int plantCount;
}

// ── Provider ──────────────────────────────────────────────────────────────────

class HomeProvider extends ChangeNotifier {
  HomeProvider({PlantRepository? repository})
      : _repo = repository ?? PlantRepository.instance;

  final PlantRepository _repo;

  // ── Loading state ─────────────────────────────────────────────────────────

  bool _loading = true;
  bool get loading => _loading;

  // ── Raw data ──────────────────────────────────────────────────────────────

  List<CaughtPlant> _allCatches = [];

  // ── Today ─────────────────────────────────────────────────────────────────

  List<CaughtPlant> get todayCatches {
    final today = DateTime.now();
    return _allCatches.where((p) {
      final d = p.caughtAtDate;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).toList();
  }

  int get todayCatchCount => todayCatches.length;

  int get todayXp =>
      todayCatches.fold(0, (sum, p) => sum + _xpForRarity(p.rarity));

  int get totalCatchCount => _allCatches.length;

  // ── Rarity breakdown ──────────────────────────────────────────────────────

  int get commonCount =>
      _allCatches.where((p) => p.rarity.toLowerCase() == 'common').length;
  int get rareCount =>
      _allCatches.where((p) => p.rarity.toLowerCase() == 'rare').length;
  int get epicCount =>
      _allCatches.where((p) => p.rarity.toLowerCase() == 'epic').length;
  int get legendaryCount =>
      _allCatches.where((p) => p.rarity.toLowerCase() == 'legendary').length;

  // ── Collection summary ────────────────────────────────────────────────────

  Set<String> get families =>
      _allCatches.map((p) => p.family).where((f) => f.isNotEmpty).toSet();

  String get topFamily {
    if (_allCatches.isEmpty) return '';
    final freq = <String, int>{};
    for (final p in _allCatches) {
      if (p.family.isNotEmpty) freq[p.family] = (freq[p.family] ?? 0) + 1;
    }
    if (freq.isEmpty) return '';
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ── Streak ────────────────────────────────────────────────────────────────

  int get currentStreak {
    final dates = _allCatches.map((p) => p.caughtAtDate).toList();
    return _computeStreaks(dates).current;
  }

  int get bestStreak {
    final dates = _allCatches.map((p) => p.caughtAtDate).toList();
    return _computeStreaks(dates).best;
  }

  // ── Level / XP ────────────────────────────────────────────────────────────

  int get totalXp =>
      _allCatches.fold(0, (sum, p) => sum + _xpForRarity(p.rarity));

  int get level => _computeLevel(totalXp);

  String get levelTitle => _levelTitles[(level - 1).clamp(0, 9)];

  // ── Next badge ────────────────────────────────────────────────────────────

  /// The first badge in the canonical order that the user hasn't unlocked yet.
  _BadgeCheck? get _nextBadgeCheck {
    final distinctLocations = <String>{};
    for (final p in _allCatches) {
      if (p.latitude != null && p.longitude != null) {
        distinctLocations.add(
            '${(p.latitude! * 100).round()},${(p.longitude! * 100).round()}');
      }
    }

    final checks = _evaluateBadges(
      totalCaught: totalCatchCount,
      rareCount: rareCount,
      epicCount: epicCount,
      legendaryCount: legendaryCount,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      families: families,
      distinctLocationCount: distinctLocations.length,
    );

    try {
      return checks.firstWhere((b) => !b.unlocked);
    } catch (_) {
      return null; // all badges unlocked
    }
  }

  String get nextBadgeEmoji => _nextBadgeCheck?.emoji ?? '🏆';
  String get nextBadgeName => _nextBadgeCheck?.name ?? 'All badges unlocked!';
  String get nextBadgeHint => _nextBadgeCheck?.hintText ?? '';
  int get nextBadgeCurrent => _nextBadgeCheck?.current ?? 0;
  int get nextBadgeTarget => _nextBadgeCheck?.target ?? 1;
  double get nextBadgeProgress =>
      nextBadgeTarget == 0 ? 1.0 : nextBadgeCurrent / nextBadgeTarget;

  // ── Last catch ────────────────────────────────────────────────────────────

  CaughtPlant? get lastCatch {
    if (_allCatches.isEmpty) return null;
    return _allCatches.reduce((a, b) => a.caughtAt >= b.caughtAt ? a : b);
  }

  // ── Recent spots (reverse-geocoded) ──────────────────────────────────────

  List<RecentSpot> _recentSpots = [];
  List<RecentSpot> get recentSpots => _recentSpots;

  Future<void> _resolveRecentSpots() async {
    // Group catches by ~1 km cell.
    final cellCatches = <String, List<CaughtPlant>>{};
    for (final plant in _allCatches) {
      final key = plant.latitude != null && plant.longitude != null
          ? '${(plant.latitude! * 100).round()},${(plant.longitude! * 100).round()}'
          : '__no_gps__';
      (cellCatches[key] ??= []).add(plant);
    }

    // Sort cells by catch count descending, take top 3.
    final sorted = cellCatches.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final top = sorted.take(3).toList();
    final spots = <RecentSpot>[];

    for (final entry in top) {
      final rep = entry.value.first; // representative plant for geocoding
      String label;

      if (rep.latitude != null && rep.longitude != null) {
        label = await GeocodingService.instance
                .getPlaceName(rep.latitude!, rep.longitude!) ??
            '${rep.latitude!.toStringAsFixed(2)}, ${rep.longitude!.toStringAsFixed(2)}';
      } else {
        label = 'Unknown location';
      }

      spots.add(RecentSpot(label: label, plantCount: entry.value.length));
    }

    _recentSpots = spots;
    notifyListeners();
  }

  // ── Seasonal quest helpers ────────────────────────────────────────────────

  /// Catches that happened in the current calendar month.
  List<CaughtPlant> get _monthlyCatches {
    final now = DateTime.now();
    return _allCatches.where((p) {
      final d = p.caughtAtDate;
      return d.year == now.year && d.month == now.month;
    }).toList();
  }

  /// Distinct ~1 km GPS cells seen this month (same grid as recentSpots).
  Set<String> get _monthlyLocKeys {
    final keys = <String>{};
    for (final p in _monthlyCatches) {
      if (p.latitude != null && p.longitude != null) {
        keys.add(
            '${(p.latitude! * 100).round()},${(p.longitude! * 100).round()}');
      }
    }
    return keys;
  }

  // ── Public getters consumed by home_screen.dart ───────────────────────────

  /// The episode for the current calendar month.
  SeasonalEpisode get activeEpisode => currentEpisode();

  /// Full progress list — one entry per quest, in order.
  List<QuestProgress> get questProgressList => computeQuestProgress(
        episode: activeEpisode,
        monthlyCatches: _monthlyCatches,
        distinctLocKeys: _monthlyLocKeys,
      );

  /// The first quest that isn't completed yet (null if all done).
  QuestProgress? get activeQuest {
    try {
      return questProgressList.firstWhere((qp) => !qp.completed);
    } catch (_) {
      return null;
    }
  }

  /// How many quests in the current episode are fully completed.
  int get completedQuestCount =>
      questProgressList.where((qp) => qp.completed).length;

  /// Countdown string to end of current month (used in the card timer).
  String get resetCountdown {
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(seconds: 1));
    final diff = endOfMonth.difference(now);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ${diff.inHours.remainder(24)}h';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
    return '${diff.inMinutes}m';
  }

  // ── Daily quest helpers ───────────────────────────────────────────────────

  /// Distinct ~1 km GPS cells seen today (same grid as recentSpots).
  Set<String> get _todayLocKeys {
    final keys = <String>{};
    for (final p in todayCatches) {
      if (p.latitude != null && p.longitude != null) {
        keys.add(
            '${(p.latitude! * 100).round()},${(p.longitude! * 100).round()}');
      }
    }
    return keys;
  }

  /// The quest picked for today, rotating from the pool by date.
  DailyQuest get todayQuest => dailyQuestForToday();

  /// Progress on today's quest.
  DailyQuestProgress get dailyQuestProgress => computeDailyQuestProgress(
        quest: todayQuest,
        todayCatches: todayCatches,
        distinctLocKeys: _todayLocKeys,
      );

  // ── Load / refresh ────────────────────────────────────────────────────────

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    _allCatches = await _repo.getAllCatches();
    _loading = false;
    notifyListeners(); // paint screen immediately with sync data

    // Geocoding runs after the first paint — labels update when ready.
    _resolveRecentSpots();
  }

  Future<void> refresh() => load();
}
