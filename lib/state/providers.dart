import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/currencies.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../data/storage.dart';
import 'gamification.dart';
import 'stats.dart';

/// Overridden in main() with the opened storage.
final storageProvider = Provider<Storage>((ref) => throw UnimplementedError());

// ─── Settings ────────────────────────────────────────────────────────────────
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(storageProvider).loadSettings();

  Future<void> _save(AppSettings s) async {
    state = s;
    await ref.read(storageProvider).saveSettings(s);
  }

  Future<void> setCurrency(String code) => _save(state.copyWith(currency: code));
  Future<void> finishOnboarding(String code) =>
      _save(state.copyWith(currency: code, onboarded: true));
  Future<void> setThemeMode(ThemeMode m) => _save(state.copyWith(themeMode: m));
  Future<void> setHaptics(bool v) => _save(state.copyWith(haptics: v));
  Future<void> logToday() {
    final k = dayKey(DateTime.now());
    if (state.logDays.contains(k)) return Future.value();
    return _save(state.copyWith(logDays: {...state.logDays, k}));
  }

  Future<void> markBadgesSeen(Iterable<String> ids) =>
      _save(state.copyWith(seenBadges: {...state.seenBadges, ...ids}));

  void reload() => state = ref.read(storageProvider).loadSettings();
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final currencyProvider = Provider<Currency>((ref) => currencyFor(ref.watch(settingsProvider).currency));
final moneyProvider = Provider<Money>((ref) => Money(ref.watch(currencyProvider)));

// ─── Trips ───────────────────────────────────────────────────────────────────
class TripsNotifier extends Notifier<List<Trip>> {
  @override
  List<Trip> build() => _sorted(ref.watch(storageProvider).loadTrips());

  List<Trip> _sorted(List<Trip> l) => l..sort((a, b) => b.startDate.compareTo(a.startDate));

  Future<void> upsert(Trip t) async {
    state = _sorted([...state.where((x) => x.id != t.id), t]);
    await ref.read(storageProvider).putTrip(t);
  }

  Future<void> remove(String id) async {
    state = state.where((t) => t.id != id).toList();
    await ref.read(storageProvider).deleteTrip(id);
    await ref.read(expensesProvider.notifier).removeForTrip(id);
  }

  void reload() => state = _sorted(ref.read(storageProvider).loadTrips());
}

final tripsProvider = NotifierProvider<TripsNotifier, List<Trip>>(TripsNotifier.new);

final tripProvider = Provider.family<Trip?, String>((ref, id) {
  for (final t in ref.watch(tripsProvider)) {
    if (t.id == id) return t;
  }
  return null;
});

// ─── Expenses ────────────────────────────────────────────────────────────────
class ExpensesNotifier extends Notifier<List<Expense>> {
  @override
  List<Expense> build() => ref.watch(storageProvider).loadExpenses();

  Storage get _db => ref.read(storageProvider);

  Future<void> upsert(Expense e, {bool isNew = false}) async {
    state = [...state.where((x) => x.id != e.id), e];
    await _db.putExpense(e);
    if (isNew) await ref.read(settingsProvider.notifier).logToday();
  }

  /// Removes from the list but keeps the receipt file so "Undo" can restore it.
  Future<Expense?> remove(String id) async {
    Expense? removed;
    for (final e in state) {
      if (e.id == id) removed = e;
    }
    state = state.where((x) => x.id != id).toList();
    await _db.deleteExpense(id);
    return removed;
  }

  Future<void> deletePhoto(String? name) async {
    if (name == null) return;
    final f = _db.receiptFile(name);
    if (await f.exists()) await f.delete();
  }

  Future<void> removeForTrip(String tripId) async {
    final gone = state.where((e) => e.tripId == tripId).toList();
    state = state.where((e) => e.tripId != tripId).toList();
    for (final e in gone) {
      await _db.deleteExpense(e.id);
      await deletePhoto(e.photo);
    }
  }

  void reload() => state = _db.loadExpenses();
}

final expensesProvider = NotifierProvider<ExpensesNotifier, List<Expense>>(ExpensesNotifier.new);

// ─── Categories ──────────────────────────────────────────────────────────────
class CategoriesNotifier extends Notifier<List<SpendCategory>> {
  @override
  List<SpendCategory> build() => ref.watch(storageProvider).loadCategories();

  Future<void> _save(List<SpendCategory> l) async {
    state = l;
    await ref.read(storageProvider).saveCategories(l);
  }

  Future<void> add(String name, String icon) =>
      _save([...state, SpendCategory(id: newId(), name: name, icon: icon)]);

  Future<void> edit(SpendCategory c) => _save([for (final x in state) x.id == c.id ? c : x]);

  Future<void> remove(String id) => _save(state.where((c) => c.id != id).toList());

  Future<void> reorder(int oldIndex, int newIndex) {
    final l = List.of(state);
    if (newIndex > oldIndex) newIndex -= 1;
    l.insert(newIndex, l.removeAt(oldIndex));
    return _save(l);
  }

  void reload() => state = ref.read(storageProvider).loadCategories();
}

final categoriesProvider =
    NotifierProvider<CategoriesNotifier, List<SpendCategory>>(CategoriesNotifier.new);

final categoryMapProvider = Provider<Map<String, SpendCategory>>(
    (ref) => {for (final c in ref.watch(categoriesProvider)) c.id: c});

// ─── Derived ─────────────────────────────────────────────────────────────────
final tripStatsProvider = Provider.family<TripStats?, String>((ref, id) {
  final trip = ref.watch(tripProvider(id));
  if (trip == null) return null;
  return TripStats.compute(trip, ref.watch(expensesProvider), ref.watch(categoryMapProvider));
});

final allStatsProvider = Provider<Map<String, TripStats>>((ref) {
  final cats = ref.watch(categoryMapProvider);
  final ex = ref.watch(expensesProvider);
  return {for (final t in ref.watch(tripsProvider)) t.id: TripStats.compute(t, ex, cats)};
});

final streakProvider =
    Provider<StreakInfo>((ref) => StreakInfo.from(ref.watch(settingsProvider).logDays));

final badgesProvider = Provider<List<BadgeStatus>>((ref) {
  final ctx = BadgeCtx(
    ref.watch(tripsProvider),
    ref.watch(expensesProvider),
    ref.watch(categoriesProvider),
    ref.watch(streakProvider),
    ref.watch(allStatsProvider),
  );
  return badgeDefs.map((d) => BadgeStatus(d, d.progress(ctx))).toList();
});

/// Resolves a stored receipt name to a file on disk.
final receiptFileProvider =
    Provider.family<File, String>((ref, name) => ref.watch(storageProvider).receiptFile(name));
