import 'dart:math';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/models.dart';
import 'stats.dart';

class StreakInfo {
  final int current;
  final int best;
  final bool loggedToday;

  /// Last 7 days, oldest first. true = logged that day.
  final List<bool> week;
  const StreakInfo(this.current, this.best, this.loggedToday, this.week);

  static StreakInfo from(Set<String> days) {
    final today = dateOnly(DateTime.now());
    bool has(DateTime d) => days.contains(dayKey(d));
    final loggedToday = has(today);

    var cur = 0;
    var d = loggedToday ? today : DateTime(today.year, today.month, today.day - 1);
    while (has(d)) {
      cur++;
      d = DateTime(d.year, d.month, d.day - 1);
    }

    final sorted = days.map(parseDayKey).toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final x in sorted) {
      run = (prev != null && dayDiff(prev, x) == 1) ? run + 1 : 1;
      best = max(best, run);
      prev = x;
    }

    final week = List.generate(7, (i) => has(DateTime(today.year, today.month, today.day - 6 + i)));
    return StreakInfo(cur, max(best, cur), loggedToday, week);
  }
}

class BadgeCtx {
  final List<Trip> trips;
  final List<Expense> expenses;
  final List<SpendCategory> categories;
  final StreakInfo streak;
  final Map<String, TripStats> stats;
  const BadgeCtx(this.trips, this.expenses, this.categories, this.streak, this.stats);
}

class BadgeDef {
  final String id;
  final String title;
  final String desc;
  final IconData icon;

  /// Progress 0..1 — 1 means unlocked.
  final double Function(BadgeCtx c) progress;
  const BadgeDef(this.id, this.title, this.desc, this.icon, this.progress);
}

class BadgeStatus {
  final BadgeDef def;
  final double progress;
  bool get unlocked => progress >= 1;
  const BadgeStatus(this.def, this.progress);
}

double _ratio(num v, num goal) => min(1, v / goal).toDouble();

final badgeDefs = <BadgeDef>[
  BadgeDef('first_trip', 'Boarding pass', 'Create your first trip', Icons.flight_takeoff_rounded,
      (c) => _ratio(c.trips.length, 1)),
  BadgeDef('first_expense', 'First coin', 'Log your first expense', Icons.toll_rounded,
      (c) => _ratio(c.expenses.length, 1)),
  BadgeDef('streak_3', 'Warming up', 'Log expenses 3 days in a row',
      Icons.local_fire_department_rounded, (c) => _ratio(c.streak.best, 3)),
  BadgeDef('streak_7', 'On fire', 'Keep a 7-day logging streak', Icons.whatshot_rounded,
      (c) => _ratio(c.streak.best, 7)),
  BadgeDef('streak_30', 'Unbreakable', 'Keep a 30-day logging streak', Icons.bolt_rounded,
      (c) => _ratio(c.streak.best, 30)),
  BadgeDef('expenses_50', 'Bookkeeper', 'Log 50 expenses', Icons.receipt_long_rounded,
      (c) => _ratio(c.expenses.length, 50)),
  BadgeDef('expenses_250', 'Ledger legend', 'Log 250 expenses', Icons.menu_book_rounded,
      (c) => _ratio(c.expenses.length, 250)),
  BadgeDef('trips_3', 'Globetrotter', 'Create 3 trips', Icons.public_rounded,
      (c) => _ratio(c.trips.length, 3)),
  BadgeDef('trips_10', 'Nomad', 'Create 10 trips', Icons.explore_rounded,
      (c) => _ratio(c.trips.length, 10)),
  BadgeDef('under_budget', 'Smart spender', 'Finish a trip under budget', Icons.savings_rounded,
      (c) => c.trips.any((t) =>
              t.closed && t.hasBudget && (c.stats[t.id]?.spent ?? 0) <= t.budget!)
          ? 1.0
          : 0.0),
  BadgeDef('receipts_10', 'Paper trail', 'Attach 10 receipt photos', Icons.photo_camera_rounded,
      (c) => _ratio(c.expenses.where((e) => e.photo != null).length, 10)),
  BadgeDef('group', 'Squad goals', 'Split a trip with friends', Icons.groups_rounded,
      (c) => c.trips.any((t) => t.isGroup && (c.stats[t.id]?.expenses.isNotEmpty ?? false))
          ? 1.0
          : 0.0),
  BadgeDef('custom_cat', 'Organizer', 'Create a custom category', Icons.category_rounded,
      (c) => c.categories.any((x) => !x.preset) ? 1.0 : 0.0),
  BadgeDef('explorer', 'Explorer', 'Use 6 different categories in one trip',
      Icons.travel_explore_rounded,
      (c) => c.stats.values.fold<double>(0, (m, s) => max(m, _ratio(s.byCategory.length, 6)))),
];
