import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'trip_detail_screen.dart';

Future<void> showTripForm(BuildContext context, {Trip? trip}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TripFormSheet(trip: trip),
  );
}

class TripFormSheet extends ConsumerStatefulWidget {
  final Trip? trip;
  const TripFormSheet({super.key, this.trip});

  @override
  ConsumerState<TripFormSheet> createState() => _TripFormSheetState();
}

class _TripFormSheetState extends ConsumerState<TripFormSheet> {
  late final _title = TextEditingController(text: widget.trip?.title ?? '');
  late final _budget = TextEditingController(
      text: widget.trip?.budget == null ? '' : _num(widget.trip!.budget!));
  final _member = TextEditingController();
  late DateTime _start = widget.trip?.startDate ?? dateOnly(DateTime.now());
  late DateTime? _end = widget.trip?.endDate;
  late List<Member> _members =
      List.of(widget.trip?.members ?? const [Member(id: meId, name: 'You')]);

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  bool get _valid => _title.text.trim().isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    _budget.dispose();
    _member.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _start, end: _end ?? _start),
      helpText: 'Trip dates',
    );
    if (r != null) {
      setState(() {
        _start = dateOnly(r.start);
        _end = dateOnly(r.end);
      });
    }
  }

  void _addMember() {
    final n = _member.text.trim();
    if (n.isEmpty) return;
    buzz(ref, Buzz.select);
    setState(() {
      _members = [..._members, Member(id: newId(), name: n)];
      _member.clear();
    });
  }

  Future<void> _save() async {
    if (!_valid) return;
    buzz(ref, Buzz.success);
    final budget = double.tryParse(_budget.text.replaceAll(',', '').trim());
    final isNew = widget.trip == null;
    final t = isNew
        ? Trip(
            id: newId(),
            title: _title.text.trim(),
            budget: budget,
            startDate: _start,
            endDate: _end,
            members: _members,
            createdAt: DateTime.now(),
          )
        : widget.trip!.copyWith(
            title: _title.text.trim(),
            budget: budget,
            clearBudget: budget == null,
            startDate: _start,
            endDate: _end,
            clearEnd: _end == null,
            members: _members,
          );
    await ref.read(tripsProvider.notifier).upsert(t);
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop();
    if (isNew) {
      await nav.push(MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: t.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final cur = ref.watch(currencyProvider);
    final usedIds = widget.trip == null
        ? <String>{}
        : ref
            .watch(expensesProvider)
            .where((e) => e.tripId == widget.trip!.id)
            .expand((e) => [e.paidBy, ...e.splitWith])
            .toSet();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.trip == null ? 'New trip' : 'Edit trip', style: context.tt.headlineMedium),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            autofocus: widget.trip == null,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(hintText: 'Trip name, e.g. Pokhara 2026'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              hintText: 'Budget (optional)',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Text(cur.symbol,
                    style: TextStyle(fontWeight: FontWeight.w800, color: p.ink, fontSize: 16)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
          ),
          const SizedBox(height: 12),
          Pressable(
            onTap: _pickDates,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(Icons.calendar_month_rounded, color: p.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _end == null
                        ? 'Starts ${fmtShortYear(_start)} · add end date'
                        : '${fmtShort(_start)} – ${fmtShortYear(_end!)} · ${daysBetween(_start, _end!)} days',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (_end != null)
                  GestureDetector(
                    onTap: () => setState(() => _end = null),
                    child: Icon(Icons.close_rounded, color: p.muted, size: 20),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Add budget + end date to unlock daily spending targets.',
                style: TextStyle(color: p.muted, fontSize: 12)),
          ),
          const SizedBox(height: 20),
          const Label('Travelling with'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in _members)
              InputChip(
                label: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                backgroundColor: p.card,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                onDeleted: m.id == meId || usedIds.contains(m.id)
                    ? null
                    : () => setState(() => _members = _members.where((x) => x.id != m.id).toList()),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _member,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Add a friend to split costs',
              suffixIcon: IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add_alt_1_rounded)),
            ),
            onSubmitted: (_) => _addMember(),
          ),
          const SizedBox(height: 24),
          AnimatedOpacity(
            opacity: _valid ? 1 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: FilledButton(
              onPressed: _valid ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
                disabledBackgroundColor: p.card,
              ),
              child: Text(widget.trip == null ? 'Create trip' : 'Save changes'),
            ),
          ),
        ]),
      ),
    );
  }
}

