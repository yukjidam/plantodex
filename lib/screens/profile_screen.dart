import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../database/app_database.dart';
import '../models/caught_plant.dart';
import '../repositories/plant_repository.dart';
import '../theme/colors.dart';
import 'home_screen.dart' show showHowToPlay;

// ─────────────────────────────────────────────────────────────────────────────
// XP + Level system
// ─────────────────────────────────────────────────────────────────────────────

int _xpForRarity(String rarity) => switch (rarity) {
      'legendary' => 150,
      'rare' => 60,
      'epic' => 30,
      _ => 10, // common
    };

const _levelThresholds = [
  0, // Lv 1  — Seedling
  100, // Lv 2  — Sprout
  250, // Lv 3  — Tender
  500, // Lv 4  — Herbalist
  1000, // Lv 5  — Field Scout
  1800, // Lv 6  — Naturalist
  3000, // Lv 7  — Botanist
  4500, // Lv 8  — Flora Sage
  6500, // Lv 9  — Grove Keeper
  9000, // Lv 10 — Legendary Warden
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

String _titleForLevel(int level) => _levelTitles[(level - 1).clamp(0, 9)];

({int current, int? nextThreshold}) _xpProgress(int totalXp, int level) {
  final currentFloor = _levelThresholds[(level - 1).clamp(0, 9)];
  if (level >= 10)
    return (current: totalXp - currentFloor, nextThreshold: null);
  final nextFloor = _levelThresholds[level];
  return (
    current: totalXp - currentFloor,
    nextThreshold: nextFloor - currentFloor,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge bonus XP — awarded once when a badge is first unlocked
// ─────────────────────────────────────────────────────────────────────────────

const _badgeBonusXp = <String, int>{
  'first_catch': 20,
  'collector_10': 50,
  'collector_50': 120,
  'collector_100': 250,
  'first_rare': 30,
  'first_legendary': 80,
  'legendary_5': 200,
  'streak_3': 20,
  'streak_7': 60,
  'streak_30': 200,
  'orchid': 25,
  'fern': 25,
  'world': 40,
  'explorer': 40,
};

/// Flavor toast text shown when a badge is first earned.
const _badgeFlavorText = <String, String>{
  'first_catch': 'Your botanical journey begins!',
  'collector_10': 'A true collector is emerging.',
  'collector_50': 'Half a century of catches. Respect.',
  'collector_100': 'One hundred plants. Legendary.',
  'first_rare': 'You have an eye for the rare.',
  'first_legendary': 'The forest chose you.',
  'legendary_5': 'Five legends bow to your skill.',
  'streak_3': 'Consistency is the root of mastery.',
  'streak_7': '7 days strong. Week Warrior!',
  'streak_30': 'A whole month. Incredible dedication.',
  'orchid': 'Orchid Expert — delicate and disciplined.',
  'fern': 'Ancient spores, fresh discovery.',
  'world': 'Three families, one true botanist.',
  'explorer': 'The world is your garden.',
};

// ─────────────────────────────────────────────────────────────────────────────
// XP Multiplier — streak_7 / streak_30 grant 1.5× for 7 days
// ─────────────────────────────────────────────────────────────────────────────

const _prefsMultiplierExpiryKey = 'profile_xp_multiplier_expiry_ms';
const double _xpMultiplierValue = 1.5;
const int _xpMultiplierDays = 7;

// ─────────────────────────────────────────────────────────────────────────────
// About / developer info
// ─────────────────────────────────────────────────────────────────────────────

const _githubUsername = 'yukjidam';
const _appVersion = '1.0.0';

/// Returns true when a stored multiplier expiry is still in the future.
bool _isMultiplierActive(SharedPreferences prefs) {
  final expiry = prefs.getInt(_prefsMultiplierExpiryKey) ?? 0;
  return DateTime.now().millisecondsSinceEpoch < expiry;
}

/// Grants the multiplier for [_xpMultiplierDays] days from now (idempotent —
/// only extends if the current expiry is in the past or within 1 day).
Future<void> _grantMultiplier(SharedPreferences prefs) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final expiry = prefs.getInt(_prefsMultiplierExpiryKey) ?? 0;
  final newExpiry =
      now + const Duration(days: _xpMultiplierDays).inMilliseconds;
  // Only extend if not already active (or less than 1 day remaining).
  if (expiry - now < const Duration(days: 1).inMilliseconds) {
    await prefs.setInt(_prefsMultiplierExpiryKey, newExpiry);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile flair tier — driven by total unlocked badge count
// ─────────────────────────────────────────────────────────────────────────────

enum _FlairTier { plain, vine, gold }

_FlairTier _flairForBadgeCount(int count) {
  if (count >= 10) return _FlairTier.gold;
  if (count >= 5) return _FlairTier.vine;
  return _FlairTier.plain;
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak computation
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Badge definitions
// ─────────────────────────────────────────────────────────────────────────────

enum BadgeTier { bronze, silver, gold }

/// Progress toward a milestone badge, e.g. current: 67, target: 100.
/// Null for badges that are purely boolean (discovery badges).
typedef BadgeProgress = ({int current, int target});

class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.emoji,
    required this.name,
    required this.tier,
    required this.unlockedWhen,
    required this.hintText,
    this.isDiscovery = false,
    this.progressFor,
  });

  final String id;
  final String emoji;
  final String name;
  final BadgeTier tier;
  final bool Function(_ProfileStats s) unlockedWhen;
  final String hintText;
  final bool isDiscovery;

  /// Returns current/target progress for milestone badges. Null means
  /// "don't show a progress bar" (used for discovery badges, where
  /// "progress" doesn't make conceptual sense).
  final BadgeProgress? Function(_ProfileStats s)? progressFor;
}

// Predicates must be top-level for const
bool _p_firstCatch(_ProfileStats s) => s.totalCaught >= 1;
bool _p_catch10(_ProfileStats s) => s.totalCaught >= 10;
bool _p_catch50(_ProfileStats s) => s.totalCaught >= 50;
bool _p_catch100(_ProfileStats s) => s.totalCaught >= 100;
bool _p_firstRare(_ProfileStats s) => s.rareCount >= 1;
bool _p_firstLegend(_ProfileStats s) => s.legendaryCount >= 1;
bool _p_legend5(_ProfileStats s) => s.legendaryCount >= 5;
bool _p_streak3(_ProfileStats s) => s.bestStreak >= 3;
bool _p_streak7(_ProfileStats s) => s.bestStreak >= 7;
bool _p_streak30(_ProfileStats s) => s.bestStreak >= 30;
bool _p_orchid(_ProfileStats s) =>
    s.families.any((f) => f.toLowerCase().contains('orchid'));
bool _p_fern(_ProfileStats s) => s.families.any((f) {
      final l = f.toLowerCase();
      return l.contains('polypodiaceae') ||
          l.contains('pteridaceae') ||
          l.contains('aspleniaceae') ||
          l.contains('dennstaedtiaceae');
    });
bool _p_world(_ProfileStats s) => s.families.length >= 3;
bool _p_explorer(_ProfileStats s) => s.distinctLocationCount >= 3;

// Progress functions — paired 1:1 with the milestone predicates above.
// Current values are clamped to target so a badge that's already
// unlocked never shows e.g. "143/100".
BadgeProgress _prog(int current, int target) =>
    (current: current.clamp(0, target), target: target);

const _badges = [
  BadgeDefinition(
    id: 'first_catch',
    emoji: '🌱',
    name: 'First Catch',
    tier: BadgeTier.gold,
    unlockedWhen: _p_firstCatch,
    hintText: 'Catch your first plant',
    progressFor: _progFirstCatch,
  ),
  BadgeDefinition(
    id: 'collector_10',
    emoji: '🌿',
    name: 'Collector',
    tier: BadgeTier.bronze,
    unlockedWhen: _p_catch10,
    hintText: 'Catch 10 plants',
    progressFor: _progCollector10,
  ),
  BadgeDefinition(
    id: 'collector_50',
    emoji: '🌿',
    name: 'Botanist',
    tier: BadgeTier.silver,
    unlockedWhen: _p_catch50,
    hintText: 'Catch 50 plants',
    progressFor: _progCollector50,
  ),
  BadgeDefinition(
    id: 'collector_100',
    emoji: '🌿',
    name: 'Centurion',
    tier: BadgeTier.gold,
    unlockedWhen: _p_catch100,
    hintText: 'Catch 100 plants',
    progressFor: _progCollector100,
  ),
  BadgeDefinition(
    id: 'first_rare',
    emoji: '💜',
    name: 'Rare Find',
    tier: BadgeTier.bronze,
    unlockedWhen: _p_firstRare,
    hintText: 'Catch your first Rare plant',
    progressFor: _progFirstRare,
  ),
  BadgeDefinition(
    id: 'first_legendary',
    emoji: '🔥',
    name: 'Legendary',
    tier: BadgeTier.silver,
    unlockedWhen: _p_firstLegend,
    hintText: 'Catch your first Legendary plant',
    progressFor: _progFirstLegendary,
  ),
  BadgeDefinition(
    id: 'legendary_5',
    emoji: '🔥',
    name: 'Legend Keeper',
    tier: BadgeTier.gold,
    unlockedWhen: _p_legend5,
    hintText: 'Catch 5 Legendary plants',
    progressFor: _progLegendary5,
  ),
  BadgeDefinition(
    id: 'streak_3',
    emoji: '🗓️',
    name: '3-Day Streak',
    tier: BadgeTier.bronze,
    unlockedWhen: _p_streak3,
    hintText: 'Scan plants 3 days in a row',
    progressFor: _progStreak3,
  ),
  BadgeDefinition(
    id: 'streak_7',
    emoji: '🗓️',
    name: '7-Day Streak',
    tier: BadgeTier.silver,
    unlockedWhen: _p_streak7,
    hintText: 'Scan plants 7 days in a row',
    progressFor: _progStreak7,
  ),
  BadgeDefinition(
    id: 'streak_30',
    emoji: '🗓️',
    name: '30-Day Streak',
    tier: BadgeTier.gold,
    unlockedWhen: _p_streak30,
    hintText: 'Scan plants 30 days in a row',
    progressFor: _progStreak30,
  ),
  BadgeDefinition(
    id: 'orchid',
    emoji: '🌸',
    name: 'Orchid Badge',
    tier: BadgeTier.bronze,
    unlockedWhen: _p_orchid,
    hintText: 'Catch a plant from the Orchidaceae family',
    isDiscovery: true,
  ),
  BadgeDefinition(
    id: 'fern',
    emoji: '🌿',
    name: 'Spore Badge',
    tier: BadgeTier.bronze,
    unlockedWhen: _p_fern,
    hintText: 'Catch a fern',
    isDiscovery: true,
  ),
  BadgeDefinition(
    id: 'world',
    emoji: '🌍',
    name: 'World Badge',
    tier: BadgeTier.gold,
    unlockedWhen: _p_world,
    hintText: 'Catch plants from 3 different families',
    isDiscovery: true,
  ),
  BadgeDefinition(
    id: 'explorer',
    emoji: '🗺️',
    name: 'Explorer',
    tier: BadgeTier.silver,
    unlockedWhen: _p_explorer,
    hintText: 'Catch plants in 3 different locations',
    isDiscovery: true,
  ),
];

// Top-level progress functions (must be top-level for const BadgeDefinition).
BadgeProgress _progFirstCatch(_ProfileStats s) => _prog(s.totalCaught, 1);
BadgeProgress _progCollector10(_ProfileStats s) => _prog(s.totalCaught, 10);
BadgeProgress _progCollector50(_ProfileStats s) => _prog(s.totalCaught, 50);
BadgeProgress _progCollector100(_ProfileStats s) => _prog(s.totalCaught, 100);
BadgeProgress _progFirstRare(_ProfileStats s) => _prog(s.rareCount, 1);
BadgeProgress _progFirstLegendary(_ProfileStats s) =>
    _prog(s.legendaryCount, 1);
BadgeProgress _progLegendary5(_ProfileStats s) => _prog(s.legendaryCount, 5);
BadgeProgress _progStreak3(_ProfileStats s) => _prog(s.bestStreak, 3);
BadgeProgress _progStreak7(_ProfileStats s) => _prog(s.bestStreak, 7);
BadgeProgress _progStreak30(_ProfileStats s) => _prog(s.bestStreak, 30);

// ─────────────────────────────────────────────────────────────────────────────
// Avatar options
// ─────────────────────────────────────────────────────────────────────────────

class AvatarOption {
  const AvatarOption({
    required this.emoji,
    this.requiredBadgeId,
    required this.label,
  });

  final String emoji;
  final String label;

  /// Badge id that must be unlocked before this avatar can be selected.
  /// Null means it's available from the start.
  final String? requiredBadgeId;
}

const _avatarOptions = [
  AvatarOption(emoji: '🌿', label: 'Sprout', requiredBadgeId: null),
  AvatarOption(emoji: '🌸', label: 'Orchid', requiredBadgeId: 'orchid'),
  AvatarOption(emoji: '🍃', label: 'Fern', requiredBadgeId: 'fern'),
  AvatarOption(emoji: '🌍', label: 'Globe', requiredBadgeId: 'world'),
  AvatarOption(
      emoji: '💜', label: 'Rare Hunter', requiredBadgeId: 'first_rare'),
  AvatarOption(
      emoji: '🔥', label: 'Legend', requiredBadgeId: 'first_legendary'),
  AvatarOption(
      emoji: '🌳', label: 'Ancient Tree', requiredBadgeId: 'collector_100'),
];

bool _isAvatarUnlocked(AvatarOption avatar, _ProfileStats stats) {
  if (avatar.requiredBadgeId == null) return true;
  final badge = _badges.firstWhere((b) => b.id == avatar.requiredBadgeId);
  return badge.unlockedWhen(stats);
}

// ─────────────────────────────────────────────────────────────────────────────
// Local prefs keys (new-badge tracking + chosen avatar)
// ─────────────────────────────────────────────────────────────────────────────

const _prefsSeenBadgesKey = 'profile_seen_badge_ids';
const _prefsAvatarKey = 'profile_selected_avatar';
const _prefsBonusXpBadgesKey = 'profile_bonus_xp_badge_ids';
const _prefsUsernameKey = 'profile_username';
const _defaultUsername = 'Botanist';

// ─────────────────────────────────────────────────────────────────────────────
// Profile stats — computed from raw CaughtPlant list
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileStats {
  const _ProfileStats({
    required this.totalCaught,
    required this.uniqueSpecies,
    required this.commonCount,
    required this.epicCount,
    required this.rareCount,
    required this.legendaryCount,
    required this.totalXp,
    required this.level,
    required this.currentStreak,
    required this.bestStreak,
    required this.families,
    required this.familyCounts,
    required this.distinctLocationCount,
    required this.catchDates,
    required this.earliestCatch,
  });

  final int totalCaught;
  final int uniqueSpecies;
  final int commonCount;
  final int epicCount;
  final int rareCount;
  final int legendaryCount;
  final int totalXp;
  final int level;
  final int currentStreak;
  final int bestStreak;
  final Set<String> families;
  final Map<String, int> familyCounts;
  final int distinctLocationCount;
  final List<DateTime> catchDates;
  final DateTime? earliestCatch;

  /// The family with the most catches, or null if no catches have a family.
  String? get topFamily {
    if (familyCounts.isEmpty) return null;
    final sorted = familyCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  int get topFamilyCount =>
      topFamily == null ? 0 : (familyCounts[topFamily] ?? 0);

  static _ProfileStats fromCatches(List<CaughtPlant> catches) {
    int common = 0, epic = 0, rare = 0, legendary = 0, xp = 0;
    final species = <String>{};
    final families = <String>{};
    final familyCounts = <String, int>{};
    final locations = <String>{};
    final dates = <DateTime>[];
    DateTime? earliest;

    for (final c in catches) {
      switch (c.rarity) {
        case 'common':
          common++;
          break;
        case 'epic':
          epic++;
          break;
        case 'rare':
          rare++;
          break;
        case 'legendary':
          legendary++;
          break;
      }
      xp += _xpForRarity(c.rarity);

      if (c.scientificName.isNotEmpty) species.add(c.scientificName);
      if (c.family.isNotEmpty) {
        families.add(c.family);
        familyCounts.update(c.family, (v) => v + 1, ifAbsent: () => 1);
      }

      final lat = c.latitude;
      final lng = c.longitude;
      if (lat != null && lng != null) {
        locations.add('${(lat * 100).round()},${(lng * 100).round()}');
      }

      final d = c.caughtAtDate; // uses the DateTime helper on the entity
      dates.add(d);
      if (earliest == null || d.isBefore(earliest)) earliest = d;
    }

    final streaks = _computeStreaks(dates);
    final level = _computeLevel(xp);

    return _ProfileStats(
      totalCaught: catches.length,
      uniqueSpecies: species.length,
      commonCount: common,
      epicCount: epic,
      rareCount: rare,
      legendaryCount: legendary,
      totalXp: xp,
      level: level,
      currentStreak: streaks.current,
      bestStreak: streaks.best,
      families: families,
      familyCounts: familyCounts,
      distinctLocationCount: locations.length,
      catchDates: dates,
      earliestCatch: earliest,
    );
  }

  static const empty = _ProfileStats(
    totalCaught: 0,
    uniqueSpecies: 0,
    commonCount: 0,
    epicCount: 0,
    rareCount: 0,
    legendaryCount: 0,
    totalXp: 0,
    level: 1,
    currentStreak: 0,
    bestStreak: 0,
    families: {},
    familyCounts: {},
    distinctLocationCount: 0,
    catchDates: [],
    earliestCatch: null,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Date formatting helper (no intl dependency in this project)
// ─────────────────────────────────────────────────────────────────────────────

const _monthNames = [
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

String _formatMonthYear(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Stream<List<CaughtPlant>>? _stream;
  SharedPreferences? _prefs;

  Set<String> _seenBadgeIds = {};
  Set<String> _bonusXpBadgeIds = {};
  String _selectedAvatar = _avatarOptions.first.emoji;
  bool _multiplierActive = false;
  String _username = _defaultUsername;

  // Toast state
  String? _toastBadgeName;
  String? _toastFlavor;
  int? _toastBonusXp;
  bool _toastVisible = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    prefetchGitHubProfile(); // fire-and-forget so modal is instant
    final db = await AppDatabase.getInstance();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _stream = db.caughtPlantDao.watchAllPlants();
      _prefs = prefs;
      _seenBadgeIds =
          (prefs.getStringList(_prefsSeenBadgesKey) ?? const []).toSet();
      _bonusXpBadgeIds =
          (prefs.getStringList(_prefsBonusXpBadgesKey) ?? const []).toSet();
      _selectedAvatar =
          prefs.getString(_prefsAvatarKey) ?? _avatarOptions.first.emoji;
      _multiplierActive = _isMultiplierActive(prefs);
      _username = prefs.getString(_prefsUsernameKey) ?? _defaultUsername;
    });
  }

  /// Called each time the stream emits — checks for newly unlocked badges,
  /// awards bonus XP, triggers multiplier, and queues toasts.
  void _processBadgeRewards(_ProfileStats stats) {
    final prefs = _prefs;
    if (prefs == null) return;

    for (final badge in _badges) {
      if (!badge.unlockedWhen(stats)) continue;
      if (_bonusXpBadgeIds.contains(badge.id)) continue;

      // First time this badge is unlocked — award bonus XP and show toast.
      final bonus = _badgeBonusXp[badge.id] ?? 0;
      final flavor = _badgeFlavorText[badge.id] ?? '';

      _bonusXpBadgeIds = {..._bonusXpBadgeIds, badge.id};
      prefs.setStringList(_prefsBonusXpBadgesKey, _bonusXpBadgeIds.toList());

      // Streak_7 and streak_30 also grant the XP multiplier.
      if (badge.id == 'streak_7' || badge.id == 'streak_30') {
        _grantMultiplier(prefs).then((_) {
          if (mounted) setState(() => _multiplierActive = true);
        });
      }

      // Queue the toast (show one at a time; latest wins for simplicity).
      if (mounted) {
        setState(() {
          _toastBadgeName = badge.name;
          _toastFlavor = flavor;
          _toastBonusXp = bonus;
          _toastVisible = true;
        });
        // Auto-dismiss after 3.5 s.
        Future.delayed(const Duration(milliseconds: 3500), () {
          if (mounted) setState(() => _toastVisible = false);
        });
      }
    }
  }

  /// Marks a badge as "seen" so the NEW indicator stops showing for it.
  void _markBadgeSeen(String badgeId) {
    if (_seenBadgeIds.contains(badgeId)) return;
    setState(() => _seenBadgeIds = {..._seenBadgeIds, badgeId});
    _prefs?.setStringList(_prefsSeenBadgesKey, _seenBadgeIds.toList());
  }

  void _selectAvatar(String emoji) {
    setState(() => _selectedAvatar = emoji);
    _prefs?.setString(_prefsAvatarKey, emoji);
  }

  Future<void> _editUsername(BuildContext context) async {
    final controller = TextEditingController(text: _username);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Your name',
            style: GoogleFonts.spaceMono(
                fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          style: GoogleFonts.spaceGrotesk(fontSize: 15, color: textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter a name...',
            hintStyle: GoogleFonts.spaceGrotesk(fontSize: 15, color: textMuted),
            counterStyle:
                GoogleFonts.spaceGrotesk(fontSize: 11, color: textMuted),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: borderColor)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: green600)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('Save',
                style: GoogleFonts.spaceGrotesk(
                    color: green600, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != _username) {
      setState(() => _username = result);
      _prefs?.setString(_prefsUsernameKey, result);
    }
  }

  Future<void> _resetProgress() async {
    final repo = PlantRepository.instance;
    final catches = await repo.getAllCatches();
    for (final c in catches) {
      await repo.deleteCatch(c);
    }

    await _prefs?.remove(_prefsSeenBadgesKey);
    await _prefs?.remove(_prefsBonusXpBadgesKey);
    await _prefs?.remove(_prefsMultiplierExpiryKey);

    if (mounted) {
      setState(() {
        _seenBadgeIds = {};
        _bonusXpBadgeIds = {};
        _multiplierActive = false;
      });
    }
  }

  void _dismissToast() => setState(() => _toastVisible = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: _stream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<CaughtPlant>>(
              stream: _stream,
              builder: (context, snapshot) {
                final stats = snapshot.hasData
                    ? _ProfileStats.fromCatches(snapshot.data!)
                    : _ProfileStats.empty;

                // Process rewards on every emission (idempotent via prefs set).
                if (snapshot.hasData) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _processBadgeRewards(stats));
                }

                return Stack(
                  children: [
                    _ProfileBody(
                      stats: stats,
                      seenBadgeIds: _seenBadgeIds,
                      onBadgeOpened: _markBadgeSeen,
                      selectedAvatar: _selectedAvatar,
                      onAvatarSelected: _selectAvatar,
                      multiplierActive: _multiplierActive,
                      bonusXpBadgeIds: _bonusXpBadgeIds,
                      username: _username,
                      onEditUsername: () => _editUsername(context),
                      onResetProgress: _resetProgress,
                    ),
                    // Badge unlock toast overlay
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 20,
                      right: 20,
                      child: IgnorePointer(
                        ignoring: !_toastVisible,
                        child: _BadgeUnlockToast(
                          visible: _toastVisible,
                          badgeName: _toastBadgeName ?? '',
                          flavorText: _toastFlavor ?? '',
                          bonusXp: _toastBonusXp ?? 0,
                          onDismiss: _dismissToast,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.stats,
    required this.seenBadgeIds,
    required this.onBadgeOpened,
    required this.selectedAvatar,
    required this.onAvatarSelected,
    required this.multiplierActive,
    required this.bonusXpBadgeIds,
    required this.username,
    required this.onEditUsername,
    required this.onResetProgress,
  });

  final _ProfileStats stats;
  final Set<String> seenBadgeIds;
  final void Function(String badgeId) onBadgeOpened;
  final String selectedAvatar;
  final void Function(String emoji) onAvatarSelected;
  final bool multiplierActive;
  final Set<String> bonusXpBadgeIds;
  final String username;
  final VoidCallback onEditUsername;
  final VoidCallback onResetProgress;

  void _openBadgeSheet(BuildContext context, BadgeDefinition badge) {
    final unlocked = badge.unlockedWhen(stats);
    onBadgeOpened(badge.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) =>
          _BadgeDetailSheet(badge: badge, unlocked: unlocked, stats: stats),
    );
  }

  void _openAvatarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _AvatarPickerSheet(
        stats: stats,
        selectedAvatar: selectedAvatar,
        onAvatarSelected: (emoji) {
          onAvatarSelected(emoji);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  void _openSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _SettingsSheet(
        onHowToPlay: () {
          Navigator.of(sheetContext).pop();
          showHowToPlay(context);
        },
        onResetProgress: () {
          Navigator.of(sheetContext).pop();
          _confirmResetProgress(context);
        },
        onAbout: () {
          Navigator.of(sheetContext).pop();
          showDialog(
            context: context,
            builder: (_) => const _AboutDialog(),
          );
        },
      ),
    );
  }

  Future<void> _confirmResetProgress(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset all progress?',
            style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700, color: textPrimary)),
        content: Text(
          'This permanently deletes every catch, badge, and streak. '
          'This cannot be undone.',
          style: GoogleFonts.spaceGrotesk(fontSize: 13, color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Reset',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onResetProgress();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Progress reset.',
                style: GoogleFonts.spaceGrotesk(color: textPrimary)),
            backgroundColor: surface2,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _dynamicSubtitle(_ProfileStats s) {
    if (s.currentStreak >= 7)
      return '${s.currentStreak}-day streak 🔥 Keep it up!';
    if (s.currentStreak >= 3)
      return '${s.currentStreak} days in a row 🌿 Going strong!';
    if (s.legendaryCount > 0)
      return '${s.legendaryCount} legendary ${s.legendaryCount == 1 ? 'plant' : 'plants'} caught 🔥';
    if (s.totalCaught == 0) return 'Your botanical journey begins here.';
    if (s.totalCaught == 1) return 'First catch down. Many more to go!';
    return '${s.totalCaught} plants caught across ${s.families.length} ${s.families.length == 1 ? 'family' : 'families'}.';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _xpProgress(stats.totalXp, stats.level);
    final nextTitle = stats.level < 10 ? _titleForLevel(stats.level + 1) : null;

    final unlockedCount = _badges.where((b) => b.unlockedWhen(stats)).length;
    final flair = _flairForBadgeCount(unlockedCount);

    // Find the single closest-to-unlocking locked badge for the nudge card.
    BadgeDefinition? nudgeBadge;
    double nudgeBestRatio = -1;
    for (final b in _badges) {
      if (b.unlockedWhen(stats)) continue;
      final prog = b.progressFor?.call(stats);
      if (prog == null || prog.target == 0) continue;
      final ratio = prog.current / prog.target;
      if (ratio > nudgeBestRatio) {
        nudgeBestRatio = ratio;
        nudgeBadge = b;
      }
    }

    // Does the user have the streak_7/streak_30 badge for Week Warrior title?
    final isWeekWarrior = _badges
        .where((b) => b.id == 'streak_7' || b.id == 'streak_30')
        .any((b) => b.unlockedWhen(stats));

    return CustomScrollView(
      slivers: [
        // ── Header ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Profile',
                            style: GoogleFonts.spaceMono(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            )),
                        Text(_dynamicSubtitle(stats),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              color: textSecondary,
                            )),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Optional multiplier chip
                        if (multiplierActive)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: amber.withOpacity(0.5), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🔥',
                                      style: TextStyle(fontSize: 9)),
                                  const SizedBox(width: 3),
                                  Text('1.5× XP',
                                      style: GoogleFonts.spaceMono(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: amber,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        Builder(
                          builder: (btnContext) => GestureDetector(
                            onTap: () => _openSettingsSheet(btnContext),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: surface2,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: const Icon(Icons.settings_outlined,
                                  size: 18, color: textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Botanist card ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                color: surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _openAvatarPicker(context),
                        child: _FlairAvatar(
                          emoji: selectedAvatar,
                          flair: flair,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: onEditUsername,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(username,
                                      style: GoogleFonts.spaceMono(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      )),
                                  const SizedBox(width: 5),
                                  const Icon(Icons.edit,
                                      size: 11, color: textMuted),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _TitlePill(_titleForLevel(stats.level)),
                                if (isWeekWarrior)
                                  _TitlePill('🔥 Week Warrior',
                                      color: amber,
                                      bgColor: const Color(0xFFFFF3E0)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Level',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                                letterSpacing: 0.5,
                              )),
                          Text('${stats.level}',
                              style: GoogleFonts.spaceMono(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                                height: 1,
                              )),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        nextTitle != null
                            ? 'XP to Lv. ${stats.level + 1} — $nextTitle'
                            : 'Max level reached',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (progress.nextThreshold != null)
                        Text(
                          '${progress.current} / ${progress.nextThreshold}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 10,
                            color: textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress.nextThreshold != null
                          ? (progress.current / progress.nextThreshold!)
                              .clamp(0.0, 1.0)
                          : 1.0,
                      backgroundColor: surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(green600),
                      minHeight: 5,
                    ),
                  ),
                  if (stats.earliestCatch != null || stats.topFamily != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (stats.earliestCatch != null)
                            _InsightChip(
                              icon: '📅',
                              text:
                                  'Collecting since ${_formatMonthYear(stats.earliestCatch!)}',
                            ),
                          if (stats.topFamily != null)
                            _InsightChip(
                              icon: '🌿',
                              text: 'Mostly ${stats.topFamily}',
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── Collection ────────────────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionLabel('Collection')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _StatPill('${stats.totalCaught}', 'Caught'),
                const SizedBox(width: 8),
                _StatPill('${stats.uniqueSpecies}', 'Species'),
                const SizedBox(width: 8),
                _StatPill('${stats.legendaryCount}', 'Legendary'),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                _RarityChip('${stats.commonCount}', 'Common', textMuted),
                const SizedBox(width: 6),
                _RarityChip(
                    '${stats.epicCount}', 'Epic', const Color(0xFFC04080)),
                const SizedBox(width: 6),
                _RarityChip(
                    '${stats.rareCount}', 'Rare', const Color(0xFF9A60D0)),
                const SizedBox(width: 6),
                _RarityChip('${stats.legendaryCount}', 'Legend',
                    const Color(0xFFFF6432)),
              ],
            ),
          ),
        ),

        // ── Badges ────────────────────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionLabel('Badges')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              itemCount: _badges.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final badge = _badges[i];
                final unlocked = badge.unlockedWhen(stats);
                final isNew = unlocked && !seenBadgeIds.contains(badge.id);
                // A badge is "fresh" if bonus XP was never recorded for it
                // before this session — we use this to trigger the flip.
                final isFresh = unlocked && !bonusXpBadgeIds.contains(badge.id);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _BadgeCard(
                    badge: badge,
                    unlocked: unlocked,
                    isNew: isNew,
                    isFresh: isFresh,
                    progress: badge.progressFor?.call(stats),
                    onTap: () => _openBadgeSheet(context, badge),
                  ),
                );
              },
            ),
          ),
        ),

        // ── Next badge nudge ─────────────────────────────────────────
        if (nudgeBadge != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _NextBadgeNudge(
                badge: nudgeBadge!,
                progress: nudgeBadge!.progressFor!.call(stats)!,
                onTap: () => _openBadgeSheet(context, nudgeBadge!),
              ),
            ),
          ),

        // ── Streak ────────────────────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionLabel('Streak')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _StreakCard(stats: stats),
          ),
        ),

        // ── Activity (heatmap) ───────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionLabel('Activity')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ActivityHeatmapCard(catchDates: stats.catchDates),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textMuted,
            letterSpacing: 1.0,
          ),
        ),
      );
}

