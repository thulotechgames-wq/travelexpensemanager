import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currencies.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'quick_add_sheet.dart';

Future<void> showExpenseDetail(BuildContext context, WidgetRef ref, Expense e) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ExpenseDetailSheet(expenseId: e.id),
  );
  if (!context.mounted) return;
  if (action == 'edit') {
    await showQuickAdd(context, ref, e.tripId, edit: e);
  } else if (action == 'delete') {
    final ok = await confirm(context, title: 'Delete expense?', message: '"${e.title}" will be removed.');
    if (!ok || !context.mounted) return;
    final n = ref.read(expensesProvider.notifier);
    await n.remove(e.id);
    await n.deletePhoto(e.photo);
    buzz(ref, Buzz.medium);
  }
}

class ExpenseDetailSheet extends ConsumerWidget {
  final String expenseId;
  const ExpenseDetailSheet({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.p;
    Expense? e;
    for (final x in ref.watch(expensesProvider)) {
      if (x.id == expenseId) e = x;
    }
    if (e == null) return const SizedBox(height: 100);
    final exp = e;
    final trip = ref.watch(tripProvider(exp.tripId));
    final money = ref.watch(moneyProvider);
    final cat = ref.watch(categoryMapProvider)[exp.categoryId] ?? presetCategories.last;

    final rows = <(IconData, String, String)>[
      (Icons.calendar_today_rounded, 'Date', '${fmtDay(exp.date)} · ${fmtTime(exp.date)}'),
      (cat.iconData, 'Category', cat.name),
      if (trip != null && trip.isGroup) ...[
        (Icons.account_balance_wallet_rounded, 'Paid by', trip.memberName(exp.paidBy)),
        (
          Icons.group_rounded,
          'Split between',
          exp.splitWith.isEmpty
              ? 'Everyone (${money.exact(exp.amount / trip.members.length)} each)'
              : '${exp.splitWith.map(trip.memberName).join(', ')} (${money.exact(exp.amount / exp.splitWith.length)} each)'
        ),
      ],
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CatIcon(cat, size: 52, highlight: true),
            const SizedBox(width: 14),
            Expanded(
              child: Text(exp.title, style: context.tt.titleLarge, maxLines: 2),
            ),
          ]),
          const SizedBox(height: 16),
          Text(money.exact(exp.amount), style: context.tt.displayMedium),
          if (exp.isForeign) ...[
            const SizedBox(height: 4),
            Text(
              'Paid ${Money(currencyFor(exp.origCurrency!)).exact(exp.origAmount!)} · '
              '1 ${exp.origCurrency} = ${exp.rate!.toStringAsFixed(exp.rate! >= 100 ? 2 : 4)} ${money.c.code}',
              style: TextStyle(color: p.muted, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 16),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(r.$1, size: 20, color: p.muted),
                const SizedBox(width: 12),
                SizedBox(
                    width: 104,
                    child: Text(r.$2,
                        style: TextStyle(color: p.muted, fontWeight: FontWeight.w600))),
                Expanded(
                    child: Text(r.$3, style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
          if (exp.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16)),
              child: Text(exp.note, style: const TextStyle(height: 1.4)),
            ),
          ],
          if (exp.photo != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => _PhotoView(file: ref.read(receiptFileProvider(exp.photo!)).path),
              )),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  ref.read(receiptFileProvider(exp.photo!)),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 80,
                    color: p.card,
                    alignment: Alignment.center,
                    child: Text('Receipt not found', style: TextStyle(color: p.muted)),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'delete'),
                icon: Icon(Icons.delete_outline_rounded, color: p.danger),
                label: Text('Delete', style: TextStyle(color: p.danger)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  side: BorderSide(color: p.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'edit'),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _PhotoView extends StatelessWidget {
  final String file;
  const _PhotoView({required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt'),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(File(file)),
        ),
      ),
    );
  }
}
