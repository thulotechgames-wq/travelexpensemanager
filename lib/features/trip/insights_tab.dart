import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../state/stats.dart';
import '../../widgets/common.dart';
import '../expense/expense_detail_sheet.dart';

class InsightsTab extends ConsumerStatefulWidget {
  final String tripId;
  const InsightsTab({super.key, required this.tripId});

  @override
  ConsumerState<InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends ConsumerState<InsightsTab> with AutomaticKeepAliveClientMixin {
  int _touched = -1;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final stats = ref.watch(tripStatsProvider(widget.tripId));
    if (stats == null) return const SizedBox.shrink();
    final p = context.p;
    final money = ref.watch(moneyProvider);

    if (stats.expenses.isEmpty) {
      return ListView(children: const [
        EmptyState(
          icon: Icons.insights_rounded,
          title: 'Charts appear here',
          subtitle: 'Log a few expenses and see where your money goes, day by day.',
        ),
      ]);
    }

    final colors = p.series;
    Color colorAt(int i) => colors[min(i, colors.length - 1)];
    final sel = _touched >= 0 && _touched < stats.byCategory.length ? _touched : 0;
    final selCat = stats.byCategory[sel];

    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 120), children: [
      // ── Donut by category ──
      Tile(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Label('By category'),
          SizedBox(
            height: 220,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 3,
                  centerSpaceRadius: 70,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, resp) {
                      final i = resp?.touchedSection?.touchedSectionIndex ?? -1;
                      if (event is FlTapUpEvent && i >= 0 && i != _touched) {
                        buzz(ref, Buzz.select);
                        setState(() => _touched = i);
                      }
                    },
                  ),
                  sections: [
                    for (var i = 0; i < stats.byCategory.length; i++)
                      PieChartSectionData(
                        value: stats.byCategory[i].total,
                        color: colorAt(i),
                        radius: i == sel ? 34 : 26,
                        showTitle: false,
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 250),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(selCat.category.iconData, color: p.ink),
                const SizedBox(height: 4),
                Text('${(selCat.total / stats.spent * 100).round()}%',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                Text(selCat.category.name,
                    style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < stats.byCategory.length; i++)
            _CatRow(
              ct: stats.byCategory[i],
              color: colorAt(i),
              share: stats.byCategory[i].total / stats.spent,
              money: money,
              selected: i == sel,
              onTap: () {
                buzz(ref, Buzz.select);
                setState(() => _touched = i);
              },
            ),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Daily bars ──
      Tile(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Label('Daily spending',
              trailing: stats.dailyBudget == null
                  ? null
                  : Text('— target ${money.compact(stats.dailyBudget!)}',
                      style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600))),
          _DailyBars(stats: stats, money: money),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Cumulative vs budget ──
      if (stats.byDay.length >= 2) ...[
        Tile(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Label(stats.budget == null ? 'Running total' : 'Running total vs budget'),
            _Cumulative(stats: stats, money: money),
          ]),
        ),
        const SizedBox(height: 12),
      ],

      // ── Quick facts ──
      _Facts(stats: stats, money: money),
      const SizedBox(height: 12),

      // ── Top expenses ──
      Tile(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Label('Biggest expenses'),
          for (var i = 0; i < stats.top.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showExpenseDetail(context, ref, stats.top[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: i == 0 ? p.ink : p.muted,
                            fontSize: 16)),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(stats.top[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(fmtDay(stats.top[i].date),
                          style: TextStyle(color: p.muted, fontSize: 12)),
                    ]),
                  ),
                  Text(money(stats.top[i].amount),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: tabular)),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _CatRow extends StatelessWidget {
  final CategoryTotal ct;
  final Color color;
  final double share;
  final Money money;
  final bool selected;
  final VoidCallback onTap;
  const _CatRow({
    required this.ct,
    required this.color,
    required this.share,
    required this.money,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? p.card : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: p.line),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ct.category.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${ct.count} ${ct.count == 1 ? 'expense' : 'expenses'}',
                  style: TextStyle(color: p.muted, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(ct.total),
                style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: tabular)),
            Text('${(share * 100).toStringAsFixed(share < 0.1 ? 1 : 0)}%',
                style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

class _DailyBars extends StatelessWidget {
  final TripStats stats;
  final Money money;
  const _DailyBars({required this.stats, required this.money});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final days = stats.byDay;
    final daily = stats.dailyBudget;
    final todayKey = dayKey(DateTime.now());
    final maxV = max(days.fold<double>(0, (m, e) => max(m, e.value)), daily ?? 0);
    final labelEvery = days.length <= 10 ? 1 : (days.length / 8).ceil();

    final chart = BarChart(
      BarChartData(
        maxY: maxV <= 0 ? 1 : maxV * 1.15,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= days.length || i % labelEvery != 0) return const SizedBox.shrink();
                final d = days[i].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    days.length <= 7 ? DateFormat('E').format(d) : DateFormat('d/M').format(d),
                    style: TextStyle(color: p.muted, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [
          if (daily != null)
            HorizontalLine(y: daily, color: p.muted, strokeWidth: 1.5, dashArray: [6, 4]),
        ]),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => p.ink,
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              '${fmtShort(days[group.x].key)}\n${money(rod.toY)}',
              TextStyle(color: p.bg, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: days[i].value,
                width: days.length > 20 ? 8 : 14,
                borderRadius: BorderRadius.circular(5),
                color: dayKey(days[i].key) == todayKey
                    ? p.accent
                    : (daily != null && days[i].value > daily)
                        ? p.danger
                        : p.ink,
                backDrawRodData: BackgroundBarChartRodData(
                    show: true, toY: maxV <= 0 ? 1 : maxV * 1.15, color: p.card),
              ),
            ]),
        ],
      ),
    );

