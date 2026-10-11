import 'dart:math';

import '../core/format.dart';
import '../data/models.dart';

enum Health { none, good, warn, over }

class CategoryTotal {
  final SpendCategory category;
  final double total;
  final int count;
  const CategoryTotal(this.category, this.total, this.count);
}

class MemberBalance {
  final Member member;
  final double paid;
  final double share;
  double get balance => paid - share;
  const MemberBalance(this.member, this.paid, this.share);
}

class Settlement {
  final Member from;
  final Member to;
  final double amount;
  const Settlement(this.from, this.to, this.amount);
}

class TripStats {
  final Trip trip;
  final List<Expense> expenses;
  final double spent;
  final List<CategoryTotal> byCategory;

  /// Every day from trip start to the last relevant day, with totals (0 for empty days).
  final List<MapEntry<DateTime, double>> byDay;
  final int elapsedDays;
  final int? totalDays;
  final double todaySpent;
  final List<MemberBalance> balances;
  final List<Settlement> settlements;

  TripStats._({
    required this.trip,
    required this.expenses,
    required this.spent,
    required this.byCategory,
    required this.byDay,
    required this.elapsedDays,
    required this.totalDays,
    required this.todaySpent,
    required this.balances,
    required this.settlements,
  });

  double? get budget => trip.hasBudget ? trip.budget : null;
  double? get remaining => budget == null ? null : budget! - spent;
  double get pct => budget == null ? 0 : spent / budget!;

  Health get health {
    if (budget == null) return Health.none;
    if (pct >= 1) return Health.over;
    if (pct >= 0.8) return Health.warn;
    return Health.good;
  }

  /// Planned spend per day (only when trip has budget and end date).
  double? get dailyBudget =>
      (budget != null && totalDays != null) ? budget! / totalDays! : null;

  /// What you can still spend per day from today until the trip ends.
  double? get leftPerDay {
    if (budget == null || trip.endDate == null) return null;
    final today = dateOnly(DateTime.now());
    final end = dateOnly(trip.endDate!);
    if (today.isAfter(end)) return null;
    final start = dateOnly(trip.startDate);
    final from = today.isBefore(start) ? start : today;
    final daysLeft = daysBetween(from, end);
    return max(0, remaining!) / daysLeft;
  }

  /// Today's fair share of the budget: what was left this morning ÷ days left including today.
  /// Only for an open trip with a budget and end date, while it is running.
  double? get todayAllowance {
    if (budget == null || trip.endDate == null || trip.closed) return null;
    final today = dateOnly(DateTime.now());
    final end = dateOnly(trip.endDate!);
    if (today.isBefore(dateOnly(trip.startDate)) || today.isAfter(end)) return null;
    return max(0, budget! - (spent - todaySpent)) / daysBetween(today, end);
  }

  /// How much more can be spent today and still finish on budget. Negative = over today's share.
  double? get safeToday => todayAllowance == null ? null : todayAllowance! - todaySpent;

  /// Daily share from tomorrow on, given everything spent so far.
  double? get tomorrowAllowance {
    if (todayAllowance == null) return null;
    final daysAfterToday = daysBetween(dateOnly(DateTime.now()), trip.endDate!) - 1;
    return daysAfterToday <= 0 ? null : max(0, remaining!) / daysAfterToday;
  }

  double get avgPerDay => elapsedDays == 0 ? 0 : spent / elapsedDays;

  MapEntry<DateTime, double>? get biggestDay {
    if (byDay.isEmpty) return null;
    return byDay.reduce((a, b) => b.value > a.value ? b : a);
  }

  List<Expense> get top => (List.of(expenses)..sort((a, b) => b.amount.compareTo(a.amount)))
      .take(5)
      .toList();

  /// Days that stayed under the daily budget ("clean days") — a little game stat.
  int get underBudgetDays {
    final d = dailyBudget;
    if (d == null) return 0;
    final today = dateOnly(DateTime.now());
    return byDay.where((e) => !e.key.isAfter(today) && e.value <= d).length;
  }

