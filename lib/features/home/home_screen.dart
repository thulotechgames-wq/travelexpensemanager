import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/stats.dart';
import '../../widgets/common.dart';
import '../badges/badges_screen.dart';
import '../expense/quick_add_sheet.dart';
import '../settings/settings_screen.dart';
import '../trip/trip_detail_screen.dart';
import '../trip/trip_form_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);
    final stats = ref.watch(allStatsProvider);
    final money = ref.watch(moneyProvider);
    final active = trips.where((t) => !t.closed).toList();
    final done = trips.where((t) => t.closed).toList();
    final total = stats.values.fold<double>(0, (s, x) => s + x.spent);
    final unlocked = ref.watch(badgesProvider).where((b) => b.unlocked).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          buzz(ref);
          showTripForm(context);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New trip', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            sliver: SliverToBoxAdapter(
              child: Row(children: [
                Expanded(child: Text('Trips', style: context.tt.displayMedium)),
                _RoundBtn(
                  icon: Icons.emoji_events_rounded,
                  badge: unlocked > 0 ? '$unlocked' : null,
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
                ),
                _RoundBtn(
                  icon: Icons.settings, // IconData(0xe57f, fontFamily: 'MaterialIcons')
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ]),
            ),
          ),
          for (final t in active)
            if (stats[t.id]!.safeToday != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(child: SafeToSpendCard(stats: stats[t.id]!)),
              ),
          if (active.isNotEmpty && !active.any((t) => stats[t.id]!.safeToday != null))
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(child: _SafeToSpendHint(trip: active.first)),
            ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(child: StreakCard()),
          ),
          if (trips.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  Expanded(
                    child: _MiniStat(
                        label: 'All-time spent', value: money.compact(total)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(label: 'Trips', value: '${trips.length}'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                        label: 'Expenses', value: '${ref.watch(expensesProvider).length}'),
                  ),
                ]),
              ),
            ),
          if (trips.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.flight_takeoff_rounded,
                title: 'Where to next?',
                subtitle: 'Create your first trip and start tracking every coin you spend on it.',
                action: SizedBox(
                  width: 220,
                  child: FilledButton(
                    onPressed: () => showTripForm(context),
                    child: const Text('Create a trip'),
                  ),
                ),
              ),
            ),
          if (active.isNotEmpty) ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(child: Label('Active')),
            ),
            SliverList.separated(
              itemCount: active.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TripCard(trip: active[i], stats: stats[active[i].id]!),
              ),
            ),
          ],
          if (done.isNotEmpty) ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(child: Label('Completed')),
            ),
            SliverList.separated(
              itemCount: done.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TripCard(trip: done[i], stats: stats[done[i].id]!, compact: true),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 120 + MediaQuery.paddingOf(context).bottom)),
        ]),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;
  const _RoundBtn({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Pressable(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: p.card, shape: BoxShape.circle),
            child: Icon(icon, color: p.ink),
          ),
          if (badge != null)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration:
                    BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(10)),
                child: Text(badge!,
                    style: TextStyle(
                        color: p.onAccent, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, fontFeatures: tabular)),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// The app's core answer: how much more you can spend today and still finish on budget.
class SafeToSpendCard extends ConsumerWidget {
  final TripStats stats;
  const SafeToSpendCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.p;
    final money = ref.watch(moneyProvider);
    final safe = stats.safeToday!;
    final allowance = stats.todayAllowance!;
    final over = safe < 0;
    final tomorrow = stats.tomorrowAllowance;
    final msg = over
        ? tomorrow != null
            ? 'Over today\'s share by ${money(-safe)}. Tomorrow drops to ${money(tomorrow)}.'
            : 'Over today\'s share by ${money(-safe)}.'
        : stats.todaySpent == 0
            ? 'Nothing spent yet today. Your share is ${money(allowance)}.'
            : '${money(stats.todaySpent)} spent of today\'s ${money(allowance)}.';

    return Pressable(
      onTap: () {
        buzz(ref, Buzz.select);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: stats.trip.id)));
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                'SAFE TO SPEND TODAY · ${stats.trip.title.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: p.bg.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1),
              ),
            ),
            Pressable(
              onTap: () {
                buzz(ref, Buzz.medium);
                showQuickAdd(context, ref, stats.trip.id);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                child: Icon(Icons.add_rounded, color: p.onAccent),
              ),
            ),
          ]),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountUp(
              value: over ? 0 : safe,
              format: money.call,
              style: context.tt.displayMedium?.copyWith(color: over ? p.danger : p.accent),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: allowance <= 0 ? 1 : (stats.todaySpent / allowance).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: p.bg.withValues(alpha: 0.15),
              color: over ? p.danger : p.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(msg, style: TextStyle(color: p.bg.withValues(alpha: 0.75), fontSize: 13, height: 1.35)),
        ]),
      ),
    );
  }
}