class _TitlePill extends StatelessWidget {
  const _TitlePill(this.title, {this.color, this.bgColor});
  final String title;
  final Color? color;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? green600;
    final bg = bgColor ?? green100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color == null)
            const Icon(Icons.eco_outlined, size: 10, color: green600),
          if (color == null) const SizedBox(width: 4),
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: 0.3,
              )),
        ],
      ),
    );
  }
}

/// Small pill used for "Collecting since ..." / "Mostly <family>" insights.
class _InsightChip extends StatelessWidget {
  const _InsightChip({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
            Text(text,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                )),
          ],
        ),
      );
}

/// Identical to the Dex screen's _StatPill.
class _StatPill extends StatelessWidget {
  const _StatPill(this.number, this.label);
  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Text(number,
                  style: GoogleFonts.spaceMono(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  )),
              Text(label,
                  style:
                      GoogleFonts.spaceGrotesk(fontSize: 11, color: textMuted)),
            ],
          ),
        ),
      );
}

class _RarityChip extends StatelessWidget {
  const _RarityChip(this.count, this.label, this.color);
  final String count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Text(count,
                  style: GoogleFonts.spaceMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  )),
              Text(label.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                    letterSpacing: 0.3,
                  )),
            ],
          ),
        ),
      );
}

class _BadgeCard extends StatefulWidget {
  const _BadgeCard({
    required this.badge,
    required this.unlocked,
    required this.isNew,
    required this.isFresh,
    required this.progress,
    required this.onTap,
  });