  static TripStats compute(Trip trip, List<Expense> all, Map<String, SpendCategory> cats) {
    final ex = all.where((e) => e.tripId == trip.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final spent = ex.fold<double>(0, (s, e) => s + e.amount);

    // Categories
    final catTotals = <String, double>{};
    final catCounts = <String, int>{};
    for (final e in ex) {
      final id = cats.containsKey(e.categoryId) ? e.categoryId : 'other';
      catTotals[id] = (catTotals[id] ?? 0) + e.amount;
      catCounts[id] = (catCounts[id] ?? 0) + 1;
    }
    final fallback = presetCategories.last;
    final byCat = catTotals.entries
        .map((m) => CategoryTotal(cats[m.key] ?? fallback, m.value, catCounts[m.key] ?? 0))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    // Days
    final today = dateOnly(DateTime.now());
    final start = dateOnly(trip.startDate);
    DateTime last = trip.endDate != null ? dateOnly(trip.endDate!) : today;
    if (trip.endDate != null && last.isAfter(today) && !trip.closed) last = today;
    for (final e in ex) {
      final d = dateOnly(e.date);
      if (d.isAfter(last)) last = d;
    }
    DateTime first = start;
    for (final e in ex) {
      final d = dateOnly(e.date);
      if (d.isBefore(first)) first = d;
    }
    if (last.isBefore(first)) last = first;
    final dayTotals = <String, double>{};
    for (final e in ex) {
      final k = dayKey(e.date);
      dayTotals[k] = (dayTotals[k] ?? 0) + e.amount;
    }
    final byDay = <MapEntry<DateTime, double>>[];
    for (var d = first; !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) {
      byDay.add(MapEntry(d, dayTotals[dayKey(d)] ?? 0));
      if (byDay.length > 400) break; // safety for very long trips
    }

    final elapsed = today.isBefore(start) ? 0 : byDay.where((e) => !e.key.isAfter(today)).length;
    final totalDays = trip.endDate == null ? null : daysBetween(start, trip.endDate!);

    // Split
    final paid = {for (final m in trip.members) m.id: 0.0};
    final share = {for (final m in trip.members) m.id: 0.0};
    final memberIds = trip.members.map((m) => m.id).toSet();
    for (final e in ex) {
      if (memberIds.contains(e.paidBy)) paid[e.paidBy] = paid[e.paidBy]! + e.amount;
      var sharers = e.splitWith.where(memberIds.contains).toList();
      if (sharers.isEmpty) sharers = memberIds.toList();
      final part = e.amount / sharers.length;
      for (final id in sharers) {
        share[id] = share[id]! + part;
      }
    }
    final balances =
        trip.members.map((m) => MemberBalance(m, paid[m.id]!, share[m.id]!)).toList();

    return TripStats._(
      trip: trip,
      expenses: ex,
      spent: spent,
      byCategory: byCat,
      byDay: byDay,
      elapsedDays: elapsed,
      totalDays: totalDays,
      todaySpent: dayTotals[dayKey(today)] ?? 0,
      balances: balances,
      settlements: _settle(balances),
    );
  }

  /// Greedy minimal-transfers settlement.
  static List<Settlement> _settle(List<MemberBalance> balances) {
    final debtors = balances
        .where((b) => b.balance < -0.005)
        .map((b) => [b.member, -b.balance])
        .toList();
    final creditors = balances
        .where((b) => b.balance > 0.005)
        .map((b) => [b.member, b.balance])
        .toList();
    debtors.sort((a, b) => (b[1] as double).compareTo(a[1] as double));
    creditors.sort((a, b) => (b[1] as double).compareTo(a[1] as double));
    final out = <Settlement>[];
    var i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final d = debtors[i][1] as double;
      final c = creditors[j][1] as double;
      final amt = min(d, c);
      out.add(Settlement(debtors[i][0] as Member, creditors[j][0] as Member, amt));
      debtors[i][1] = d - amt;
      creditors[j][1] = c - amt;
      if ((debtors[i][1] as double) < 0.005) i++;
      if ((creditors[j][1] as double) < 0.005) j++;
    }
    return out;
  }
}
