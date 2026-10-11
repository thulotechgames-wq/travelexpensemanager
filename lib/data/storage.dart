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

  static Future<Storage> open() async => openAt(await getApplicationDocumentsDirectory());

  /// Opens storage inside [dir]; tests pass a temporary folder.
  static Future<Storage> openAt(Directory dir) async {
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

  // Backup: one self-contained JSON file (receipts embedded) the user keeps in
  // Files / iCloud Drive / Google Drive. No account or server involved.
  static const backupFormat = 'expensetracker-backup';

  Future<Map<String, dynamic>> exportAll() async {
    final receipts = <String, String>{};
    if (await receiptsDir.exists()) {
      await for (final f in receiptsDir.list()) {
        if (f is File) receipts[f.uri.pathSegments.last] = base64Encode(await f.readAsBytes());
      }
    }
    return {
      'format': backupFormat,
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'settings': loadSettings().toJson(),
      'categories': loadCategories().map((c) => c.toJson()).toList(),
      'trips': loadTrips().map((t) => t.toJson()).toList(),
      'expenses': loadExpenses().map((e) => e.toJson()).toList(),
      'receipts': receipts,
    };
  }

  /// Throws [FormatException] if [data] is not a backup made by this app.
  static BackupSummary inspectBackup(Map<String, dynamic> data) {
    if (data['format'] != backupFormat) throw const FormatException('Not a backup file');
    return BackupSummary(
      DateTime.tryParse(data['createdAt'] as String? ?? ''),
      (data['trips'] as List).length,
      (data['expenses'] as List).length,
    );
  }

  /// Replaces everything on this device with the backup. Parses it fully first,
  /// so a broken file leaves the current data untouched.
  Future<void> importAll(Map<String, dynamic> data) async {
    inspectBackup(data);
    Map<String, dynamic> m(Object? e) => Map<String, dynamic>.from(e as Map);
    final settings = AppSettings.fromJson(m(data['settings'])).copyWith(onboarded: true);
    final cats = (data['categories'] as List).map((e) => SpendCategory.fromJson(m(e))).toList();
    final trips = (data['trips'] as List).map((e) => Trip.fromJson(m(e))).toList();
    final expenses = (data['expenses'] as List).map((e) => Expense.fromJson(m(e))).toList();
    final receipts = {
      for (final e in m(data['receipts'] ?? const {}).entries)
        e.key: base64Decode(e.value as String),
    };

    await wipe();
    await saveSettings(settings);
    await saveCategories(cats);
    for (final t in trips) {
      await putTrip(t);
    }
    for (final e in expenses) {
      await putExpense(e);
    }
    for (final r in receipts.entries) {
      // Names come from the file; never let one escape the receipts folder.
      if (r.key.contains('/') || r.key.contains('..')) continue;
      await receiptFile(r.key).writeAsBytes(r.value);
    }
  }

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

class BackupSummary {
  final DateTime? createdAt;
  final int trips;
  final int expenses;
  const BackupSummary(this.createdAt, this.trips, this.expenses);
}