class _SafeToSpendHint extends ConsumerWidget {
  final Trip trip;
  const _SafeToSpendHint({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.p;
    final started = !dateOnly(DateTime.now()).isBefore(dateOnly(trip.startDate));
    return Tile(
      onTap: started ? () => showTripForm(context, trip: trip) : null,
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Icon(Icons.savings_rounded, color: p.ink, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            started
                ? 'Add a budget and end date to ${trip.title} to see how much you can safely spend each day.'
                : '${trip.title} starts ${fmtDay(trip.startDate)}. Your daily safe-to-spend appears here once it begins.',
            style: TextStyle(color: p.muted, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.p;
    final s = ref.watch(streakProvider);
    final now = DateTime.now();
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final msg = s.loggedToday
        ? 'Logged today. See you tomorrow.'
        : s.current > 0
            ? 'Log an expense today to keep it alive.'
            : 'Log an expense today to start a streak.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: s.current > 0 ? p.accent : p.bg.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.local_fire_department_rounded,
              color: s.current > 0 ? p.onAccent : p.bg.withValues(alpha: 0.6), size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.current}-day streak',
                style: TextStyle(color: p.bg, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(msg, style: TextStyle(color: p.bg.withValues(alpha: 0.6), fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 8),
        Row(children: [
          for (var i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.week[i] ? p.accent : p.bg.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  letters[DateTime(now.year, now.month, now.day - 6 + i).weekday - 1],
                  style: TextStyle(
                      color: p.bg.withValues(alpha: i == 6 ? 0.9 : 0.4),
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ]),
            ),
        ]),
      ]),
    );
  }
}

class TripCard extends ConsumerWidget {
  final Trip trip;
  final TripStats stats;
  final bool compact;
  const TripCard({super.key, required this.trip, required this.stats, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.p;
    final money = ref.watch(moneyProvider);
    final dates = trip.endDate == null
        ? 'From ${fmtShortYear(trip.startDate)}'
        : '${fmtShort(trip.startDate)} – ${fmtShortYear(trip.endDate!)}';
    final pace = (stats.totalDays != null && stats.totalDays! > 0 && !trip.closed)
        ? stats.elapsedDays / stats.totalDays!
        : null;

    String sub;
    if (stats.budget == null) {
      sub = '${stats.expenses.length} expenses · ${money.compact(stats.avgPerDay)}/day avg';
    } else if (stats.remaining! < 0) {
      sub = '${money(-stats.remaining!)} over budget';
    } else if (stats.leftPerDay != null) {
      sub = '${money(stats.remaining!)} left · ${money(stats.leftPerDay!)}/day';
    } else {
      sub = '${money(stats.remaining!)} left of ${money.compact(stats.budget!)}';
    }

    return Tile(
      onTap: () {
        buzz(ref, Buzz.select);
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)));
      },
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleLarge),
                ),
                if (trip.isGroup) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.group_rounded, size: 18, color: p.muted),
                ],
                if (trip.closed) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle_rounded, size: 18, color: p.muted),
                ],
              ]),
              const SizedBox(height: 2),
              Text(dates, style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ),
          if (!trip.closed)
            Pressable(
              onTap: () {
                buzz(ref, Buzz.medium);
                showQuickAdd(context, ref, trip.id);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                child: Icon(Icons.add_rounded, color: p.onAccent),
              ),
            ),
        ]),
        SizedBox(height: compact ? 12 : 18),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(money(stats.spent),
                style: (compact ? context.tt.headlineSmall : context.tt.headlineLarge)
                    ?.copyWith(fontFeatures: tabular)),
            if (stats.budget != null) ...[
              const SizedBox(height: 12),
              BudgetBar(pct: stats.pct, health: stats.health, pace: pace),
            ],
            const SizedBox(height: 10),
            Text(sub,
                style: TextStyle(
                  color: stats.health == Health.over ? p.danger : p.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ]),
        ),
      ]),
    );
  }
}
