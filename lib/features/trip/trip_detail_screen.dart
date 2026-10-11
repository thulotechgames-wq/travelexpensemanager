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
import '../export/export_service.dart';
import 'expenses_tab.dart';
import 'insights_tab.dart';
import 'split_tab.dart';
import 'trip_form_sheet.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkBadges(context, ref);
    });
  }

  Future<void> _menu(String action, Trip trip, TripStats stats) async {
    switch (action) {
      case 'edit':
        await showTripForm(context, trip: trip);
      case 'close':
        await ref.read(tripsProvider.notifier).upsert(trip.copyWith(closed: !trip.closed));
        if (!mounted) return;
        if (!trip.closed) {
          final money = ref.read(moneyProvider);
          if (stats.budget != null && stats.spent <= stats.budget!) {
            buzz(ref, Buzz.success);
            await celebrate(context,
                icon: Icons.savings_rounded,
                title: 'Under budget!',
                subtitle: 'You finished ${trip.title} with ${money(stats.remaining!)} to spare.');
          } else {
            buzz(ref, Buzz.medium);
            await celebrate(context,
                icon: Icons.flag_rounded,
                title: 'Trip complete',
                subtitle: '${stats.expenses.length} expenses · ${money(stats.spent)} total.');
          }
          if (mounted) await checkBadges(context, ref);
        } else {
          toast(context, 'Trip reopened');
        }
      case 'pdf':
        await _export(() => ExportService.sharePdf(context, stats, ref.read(moneyProvider),
            ref.read(categoryMapProvider)));
      case 'csv':
        await _export(() => ExportService.shareCsv(context, stats, ref.read(moneyProvider),
            ref.read(categoryMapProvider)));
      case 'delete':
        final ok = await confirm(context,
            title: 'Delete trip?',
            message:
                '"${trip.title}" and its ${stats.expenses.length} expenses will be removed permanently.');
        if (!ok || !mounted) return;
        Navigator.pop(context);
        await ref.read(tripsProvider.notifier).remove(trip.id);
    }
  }

  Future<void> _export(Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      if (mounted) toast(context, 'Export failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final trip = ref.watch(tripProvider(widget.tripId));
    final stats = ref.watch(tripStatsProvider(widget.tripId));
    if (trip == null || stats == null) return const Scaffold();
    final money = ref.watch(moneyProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        floatingActionButton: trip.closed
            ? null
            : FloatingActionButton.extended(
                onPressed: () {
                  buzz(ref, Buzz.medium);
                  showQuickAdd(context, ref, trip.id);
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add expense', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
        body: NestedScrollView(
          headerSliverBuilder: (context, inner) => [
            SliverAppBar(
              pinned: true,
              title: Text(trip.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.ios_share_rounded),
                  tooltip: 'Export',
                  color: p.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (a) => _menu(a, trip, stats),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'pdf', child: Text('Share PDF report')),
                    PopupMenuItem(value: 'csv', child: Text('Share CSV')),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  color: p.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (a) => _menu(a, trip, stats),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit trip')),
                    PopupMenuItem(
                        value: 'close',
                        child: Text(trip.closed ? 'Reopen trip' : 'Mark as completed')),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete trip', style: TextStyle(color: p.danger))),
                  ],
                ),
              ],
            ),
            SliverToBoxAdapter(child: _Header(trip: trip, stats: stats, money: money)),
            SliverPersistentHeader(pinned: true, delegate: _TabsDelegate(p.bg)),
          ],
          body: TabBarView(children: [
            ExpensesTab(tripId: trip.id),
            InsightsTab(tripId: trip.id),
            SplitTab(tripId: trip.id),
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Trip trip;
  final TripStats stats;
  final Money money;
  const _Header({required this.trip, required this.stats, required this.money});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final dates = trip.endDate == null
        ? 'Since ${fmtShortYear(trip.startDate)}'
        : '${fmtShort(trip.startDate)} – ${fmtShortYear(trip.endDate!)}';
    final pace = (stats.totalDays != null && !trip.closed && stats.totalDays! > 0)
        ? stats.elapsedDays / stats.totalDays!
        : null;
    final dayLabel = stats.totalDays != null
        ? 'Day ${stats.elapsedDays.clamp(0, stats.totalDays!)} of ${stats.totalDays}'
        : '${stats.elapsedDays} days';

    final safe = stats.safeToday;
    final chips = <(String, String)>[
      if (safe != null)
        (safe >= 0 ? 'Safe today' : 'Over today', money.compact(safe.abs()))
      else if (stats.leftPerDay != null)
        ('Left / day', money.compact(stats.leftPerDay!)),
      if (stats.dailyBudget != null && !trip.closed) ('Today', money.compact(stats.todaySpent)),
      ('Avg / day', money.compact(stats.avgPerDay)),
      if (stats.leftPerDay == null) ('Expenses', '${stats.expenses.length}'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$dates · $dayLabel', style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        CountUp(
          value: stats.spent,
          format: money.call,
          style: context.tt.displayMedium,
        ),
        if (stats.budget != null) ...[
          const SizedBox(height: 4),
          Text(
            stats.remaining! >= 0
                ? '${money(stats.remaining!)} left of ${money(stats.budget!)}'
                : '${money(-stats.remaining!)} over ${money(stats.budget!)} budget',
            style: TextStyle(
              color: stats.health == Health.over ? p.danger : p.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          BudgetBar(pct: stats.pct, health: stats.health, height: 12, pace: pace),
        ],
        const SizedBox(height: 16),
        Row(children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: i == 0 ? p.ink : p.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(chips[i].$2,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFeatures: tabular,
                          color: i == 0 ? (safe != null && safe < 0 ? p.danger : p.accent) : p.ink,
                        )),
                  ),
                  Text(chips[i].$1,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: i == 0 ? p.bg.withValues(alpha: 0.6) : p.muted)),
                ]),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  final Color bg;
  _TabsDelegate(this.bg);

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: bg,
      alignment: Alignment.centerLeft,
      child: const TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.symmetric(horizontal: 8),
        tabs: [Tab(text: 'Expenses'), Tab(text: 'Insights'), Tab(text: 'Split')],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsDelegate old) => old.bg != bg;
}
