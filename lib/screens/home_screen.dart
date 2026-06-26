import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';
import '../providers/home_provider.dart';
import '../models/caught_plant.dart';
import '../models/seasonal_quest.dart';
import '../models/daily_quest.dart';
import '../widgets/bottom_nav_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// How-to-play onboarding
// ─────────────────────────────────────────────────────────────────────────────

const _prefsOnboardingKey = 'home_onboarding_seen';

/// Call from anywhere to show the how-to-play modal.
void showHowToPlay(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _HowToPlayDialog(),
  );
}

Future<void> _maybeShowOnboarding(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getBool(_prefsOnboardingKey) ?? false;
  if (seen) return;
  await prefs.setBool(_prefsOnboardingKey, true);
  if (context.mounted) showHowToPlay(context);
}

// ── How-to-play steps ─────────────────────────────────────────────────────────

const _howToPlaySteps = [
  (
    emoji: '📷',
    title: 'Scan a plant',
    body: 'Point your camera at any leaf, flower, or stem and tap Scan. '
        'The app will try to identify the species for you.',
  ),
  (
    emoji: '🌿',
    title: 'Catch it',
    body: 'If there\'s a match, tap "Pick this plant!" to add it to your Dex. '
        'Each species can only be caught once — so explore widely!',
  ),
  (
    emoji: '⭐',
    title: 'Rarity tiers',
    body: 'Every plant gets a rarity: Common, Rare, Epic, or Legendary. '
        'Rarer plants are harder to find and worth more XP.',
  ),
  (
    emoji: '🔥',
    title: 'Build your streak',
    body: 'Catch at least one plant each day to keep your streak alive. '
        'Longer streaks unlock bonus XP multipliers.',
  ),
  (
    emoji: '🎯',
    title: 'Complete quests',
    body: 'Daily and seasonal quests give you fun targets to chase. '
        'Finish them for bonus XP and exclusive badges.',
  ),
];

class _HowToPlayDialog extends StatefulWidget {
  const _HowToPlayDialog();

  @override
  State<_HowToPlayDialog> createState() => _HowToPlayDialogState();
}

class _HowToPlayDialogState extends State<_HowToPlayDialog> {
  // page -1 = greeting, pages 0..n-1 = how-to steps
  int _page = -1;

