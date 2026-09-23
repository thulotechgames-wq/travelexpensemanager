import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../expense/expense_detail_sheet.dart';
import '../expense/quick_add_sheet.dart';

class ExpensesTab extends ConsumerStatefulWidget {
  final String tripId;
  const ExpensesTab({super.key, required this.tripId});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab>
    with AutomaticKeepAliveClientMixin {
  String _q = '';
  String? _cat;
  bool _searching = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _delete(Expense e) async {
    buzz(ref, Buzz.medium);
    final notifier = ref.read(expensesProvider.notifier);
    await notifier.remove(e.id);
    if (!mounted) return;
    var undone = false;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    final ctrl = m.showSnackBar(SnackBar(
      content: Text('Deleted "${e.title}"'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          undone = true;
          notifier.upsert(e);
        },
      ),
    ));
    await ctrl.closed;
    if (!undone) await notifier.deletePhoto(e.photo);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.p;
    final stats = ref.watch(tripStatsProvider(widget.tripId));
    if (stats == null) return const SizedBox.shrink();
    final money = ref.watch(moneyProvider);
    final cats = ref.watch(categoryMapProvider);
    final trip = stats.trip;

    if (stats.expenses.isEmpty) {
      return ListView(children: [
        EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No expenses yet',
          subtitle: trip.closed
              ? 'This trip is completed.'
              : 'Tap "Add expense" and log your first spend. It takes three taps.',
          action: trip.closed
              ? null
              : SizedBox(
                  width: 200,
                  child: FilledButton(
                    onPressed: () => showQuickAdd(context, ref, trip.id),
                    child: const Text('Add expense'),
                  ),
                ),
        ),
      ]);
    }

    final q = _q.toLowerCase();
    final list = stats.expenses.where((e) {
      if (_cat != null && e.categoryId != _cat) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          e.note.toLowerCase().contains(q) ||
          (cats[e.categoryId]?.name.toLowerCase().contains(q) ?? false);
    }).toList();

    // Group by day (already sorted newest first)
    final groups = <String, List<Expense>>{};
    for (final e in list) {
      groups.putIfAbsent(dayKey(e.date), () => []).add(e);
    }
    final filteredTotal = list.fold<double>(0, (s, e) => s + e.amount);

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  Pill('All', selected: _cat == null, onTap: () => setState(() => _cat = null)),
                  for (final c in stats.byCategory) ...[
                    const SizedBox(width: 6),
                    Pill(c.category.name,
                        icon: c.category.iconData,
                        selected: _cat == c.category.id,
                        onTap: () {
                          buzz(ref, Buzz.select);
                          setState(() => _cat = _cat == c.category.id ? null : c.category.id);
                        }),
                  ],
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: () => setState(() {
                _searching = !_searching;
                if (!_searching) _q = '';
              }),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: _searching ? p.ink : p.card, shape: BoxShape.circle),
                child: Icon(_searching ? Icons.close_rounded : Icons.search_rounded,
                    size: 20, color: _searching ? p.bg : p.ink),
              ),
            ),
          ]),
        ),
      ),
      if (_searching)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Search title, note, category',
                  prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
        ),
      if (_cat != null || _q.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text('${list.length} results · ${money(filteredTotal)}',
                style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
          ),
        ),
      for (final entry in groups.entries) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 6),
            child: Row(children: [
              Expanded(
                child: Text(fmtDay(parseDayKey(entry.key)),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Text(money(entry.value.fold<double>(0, (s, e) => s + e.amount)),
                  style: TextStyle(
                      color: p.muted, fontWeight: FontWeight.w700, fontFeatures: tabular)),
            ]),
          ),
        ),
        SliverList.builder(
          itemCount: entry.value.length,
          itemBuilder: (context, i) {
            final e = entry.value[i];
            return Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 28),
                color: p.danger,
                child: const Icon(Icons.delete_rounded, color: Colors.white),
              ),
              onDismissed: (_) => _delete(e),
              child: ExpenseRow(expense: e, trip: trip),
            );
          },
        ),
      ],
      SliverToBoxAdapter(child: SizedBox(height: 120 + MediaQuery.paddingOf(context).bottom)),
    ]);
  }
}

class ExpenseRow extends ConsumerWidget {
  final Expense expense;
  final Trip trip;
  const ExpenseRow({super.key, required this.expense, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.p;
    final money = ref.watch(moneyProvider);
    final cat = ref.watch(categoryMapProvider)[expense.categoryId] ?? presetCategories.last;
    final parts = <String>[
      cat.name,
      fmtTime(expense.date),
      if (trip.isGroup) '${trip.memberName(expense.paidBy)} paid',
    ];
    return InkWell(
      onTap: () {
        buzz(ref, Buzz.select);
        showExpenseDetail(context, ref, expense);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          CatIcon(cat),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 2),
              Text(parts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ),
          if (expense.photo != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.image_outlined, size: 18, color: p.muted),
            ),
          if (expense.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.notes_rounded, size: 18, color: p.muted),
            ),
          Text(money(expense.amount),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, fontFeatures: tabular)),
        ]),
      ),
    );
  }
}
