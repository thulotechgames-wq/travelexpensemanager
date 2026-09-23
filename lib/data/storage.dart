import 'dart:convert';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Offline, on-device storage. Each record is stored as a JSON string in a Hive box.
/// Everything goes through this class, so adding cloud sync later means
/// swapping/extending this repository only.
class Storage {
  Storage._(this._trips, this._expenses, this._categories, this._meta, this.docsDir);

  final Box<String> _trips;
  final Box<String> _expenses;
  final Box<String> _categories;
  final Box<String> _meta;
  final Directory docsDir;

  static Future<Storage> open() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init('${dir.path}/db');
    final s = Storage._(
      await Hive.openBox<String>('trips'),
      await Hive.openBox<String>('expenses'),
      await Hive.openBox<String>('categories'),
      await Hive.openBox<String>('meta'),
      dir,
    );
    await s.receiptsDir.create(recursive: true);
    return s;
  }

  Directory get receiptsDir => Directory('${docsDir.path}/receipts');
  File receiptFile(String name) => File('${receiptsDir.path}/$name');

  Map<String, dynamic> _decode(String s) => Map<String, dynamic>.from(jsonDecode(s) as Map);

  // Settings
  AppSettings loadSettings() {
    final raw = _meta.get('settings');
    return raw == null ? const AppSettings() : AppSettings.fromJson(_decode(raw));
  }

  Future<void> saveSettings(AppSettings s) => _meta.put('settings', jsonEncode(s.toJson()));

  // Trips
  List<Trip> loadTrips() => _trips.values.map((v) => Trip.fromJson(_decode(v))).toList();
  Future<void> putTrip(Trip t) => _trips.put(t.id, jsonEncode(t.toJson()));
  Future<void> deleteTrip(String id) => _trips.delete(id);

  // Expenses
  List<Expense> loadExpenses() =>
      _expenses.values.map((v) => Expense.fromJson(_decode(v))).toList();
  Future<void> putExpense(Expense e) => _expenses.put(e.id, jsonEncode(e.toJson()));
  Future<void> deleteExpense(String id) => _expenses.delete(id);

  // Categories (ordered list stored as one record so order is preserved)
  List<SpendCategory> loadCategories() {
    final raw = _categories.get('all');
    if (raw == null) return List.of(presetCategories);
    return (jsonDecode(raw) as List)
        .map((e) => SpendCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveCategories(List<SpendCategory> list) =>
      _categories.put('all', jsonEncode(list.map((c) => c.toJson()).toList()));

  Future<void> wipe() async {
    await _trips.clear();
    await _expenses.clear();
    await _categories.clear();
    await _meta.clear();
    if (await receiptsDir.exists()) {
      await receiptsDir.delete(recursive: true);
      await receiptsDir.create(recursive: true);
    }
  }
}