  bool get _onGreeting => _page == -1;
  bool get _isLast => _page == _howToPlaySteps.length - 1;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: _onGreeting ? _buildGreeting() : _buildStep(),
      ),
    );
  }

  // ── Greeting page ───────────────────────────────────────────────────────────
  Widget _buildGreeting() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App logo
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🌿', style: TextStyle(fontSize: 36)),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Welcome to PlantoDex!',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceMono(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hey there, new botanist! 🌱\n\n'
          'Thank you so much for installing the app. '
          'It means a lot to me so I hope it brings a little joy to your walks outside.\n\n'
          'The world is full of plants just waiting to be caught. '
          'Ready to start your collection?',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            color: textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '- YukJidam',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            color: textMuted,
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Maybe later',
                  style: GoogleFonts.spaceGrotesk(
                    color: textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => setState(() => _page = 0),
                style: FilledButton.styleFrom(
                  backgroundColor: green600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  "Let's go! 🌿",
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── How-to-play step pages ──────────────────────────────────────────────────
  Widget _buildStep() {
    final step = _howToPlaySteps[_page];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Step indicator dots ──────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_howToPlaySteps.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _page ? green600 : borderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 22),

        // ── Emoji icon ───────────────────────────────────────────────
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: green100,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(step.emoji, style: const TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(height: 16),

        // ── Title ────────────────────────────────────────────────────
        Text(
          step.title,
          style: GoogleFonts.spaceMono(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        // ── Body ─────────────────────────────────────────────────────
        Text(
          step.body,
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            color: textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 26),

        // ── Navigation buttons ───────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    setState(() => _page = _page == 0 ? -1 : _page - 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textSecondary,
                  side: const BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Back',
                    style:
                        GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (_isLast) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _page++);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: green600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _isLast ? "All set!" : 'Next',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// home_screen.dart  —  PlantoDex  (LIVE + Seasonal Quests)
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().load();
      _maybeShowOnboarding(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, home, _) {
        return Scaffold(
          backgroundColor: surface,
          body: home.loading
              ? const Center(child: CircularProgressIndicator(color: green600))
              : CustomScrollView(
                  slivers: [
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
                                    Text('Home',
                                        style: GoogleFonts.spaceMono(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        )),
                                    Text(_greetingSubtitle(),
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 13,
                                            color: textSecondary)),
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
                          _SeasonalQuestCard(home: home),
                          const SizedBox(height: 14),
                          _DailyQuestCard(home: home),
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

// ── Daily quest card ───────────────────────────────────────────────────────────

class _DailyQuestCard extends StatelessWidget {
  const _DailyQuestCard({required this.home});
  final HomeProvider home;

  @override
  Widget build(BuildContext context) {
    final progress = home.dailyQuestProgress;
    final quest = progress.quest;
    final completed = progress.completed;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: completed ? green100 : amberLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  completed ? '✅  DAILY DONE' : '☀️  DAILY QUEST',
                  style: GoogleFonts.spaceGrotesk(
                    color: completed ? green600 : amber,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${quest.badgeEmoji}  +${quest.bonusXp} XP',
                style: GoogleFonts.spaceMono(
                  color: amber,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            quest.title,
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            quest.description,
            style: GoogleFonts.spaceGrotesk(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 7,
              backgroundColor: grayLight,
              valueColor: AlwaysStoppedAnimation(completed ? green600 : amber),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${progress.current} / ${quest.count} completed',
            style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

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
            value: '${home.todayCatchCount} catches'),
        const SizedBox(width: 8),
        _StatPill(emoji: '⚡', label: 'XP today', value: '+${home.todayXp} XP'),
        const SizedBox(width: 8),
        _StatPill(
            emoji: '📦',
            label: 'Total',
            value: '${home.totalCatchCount} plants'),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill(
      {required this.emoji, required this.label, required this.value});
  final String emoji, label, value;

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
            Text(value,
                style: GoogleFonts.spaceMono(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
            Text(label,
                style:
                    GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Seasonal quest card ───────────────────────────────────────────────────────

class _SeasonalQuestCard extends StatelessWidget {
  const _SeasonalQuestCard({required this.home});
  final HomeProvider home;

  @override
  Widget build(BuildContext context) {
    final episode = home.activeEpisode;
    final active = home.activeQuest;
    final done = home.completedQuestCount;
    final total = episode.quests.length;
    final allDone = done == total;

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Episode header ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: green600.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Text(episode.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.title,
                        style: GoogleFonts.spaceMono(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        episode.subtitle,
                        style: GoogleFonts.spaceGrotesk(
                            color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$done/$total',
                      style: GoogleFonts.spaceMono(
                        color: green600,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text('quests',
                        style: GoogleFonts.spaceGrotesk(
                            color: textMuted, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Quest steps row ────────────────────────────────────────
                _QuestStepRow(progressList: home.questProgressList),
                const SizedBox(height: 12),

                // ── Active quest detail / all done ─────────────────────────
                if (allDone) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: green600.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Season Complete!',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: green600,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  )),
                              Text(
                                'You\'ve finished all ${episode.title} quests. See you next month!',
                                style: GoogleFonts.spaceGrotesk(
                                    color: textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (active != null) ...[
                  // ── Current quest ──────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: amberLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🎯  QUEST ${home.completedQuestCount + 1}',
                          style: GoogleFonts.spaceGrotesk(
                            color: amber,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Real-time countdown
                      Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 11, color: textMuted),
                          const SizedBox(width: 3),
                          Text(
                            'Resets in ${home.resetCountdown}',
                            style: GoogleFonts.spaceGrotesk(
                                color: textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    active.quest.title,
                    style: GoogleFonts.spaceGrotesk(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    active.quest.description,
                    style: GoogleFonts.spaceGrotesk(
                        color: textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: active.fraction,
                      minHeight: 7,
                      backgroundColor: grayLight,
                      valueColor: AlwaysStoppedAnimation(green600),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${active.current} / ${active.quest.count} completed',
                        style: GoogleFonts.spaceGrotesk(
                            color: textMuted, fontSize: 11),
                      ),
                      Row(
                        children: [
                          Text(
                            '${active.quest.badgeEmoji}  ${active.quest.badgeName}',
                            style: GoogleFonts.spaceGrotesk(
                              color: green600,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '+${active.quest.bonusXp} XP',
                            style: GoogleFonts.spaceMono(
                              color: amber,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // ── Go Scan button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => BottomNavShell.switchTab(context, 2),
                    style: FilledButton.styleFrom(
                      backgroundColor: green600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text('Go Scan',
                        style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quest step dots ───────────────────────────────────────────────────────────

class _QuestStepRow extends StatelessWidget {
  const _QuestStepRow({required this.progressList});
  final List<QuestProgress> progressList;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(progressList.length, (i) {
        final qp = progressList[i];
        final isActive =
            !qp.completed && (i == 0 || progressList[i - 1].completed);

        Color dotColor;
        Widget inner;

        if (qp.completed) {
          dotColor = green600;
          inner = const Icon(Icons.check, size: 10, color: Colors.white);
        } else if (isActive) {
          dotColor = amber;
          inner = Text(
            '${i + 1}',
            style: GoogleFonts.spaceMono(
                color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
          );
        } else {
          dotColor = grayLight;
          inner = Text(
            '${i + 1}',
            style: GoogleFonts.spaceMono(color: textMuted, fontSize: 8),
          );
        }

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
                child: Center(child: inner),
              ),
              if (i < progressList.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: qp.completed ? green600 : grayLight,
                  ),
                ),
            ],
          ),
        );
      }),
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
                const Text('🌱', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text('No catches yet — head outside!',
                    style: GoogleFonts.spaceGrotesk(
                        color: textMuted, fontSize: 13)),
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
            child: Text('🏆  Last Catch',
                style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Stack(
              children: [
                SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: photoFile.existsSync()
                      ? Image.file(photoFile, fit: BoxFit.cover)
                      : Container(
                          color: green100,
                          child: const Center(
                              child:
                                  Text('🌺', style: TextStyle(fontSize: 48)))),
                ),
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
                          Colors.black.withOpacity(0.72)
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
                              Text(plant!.commonName,
                                  style: GoogleFonts.spaceGrotesk(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const SizedBox(height: 1),
                              Text(plant!.scientificName,
                                  style: GoogleFonts.spaceGrotesk(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 11, color: Colors.white54),
                                  const SizedBox(width: 2),
                                  Text(_caughtLabel(plant!),
                                      style: GoogleFonts.spaceGrotesk(
                                          color: Colors.white54, fontSize: 11)),
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
    final safeTotal = total == 0 ? 1 : total;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📊  My Collection',
              style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: total == 0
                  ? [_BarSegment(flex: 1, color: grayLight)]
                  : [
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
                            flex: home.rareCount * 100 ~/ safeTotal,
                            color: purple),
                      if (home.legendaryCount > 0)
                        _BarSegment(
                            flex: home.legendaryCount * 100 ~/ safeTotal,
                            color: amber),
                    ],
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
                          '${home.topFamily.isNotEmpty ? ' · Most: ${home.topFamily}' : ''}',
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
    final allUnlocked = home.nextBadgeName == 'All badges unlocked!';
    return _Card(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: purpleLight, borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Text(home.nextBadgeEmoji,
                    style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('NEXT BADGE',
                        style: GoogleFonts.spaceGrotesk(
                            color: textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6)),
                    const Spacer(),
                    if (!allUnlocked)
                      Text('${home.nextBadgeCurrent} / ${home.nextBadgeTarget}',
                          style: GoogleFonts.spaceMono(
                              color: purple,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(home.nextBadgeName,
                    style: GoogleFonts.spaceGrotesk(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
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
                  Text(home.nextBadgeHint,
                      style: GoogleFonts.spaceGrotesk(
                          color: textMuted, fontSize: 11)),
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
          Text('🗺️  Recent Spots',
              style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 10),
          if (spots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Your catch locations will appear here.',
                  style:
                      GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 12)),
            )
          else
            ...spots.map((spot) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            color: green100,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Center(
                            child: Text('📍', style: TextStyle(fontSize: 13))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(spot.label,
                            style: GoogleFonts.spaceGrotesk(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ),
                      Text(
                        '${spot.plantCount} plant${spot.plantCount == 1 ? '' : 's'}',
                        style: GoogleFonts.spaceMono(
                            color: textMuted, fontSize: 11),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right, color: textMuted, size: 16),
                    ],
                  ),
                )),
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
  Widget build(BuildContext context) => Expanded(
        flex: flex < 1 ? 1 : flex,
        child: Container(height: 9, color: color),
      );
}

class _RarityCount extends StatelessWidget {
  final String emoji, label;
  final int count;
  final Color color;
  const _RarityCount(
      {required this.emoji,
      required this.label,
      required this.count,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 2),
            Text('$count',
                style: GoogleFonts.spaceMono(
                    color: color, fontWeight: FontWeight.w700, fontSize: 14)),
            Text(label,
                style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 9)),
          ],
        ),
      );
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
          color: bg.withOpacity(0.92), borderRadius: BorderRadius.circular(8)),
      child: Text('$emoji  $label',
          style: GoogleFonts.spaceGrotesk(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
