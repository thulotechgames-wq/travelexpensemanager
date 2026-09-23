import 'package:expensetracker/core/format.dart';
import 'package:expensetracker/data/models.dart';
import 'package:expensetracker/state/stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keypad expressions', () {
    expect(evalExpr('120+45.5−10'), 155.5);
    expect(evalExpr(''), 0);
    expect(evalExpr('5−10'), 0); // never negative
  });

  test('group split settles with minimal payments', () {
    final trip = Trip(
      id: 't',
      title: 'Test',
      startDate: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      members: const [Member(id: meId, name: 'You'), Member(id: 'a', name: 'Asha')],
    );
    final e = Expense(
      id: 'e',
      tripId: 't',
      title: 'Hotel',
      amount: 100,
      categoryId: 'stay',
      date: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );
    final s = TripStats.compute(trip, [e], {for (final c in presetCategories) c.id: c});
    expect(s.spent, 100);
    expect(s.settlements.length, 1);
    expect(s.settlements.first.from.name, 'Asha');
    expect(s.settlements.first.amount, 50);
  });
}
