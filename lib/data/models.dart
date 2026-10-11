import 'package:flutter/material.dart';

class Member {
  final String id;
  final String name;
  const Member({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Member.fromJson(Map<String, dynamic> j) =>
      Member(id: j['id'] as String, name: j['name'] as String);
}

/// The member id that always represents the phone owner.
const meId = 'me';

class Trip {
  final String id;
  final String title;
  final double? budget;
  final DateTime startDate;
  final DateTime? endDate;
  final List<Member> members;
  final bool closed;
  final DateTime createdAt;

  const Trip({
    required this.id,
    required this.title,
    required this.startDate,
    required this.createdAt,
    this.budget,
    this.endDate,
    this.members = const [Member(id: meId, name: 'You')],
    this.closed = false,
  });

  bool get hasBudget => budget != null && budget! > 0;
  bool get isGroup => members.length > 1;

  String memberName(String id) =>
      members.firstWhere((m) => m.id == id, orElse: () => const Member(id: '?', name: 'Someone')).name;

  Trip copyWith({
    String? title,
    double? budget,
    bool clearBudget = false,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEnd = false,
    List<Member>? members,
    bool? closed,
  }) =>
      Trip(
        id: id,
        title: title ?? this.title,
        budget: clearBudget ? null : (budget ?? this.budget),
        startDate: startDate ?? this.startDate,
        endDate: clearEnd ? null : (endDate ?? this.endDate),
        members: members ?? this.members,
        closed: closed ?? this.closed,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'budget': budget,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'members': members.map((m) => m.toJson()).toList(),
        'closed': closed,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'] as String,
        title: j['title'] as String,
        budget: (j['budget'] as num?)?.toDouble(),
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: j['endDate'] == null ? null : DateTime.parse(j['endDate'] as String),
        members: ((j['members'] as List?) ?? [])
            .map((e) => Member.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        closed: (j['closed'] as bool?) ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class Expense {
  final String id;
  final String tripId;
  final String title;

  /// Always in the home currency, so totals, budgets and splits never mix currencies.
  final double amount;

  /// Set when the expense was paid in another currency: what was actually paid,
  /// converted into [amount] with the rate the user entered.
  final String? origCurrency;
  final double? origAmount;
  final String categoryId;
  final DateTime date;
  final String paidBy;

  /// Member ids sharing this expense. Empty = split across everyone on the trip.
  final List<String> splitWith;
  final String note;

  /// File name inside the app's receipts folder (not a full path — iOS paths change).
  final String? photo;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.date,
    required this.createdAt,
    this.paidBy = meId,
    this.splitWith = const [],
    this.note = '',
    this.photo,
    this.origCurrency,
    this.origAmount,
  });

  bool get isForeign => origCurrency != null && origAmount != null;

  /// Home-currency units per one unit of [origCurrency].
  double? get rate => isForeign && origAmount! > 0 ? amount / origAmount! : null;

  Expense copyWith({
    String? title,
    double? amount,
    String? origCurrency,
    double? origAmount,
    bool clearForeign = false,
    String? categoryId,
    DateTime? date,
    String? paidBy,
    List<String>? splitWith,
    String? note,
    String? photo,
    bool clearPhoto = false,
  }) =>
      Expense(
        id: id,
        tripId: tripId,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        date: date ?? this.date,
        paidBy: paidBy ?? this.paidBy,
        splitWith: splitWith ?? this.splitWith,
        note: note ?? this.note,
        photo: clearPhoto ? null : (photo ?? this.photo),
        origCurrency: clearForeign ? null : (origCurrency ?? this.origCurrency),
        origAmount: clearForeign ? null : (origAmount ?? this.origAmount),
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'title': title,
        'amount': amount,
        'categoryId': categoryId,
        'date': date.toIso8601String(),
        'paidBy': paidBy,
        'splitWith': splitWith,
        'note': note,
        'photo': photo,
        'origCurrency': origCurrency,
        'origAmount': origAmount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        tripId: j['tripId'] as String,
        title: j['title'] as String,
        amount: (j['amount'] as num).toDouble(),
        categoryId: j['categoryId'] as String,
        date: DateTime.parse(j['date'] as String),
        paidBy: (j['paidBy'] as String?) ?? meId,
        splitWith: ((j['splitWith'] as List?) ?? []).cast<String>(),
        note: (j['note'] as String?) ?? '',
        photo: j['photo'] as String?,
        origCurrency: j['origCurrency'] as String?,
        origAmount: (j['origAmount'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class SpendCategory {
  final String id;
  final String name;
  final String icon;
  final bool preset;
  const SpendCategory({required this.id, required this.name, required this.icon, this.preset = false});

  IconData get iconData => categoryIcons[icon] ?? Icons.more_horiz_rounded;

  SpendCategory copyWith({String? name, String? icon}) =>
      SpendCategory(id: id, name: name ?? this.name, icon: icon ?? this.icon, preset: preset);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'icon': icon, 'preset': preset};
  factory SpendCategory.fromJson(Map<String, dynamic> j) => SpendCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String,
        preset: (j['preset'] as bool?) ?? false,
      );
}

/// Icons are referenced by key so release builds can tree-shake icon fonts.
const categoryIcons = <String, IconData>{
  'food': Icons.restaurant_rounded,
  'transport': Icons.directions_bus_rounded,
  'stay': Icons.hotel_rounded,
  'activity': Icons.local_activity_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'other': Icons.more_horiz_rounded,
  'coffee': Icons.coffee_rounded,
  'drinks': Icons.local_bar_rounded,
  'flight': Icons.flight_rounded,
  'train': Icons.train_rounded,
  'taxi': Icons.local_taxi_rounded,
  'car': Icons.directions_car_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'bike': Icons.pedal_bike_rounded,
  'hike': Icons.hiking_rounded,
  'beach': Icons.beach_access_rounded,
  'museum': Icons.museum_rounded,
  'ticket': Icons.confirmation_number_rounded,
  'camera': Icons.photo_camera_rounded,
  'gift': Icons.card_giftcard_rounded,
  'health': Icons.medical_services_rounded,
  'spa': Icons.spa_rounded,
  'sim': Icons.sim_card_rounded,
  'wifi': Icons.wifi_rounded,
  'laundry': Icons.local_laundry_service_rounded,
  'cash': Icons.local_atm_rounded,
  'tips': Icons.volunteer_activism_rounded,
  'visa': Icons.badge_rounded,
  'groceries': Icons.local_grocery_store_rounded,
  'fitness': Icons.fitness_center_rounded,
};

const presetCategories = <SpendCategory>[
  SpendCategory(id: 'food', name: 'Food', icon: 'food', preset: true),
  SpendCategory(id: 'transport', name: 'Transport', icon: 'transport', preset: true),
  SpendCategory(id: 'stay', name: 'Stay', icon: 'stay', preset: true),
  SpendCategory(id: 'activity', name: 'Activities', icon: 'activity', preset: true),
  SpendCategory(id: 'shopping', name: 'Shopping', icon: 'shopping', preset: true),
  SpendCategory(id: 'other', name: 'Other', icon: 'other', preset: true),
];

class AppSettings {
  final bool onboarded;
  final String currency;
  final ThemeMode themeMode;
  final bool haptics;

  /// Days (yyyy-MM-dd) on which the user logged at least one expense.
  final Set<String> logDays;

  /// Badge ids the user has already been congratulated for.
  final Set<String> seenBadges;

  /// Last exchange rate the user entered per foreign currency
  /// (home-currency units per one foreign unit). Works offline.
  final Map<String, double> rates;

  const AppSettings({
    this.onboarded = false,
    this.currency = 'USD',
    this.themeMode = ThemeMode.system,
    this.haptics = true,
    this.logDays = const {},
    this.seenBadges = const {},
    this.rates = const {},
  });

  AppSettings copyWith({
    bool? onboarded,
    String? currency,
    ThemeMode? themeMode,
    bool? haptics,
    Set<String>? logDays,
    Set<String>? seenBadges,
    Map<String, double>? rates,
  }) =>
      AppSettings(
        onboarded: onboarded ?? this.onboarded,
        currency: currency ?? this.currency,
        themeMode: themeMode ?? this.themeMode,
        haptics: haptics ?? this.haptics,
        logDays: logDays ?? this.logDays,
        seenBadges: seenBadges ?? this.seenBadges,
        rates: rates ?? this.rates,
      );

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'currency': currency,
        'themeMode': themeMode.name,
        'haptics': haptics,
        'logDays': logDays.toList(),
        'seenBadges': seenBadges.toList(),
        'rates': rates,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        onboarded: (j['onboarded'] as bool?) ?? false,
        currency: (j['currency'] as String?) ?? 'USD',
        themeMode: ThemeMode.values.firstWhere((m) => m.name == j['themeMode'],
            orElse: () => ThemeMode.system),
        haptics: (j['haptics'] as bool?) ?? true,
        logDays: ((j['logDays'] as List?) ?? []).cast<String>().toSet(),
        seenBadges: ((j['seenBadges'] as List?) ?? []).cast<String>().toSet(),
        rates: {
          for (final e in ((j['rates'] as Map?) ?? {}).entries)
            e.key as String: (e.value as num).toDouble(),
        },
      );
}