    return LayoutBuilder(builder: (context, c) {
      final w = max(c.maxWidth, days.length * 22.0);
      final box = SizedBox(width: w, height: 180, child: chart);
      if (w <= c.maxWidth) return box;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // start at the latest days
        child: box,
      );
    });
  }
}

class _Cumulative extends StatelessWidget {
  final TripStats stats;
  final Money money;
  const _Cumulative({required this.stats, required this.money});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final days = stats.byDay;
    var run = 0.0;
    final spots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      run += days[i].value;
      spots.add(FlSpot(i.toDouble(), run));
    }
    final budget = stats.budget;
    final total = stats.totalDays;
    final paceEnd = total != null ? (total - 1).toDouble() : (days.length - 1).toDouble();
    final maxX = max(paceEnd, (days.length - 1).toDouble());
    final maxY = max(run, budget ?? 0) * 1.12;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX <= 0 ? 1 : maxX,
          minY: 0,
          maxY: maxY <= 0 ? 1 : maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: max(1, (maxX / 4).ceilToDouble()),
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('D${v.toInt() + 1}',
                      style: TextStyle(color: p.muted, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(horizontalLines: [
            if (budget != null)
              HorizontalLine(
                y: budget,
                color: p.danger.withValues(alpha: 0.6),
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topLeft,
                  style: TextStyle(color: p.muted, fontSize: 10, fontWeight: FontWeight.w700),
                  labelResolver: (_) => 'Budget ${money.compact(budget)}',
                ),
              ),
          ]),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => p.ink,
              getTooltipItems: (spots) => spots
                  .map((s) => s.barIndex == 0
                      ? LineTooltipItem(
                          'Day ${s.x.toInt() + 1}\n${money(s.y)}',
                          TextStyle(color: p.bg, fontWeight: FontWeight.w700, fontSize: 12),
                        )
                      : null)
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: p.ink,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: p.accent.withValues(alpha: 0.35)),
            ),
            if (budget != null && total != null)
              LineChartBarData(
                spots: [const FlSpot(0, 0), FlSpot(paceEnd, budget)],
                color: p.muted,
                barWidth: 1.5,
                dashArray: [4, 4],
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  final TripStats stats;
  final Money money;
  const _Facts({required this.stats, required this.money});

  @override
  Widget build(BuildContext context) {
    final big = stats.biggestDay;
    final facts = <(IconData, String, String)>[
      (Icons.trending_up_rounded, 'Avg per day', money(stats.avgPerDay)),
      if (big != null) (Icons.local_fire_department_rounded, 'Biggest day', '${money(big.value)} · ${fmtShort(big.key)}'),
      (Icons.pie_chart_rounded, 'Top category', stats.byCategory.first.category.name),
      (Icons.receipt_rounded, 'Avg per expense', money(stats.spent / stats.expenses.length)),
      if (stats.dailyBudget != null)
        (Icons.check_circle_rounded, 'Days on target', '${stats.underBudgetDays} of ${stats.elapsedDays}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: [
        for (final f in facts)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.p.card, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(f.$1, size: 20, color: context.p.ink),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(f.$3, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Text(f.$2,
                  style: TextStyle(color: context.p.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
  }
}