  final BadgeDefinition badge;
  final bool unlocked;
  final bool isNew;
  final bool isFresh; // triggers flip reveal on first appearance
  final BadgeProgress? progress;
  final VoidCallback onTap;

  @override
  State<_BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<_BadgeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _flip;

  Color get _ringColor => switch (widget.badge.tier) {
        BadgeTier.gold => amber,
        BadgeTier.silver => const Color(0xFF9EB8C0),
        BadgeTier.bronze => const Color(0xFFA07850),
      };

  String get _tierLabel => switch (widget.badge.tier) {
        BadgeTier.gold => 'Gold',
        BadgeTier.silver => 'Silver',
        BadgeTier.bronze => 'Bronze',
      };

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _flip = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    // If this badge just unlocked for the first time, play the flip.
    if (widget.isFresh && widget.unlocked) {
      // Short delay so the list has time to render first.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0; // already seen — skip animation
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _flip,
        builder: (context, child) {
          final t = _flip.value; // 0 → 1
          final showFront = t >= 0.5;

          // Each face gets its own transform so text is never
          // in the mirrored zone (past 90°).
          // Back:  rotates  0 → -π/2  (folds away)
          // Front: rotates  π/2 → 0   (unfolds into view)
          final backAngle = t * -3.14159 / 2;
          final frontAngle = (1 - t) * 3.14159 / 2;

          return Stack(
            children: [
              if (!showFront)
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(backAngle),
                  child: _buildBack(),
                ),
              if (showFront)
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(frontAngle),
                  child: _buildFront(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFront() {
    return Opacity(
      opacity: widget.unlocked ? 1.0 : 0.35,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 76,
            decoration: BoxDecoration(
              color: surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    widget.unlocked ? _ringColor.withOpacity(0.5) : borderColor,
                width: widget.unlocked ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.unlocked ? _ringColor : borderColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(widget.badge.emoji,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(widget.badge.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  widget.unlocked ? _tierLabel : 'Locked',
                  style: GoogleFonts.spaceMono(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: widget.unlocked ? _ringColor : textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
                if (!widget.unlocked && widget.progress != null) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: widget.progress!.target == 0
                          ? 0
                          : widget.progress!.current / widget.progress!.target,
                      backgroundColor: surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(green500),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${widget.progress!.current}/${widget.progress!.target}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 7,
                      color: textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.isNew)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6432),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: surface, width: 1.5),
                ),
                child: Text('NEW',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    )),
              ),
            ),
        ],
      ),
    );
  }

  /// The "back" of the card shown during the first half of the flip.
  Widget _buildBack() {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: green100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: green600.withOpacity(0.3), width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: surface,
              shape: BoxShape.circle,
            ),
            child:
                const Center(child: Text('✨', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(height: 6),
          Text('Unlocked!',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: green600,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Bottom sheet shown when a badge is tapped — replaces the old Tooltip,
/// which doesn't work well on touch devices.
class _BadgeDetailSheet extends StatelessWidget {
  const _BadgeDetailSheet({
    required this.badge,
    required this.unlocked,
    required this.stats,
  });

  final BadgeDefinition badge;
  final bool unlocked;
  final _ProfileStats stats;

  Color get _ringColor => switch (badge.tier) {
        BadgeTier.gold => amber,
        BadgeTier.silver => const Color(0xFF9EB8C0),
        BadgeTier.bronze => const Color(0xFFA07850),
      };

  String get _tierLabel => switch (badge.tier) {
        BadgeTier.gold => 'Gold',
        BadgeTier.silver => 'Silver',
        BadgeTier.bronze => 'Bronze',
      };

  @override
  Widget build(BuildContext context) {
    final progress = badge.progressFor?.call(stats);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: surface2,
                shape: BoxShape.circle,
                border: Border.all(
                  color: unlocked ? _ringColor : borderColor,
                  width: 2.5,
                ),
              ),
              child: Opacity(
                opacity: unlocked ? 1.0 : 0.4,
                child: Center(
                  child:
                      Text(badge.emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(badge.name,
                style: GoogleFonts.spaceMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                )),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: unlocked ? _ringColor.withOpacity(0.12) : surface2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                unlocked ? '$_tierLabel · Unlocked' : 'Locked',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: unlocked ? _ringColor : textMuted,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              badge.hintText,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            if (!unlocked && progress != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.target == 0
                      ? 0
                      : (progress.current / progress.target).clamp(0.0, 1.0),
                  backgroundColor: surface2,
                  valueColor: const AlwaysStoppedAnimation<Color>(green600),
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${progress.current} / ${progress.target}',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for choosing the botanist card avatar. Locked avatars show
/// the badge that needs to be unlocked first.
class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet({
    required this.stats,
    required this.selectedAvatar,
    required this.onAvatarSelected,
  });

  final _ProfileStats stats;
  final String selectedAvatar;
  final void Function(String emoji) onAvatarSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose avatar',
                style: GoogleFonts.spaceMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                )),
            const SizedBox(height: 4),
            Text('Some avatars unlock as you earn badges.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: textMuted,
                )),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _avatarOptions.map((avatar) {
                final unlocked = _isAvatarUnlocked(avatar, stats);
                final isSelected = avatar.emoji == selectedAvatar;
                return GestureDetector(
                  onTap: unlocked ? () => onAvatarSelected(avatar.emoji) : null,
                  child: Column(
                    children: [
                      Opacity(
                        opacity: unlocked ? 1.0 : 0.35,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: green100,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? green600 : borderColor,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: unlocked
                                ? Text(avatar.emoji,
                                    style: const TextStyle(fontSize: 24))
                                : const Icon(Icons.lock_outline,
                                    size: 18, color: textMuted),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        avatar.label,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: unlocked ? textSecondary : textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flair avatar — border style driven by badge count
// ─────────────────────────────────────────────────────────────────────────────

class _FlairAvatar extends StatelessWidget {
  const _FlairAvatar({required this.emoji, required this.flair});
  final String emoji;
  final _FlairTier flair;

  @override
  Widget build(BuildContext context) {
    Widget avatar = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: green100,
        shape: BoxShape.circle,
        border: flair == _FlairTier.gold
            ? Border.all(color: amber, width: 2.5)
            : flair == _FlairTier.vine
                ? Border.all(
                    color: green500, width: 2,
                    // Dashed effect via the border color only — Flutter's
                    // Border doesn't support dash natively; we fake it with
                    // a stack of a slightly dimmer circle underneath.
                  )
                : Border.all(color: green600, width: 2),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
    );

    // Gold flair: outer glow ring.
    if (flair == _FlairTier.gold) {
      avatar = Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: amber.withOpacity(0.25), width: 3),
        ),
        child: Center(child: avatar),
      );
    }

    // Vine flair: decorative leaf dots at corners.
    if (flair == _FlairTier.vine) {
      avatar = Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          for (final angle in [0.0, 1.57, 3.14, 4.71])
            Transform.translate(
              offset: Offset(
                29 *
                    (angle == 0
                        ? 0
                        : angle == 1.57
                            ? 1
                            : angle == 3.14
                                ? 0
                                : -1),
                29 *
                    (angle == 0
                        ? -1
                        : angle == 1.57
                            ? 0
                            : angle == 3.14
                                ? 1
                                : 0),
              ),
              child: const Text('🍃', style: TextStyle(fontSize: 8)),
            ),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: surface,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: const Icon(Icons.edit, size: 9, color: textMuted),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Next badge nudge card
// ─────────────────────────────────────────────────────────────────────────────

class _NextBadgeNudge extends StatelessWidget {
  const _NextBadgeNudge({
    required this.badge,
    required this.progress,
    required this.onTap,
  });

  final BadgeDefinition badge;
  final BadgeProgress progress;
  final VoidCallback onTap;

  Color get _ringColor => switch (badge.tier) {
        BadgeTier.gold => amber,
        BadgeTier.silver => const Color(0xFF9EB8C0),
        BadgeTier.bronze => const Color(0xFFA07850),
      };

  @override
  Widget build(BuildContext context) {
    final ratio =
        progress.target == 0 ? 0.0 : progress.current / progress.target;
    final remaining = progress.target - progress.current;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _ringColor.withOpacity(0.3), width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: surface,
                shape: BoxShape.circle,
                border: Border.all(color: _ringColor, width: 1.5),
              ),
              child: Center(
                  child:
                      Text(badge.emoji, style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(badge.name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          )),
                      Text('$remaining to go',
                          style: GoogleFonts.spaceMono(
                            fontSize: 10,
                            color: textMuted,
                          )),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      backgroundColor: surface,
                      valueColor: AlwaysStoppedAnimation<Color>(_ringColor),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(badge.hintText,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        color: textMuted,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: textMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge unlock toast overlay
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeUnlockToast extends StatefulWidget {
  const _BadgeUnlockToast({
    required this.visible,
    required this.badgeName,
    required this.flavorText,
    required this.bonusXp,
    required this.onDismiss,
  });

  final bool visible;
  final String badgeName;
  final String flavorText;
  final int bonusXp;
  final VoidCallback onDismiss;

  @override
  State<_BadgeUnlockToast> createState() => _BadgeUnlockToastState();
}

class _BadgeUnlockToastState extends State<_BadgeUnlockToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_BadgeUnlockToast old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      _ctrl.forward(from: 0);
    } else if (!widget.visible && old.visible) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Container(
            decoration: BoxDecoration(
              color: green800,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Badge Unlocked: ${widget.badgeName}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          )),
                      const SizedBox(height: 2),
                      Text(widget.flavorText,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: green200,
                          )),
                    ],
                  ),
                ),
                if (widget.bonusXp > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: green600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('+${widget.bonusXp} XP',
                        style: GoogleFonts.spaceMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak card
// ─────────────────────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.stats});
  final _ProfileStats stats;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${stats.currentStreak}',
                        style: GoogleFonts.spaceMono(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: amber,
                          height: 1,
                        )),
                    const SizedBox(width: 6),
                    Text('day streak 🔥',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        )),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('BEST',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                          letterSpacing: 0.5,
                        )),
                    Text('${stats.bestStreak} days',
                        style: GoogleFonts.spaceMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _WeekDots(catchDates: stats.catchDates),
          ],
        ),
      );
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.catchDates});
  final List<DateTime> catchDates;

  @override
  Widget build(BuildContext context) {
    final activeDays =
        catchDates.map((d) => DateTime(d.year, d.month, d.day)).toSet();

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final monday = todayDay
        .subtract(Duration(days: todayDay.weekday - 1)); // weekday: Mon=1

    const labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return Row(
      children: List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        final isToday = day == todayDay;
        final isActive = activeDays.contains(day) && !day.isAfter(todayDay);

        final Color dotBg = isToday
            ? green600
            : isActive
                ? green100
                : surface;
        final Color dotBorder = isToday || isActive ? green600 : borderColor;

        final Widget dotChild = isToday
            ? Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle))
            : isActive
                ? Text('✓',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: green600,
                    ))
                : const SizedBox.shrink();

        return Expanded(
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: dotBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotBorder, width: 1.5),
                ),
                child: Center(child: dotChild),
              ),
              const SizedBox(height: 3),
              Text(labels[i],
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                    letterSpacing: 0.3,
                  )),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity heatmap (last ~10 weeks)
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityHeatmapCard extends StatelessWidget {
  const _ActivityHeatmapCard({required this.catchDates});
  final List<DateTime> catchDates;

  static const int _weeks = 10;

  @override
  Widget build(BuildContext context) {
    final counts = <DateTime, int>{};
    for (final d in catchDates) {
      final day = DateTime(d.year, d.month, d.day);
      counts.update(day, (v) => v + 1, ifAbsent: () => 1);
    }

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    // Start of the current week (Monday).
    final currentWeekStart =
        todayDay.subtract(Duration(days: todayDay.weekday - 1));
    // Go back (_weeks - 1) more weeks so the grid covers ~10 weeks total.
    final gridStart =
        currentWeekStart.subtract(const Duration(days: 7 * (_weeks - 1)));

    final maxCount = counts.values.isEmpty
        ? 0
        : counts.values.reduce((a, b) => a > b ? a : b);

    Color colorFor(int count) {
      if (count == 0) return surface2;
      if (maxCount <= 1) return green400;
      final ratio = count / maxCount;
      if (ratio > 0.66) return green700;
      if (ratio > 0.33) return green500;
      return green300;
    }

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      decoration: BoxDecoration(
        color: surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Last $_weeks weeks',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                    letterSpacing: 0.3,
                  )),
              Text('${catchDates.length} catches',
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            const gap = 3.0;
            final labelColWidth = 12.0;
            final cellSize =
                ((constraints.maxWidth - labelColWidth - gap * _weeks) / _weeks)
                    .clamp(10.0, 18.0);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weekday labels down the left side.
                SizedBox(
                  width: labelColWidth,
                  child: Column(
                    children: List.generate(
                      7,
                      (row) => SizedBox(
                        height: cellSize + gap,
                        child: Text(
                          dayLabels[row],
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 8,
                            color: textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Week columns.
                ...List.generate(_weeks, (col) {
                  return Padding(
                    padding:
                        EdgeInsets.only(right: col == _weeks - 1 ? 0 : gap),
                    child: Column(
                      children: List.generate(7, (row) {
                        final day =
                            gridStart.add(Duration(days: col * 7 + row));
                        final inFuture = day.isAfter(todayDay);
                        final count = counts[day] ?? 0;
                        return Padding(
                          padding: EdgeInsets.only(bottom: row == 6 ? 0 : gap),
                          child: Tooltip(
                            message: inFuture
                                ? ''
                                : '${day.day}/${day.month}/${day.year} — '
                                    '$count catch${count == 1 ? '' : 'es'}',
                            child: Container(
                              width: cellSize,
                              height: cellSize,
                              decoration: BoxDecoration(
                                color: inFuture ? surface : colorFor(count),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ],
            );
          }),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less',
                  style:
                      GoogleFonts.spaceGrotesk(fontSize: 9, color: textMuted)),
              const SizedBox(width: 4),
              ...[surface2, green300, green500, green700].map(
                (c) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('More',
                  style:
                      GoogleFonts.spaceGrotesk(fontSize: 9, color: textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
    required this.onResetProgress,
    required this.onAbout,
    required this.onHowToPlay,
  });

  final VoidCallback onResetProgress;
  final VoidCallback onAbout;
  final VoidCallback onHowToPlay;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text('Settings',
                style: GoogleFonts.spaceMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                )),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.help_outline,
              iconColor: purple,
              title: 'How to Play',
              subtitle: 'A quick guide to catching plants',
              onTap: onHowToPlay,
            ),
            _SettingsTile(
              icon: Icons.restart_alt,
              iconColor: Colors.red,
              title: 'Reset Progress',
              subtitle: 'Permanently delete all your catches',
              onTap: onResetProgress,
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              iconColor: green600,
              title: 'About PlantoDex',
              subtitle: 'v$_appVersion · built by yukjidam',
              onTap: onAbout,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      )),
                  Text(subtitle,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, color: textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: textMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// About dialog — app info + live GitHub profile
// ─────────────────────────────────────────────────────────────────────────────

// ── GitHub profile cache — fetched once at app start ──────────────────────────
Map<String, dynamic>? _cachedGhUser;
bool _ghFetchDone = false;

Future<void> prefetchGitHubProfile() async {
  if (_ghFetchDone) return;
  _ghFetchDone = true;
  try {
    final res = await http
        .get(Uri.parse('https://api.github.com/users/$_githubUsername'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      _cachedGhUser = jsonDecode(res.body) as Map<String, dynamic>;
    }
  } catch (_) {}
}

class _AboutDialog extends StatefulWidget {
  const _AboutDialog();

  @override
  State<_AboutDialog> createState() => _AboutDialogState();
}

class _AboutDialogState extends State<_AboutDialog> {
  Map<String, dynamic>? _ghUser;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if (_cachedGhUser != null) {
      _ghUser = _cachedGhUser;
      _loading = false;
    } else {
      _fetchGitHubProfile();
    }
  }

  Future<void> _fetchGitHubProfile() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.github.com/users/$_githubUsername'))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        _cachedGhUser = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _ghUser = _cachedGhUser;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _openGitHub() async {
    final url = (_ghUser?['html_url'] as String?) ??
        'https://github.com/$_githubUsername';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _ghUser?['avatar_url'] as String?;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── App logo  ×  GH avatar ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: const Center(
                      child: Text('🌿', style: TextStyle(fontSize: 28))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('×',
                      style: GoogleFonts.spaceMono(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      )),
                ),
                // GH avatar
                if (_loading)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: surface2,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: surface2,
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person, color: textMuted, size: 26)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('PlantoDex',
                style: GoogleFonts.spaceMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                )),
            const SizedBox(height: 2),
            Text('v$_appVersion',
                style:
                    GoogleFonts.spaceGrotesk(fontSize: 11, color: textMuted)),
            const SizedBox(height: 14),
            Text(
              'It started with my mom\'s fake plants. We loved them but had no idea '
              'what any of them were called. That small mystery turned into this: '
              'a plant catching app that borrows what makes collecting games fun, '
              'rarity tiers, a Dex to fill, that itch of "what haven\'t I found yet", '
              'and points it at something real. Built solo while waiting for graduation, '
              'because every walk outside deserves a reason to look closer.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Made with ☕ and probably too much love for tiny ui details.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: textMuted,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: borderColor, height: 1),
            const SizedBox(height: 14),
            // ── GitHub button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openGitHub,
                icon: const Icon(Icons.code, size: 16),
                label: Text('github.com/$_githubUsername',
                    style: GoogleFonts.spaceMono(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: green600,
                  side: const BorderSide(color: green600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close',
                    style: GoogleFonts.spaceGrotesk(
                      color: textMuted,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
