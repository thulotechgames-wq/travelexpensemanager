import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'trip_form_sheet.dart';

class SplitTab extends ConsumerWidget {
  final String tripId;
  const SplitTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(tripStatsProvider(tripId));
    if (stats == null) return const SizedBox.shrink();
    final p = context.p;
    final money = ref.watch(moneyProvider);
    final trip = stats.trip;

    if (!trip.isGroup) {
      return ListView(children: [
        EmptyState(
          icon: Icons.groups_rounded,
          title: 'Travelling with friends?',
          subtitle:
              'Add the people on this trip. Log who paid, and we\'ll work out who owes whom.',
          action: SizedBox(
            width: 200,
            child: FilledButton(
              onPressed: () => showTripForm(context, trip: trip),
              child: const Text('Add people'),
            ),
          ),
        ),
      ]);
    }

    final maxPaid = stats.balances.fold<double>(0, (m, b) => b.paid > m ? b.paid : m);

    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 120), children: [
      Tile(
        color: p.ink,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SETTLE UP',
              style: TextStyle(
                  color: p.bg.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          if (stats.settlements.isEmpty)
            Row(children: [
              Icon(Icons.check_circle_rounded, color: p.accent),
              const SizedBox(width: 10),
              Text('All square. Nobody owes anything.',
                  style: TextStyle(color: p.bg, fontWeight: FontWeight.w700)),
            ]),
          for (final s in stats.settlements)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: s.from.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(
                          text: '  pays  ',
                          style: TextStyle(color: p.bg.withValues(alpha: 0.5))),
                      TextSpan(text: s.to.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                    style: TextStyle(color: p.bg, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration:
                      BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(20)),
                  child: Text(money.exact(s.amount),
                      style: TextStyle(
                          color: p.onAccent, fontWeight: FontWeight.w800, fontFeatures: tabular)),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Tile(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Label('Who paid what'),
          for (final b in stats.balances)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: p.card,
                    child: Text(b.member.name.characters.first.toUpperCase(),
                        style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.member.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('Paid ${money(b.paid)} · share ${money(b.share)}',
                          style: TextStyle(color: p.muted, fontSize: 12)),
                    ]),
                  ),
                  Text(
                    b.balance.abs() < 0.005
                        ? 'settled'
                        : '${b.balance > 0 ? '+' : '−'}${money.exact(b.balance.abs())}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFeatures: tabular,
                      color: b.balance < -0.005 ? p.danger : p.ink,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxPaid == 0 ? 0 : b.paid / maxPaid,
                    minHeight: 6,
                    backgroundColor: p.card,
                    color: p.ink,
                  ),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          '+ means the group owes them, − means they owe the group. '
          'Settle-up uses the fewest possible payments.',
          style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
        ),
      ),
    ]);
  }
}
