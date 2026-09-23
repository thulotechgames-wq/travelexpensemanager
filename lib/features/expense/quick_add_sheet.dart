import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/storage.dart';
import '../../state/providers.dart';
import '../../state/stats.dart';
import '../../widgets/common.dart';
import '../badges/badges_screen.dart';

/// Opens the calculator-style add sheet. After saving it runs budget alerts,
/// badge checks and a tiny "saved" confirmation.
Future<void> showQuickAdd(BuildContext context, WidgetRef ref, String tripId,
    {Expense? edit}) async {
  final before = ref.read(tripStatsProvider(tripId));
  final saved = await showModalBottomSheet<Expense>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => QuickAddSheet(tripId: tripId, edit: edit),
  );
  if (saved == null || !context.mounted) return;

  final after = ref.read(tripStatsProvider(tripId));
  final money = ref.read(moneyProvider);
  if (before != null && after != null) {
    final isToday = dayKey(saved.date) == dayKey(DateTime.now());
    final daily = after.dailyBudget;
    if (after.budget != null && before.pct < 1 && after.pct >= 1) {
      buzz(ref, Buzz.heavy);
      toast(context, 'Over budget by ${money(-after.remaining!)}. Time to slow down.');
    } else if (after.budget != null && before.pct < 0.8 && after.pct >= 0.8) {
      buzz(ref, Buzz.medium);
      toast(context, '80% of budget used · ${money(after.remaining!)} left');
    } else if (daily != null && isToday && before.todaySpent <= daily && after.todaySpent > daily) {
      buzz(ref, Buzz.medium);
      toast(context, 'Today is over your ${money(daily)} daily target');
    } else if (edit == null) {
      final left = after.leftPerDay;
      toast(
        context,
        left != null
            ? 'Added ${money(saved.amount)} · ${money(left)}/day left'
            : 'Added ${money(saved.amount)} · ${money(after.spent)} total',
      );
    }
  }
  await checkBadges(context, ref);
}

class QuickAddSheet extends ConsumerStatefulWidget {
  final String tripId;
  final Expense? edit;
  const QuickAddSheet({super.key, required this.tripId, this.edit});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  late String _expr;
  late String _cat;
  late DateTime _date;
  late String _paidBy;
  late Set<String> _split;
  late final TextEditingController _title;
  late final TextEditingController _note;
  String? _photo;
  String? _pickedPhoto; // photo picked in this session (deleted if not saved)
  bool _saved = false;
  bool _showNote = false;
  int _shake = 0;

  late final Storage _db;

  @override
  void initState() {
    super.initState();
    _db = ref.read(storageProvider);
    final e = widget.edit;
    final trip = ref.read(tripProvider(widget.tripId))!;
    final cats = ref.read(categoriesProvider);
    if (e != null) {
      _expr = e.amount == e.amount.roundToDouble()
          ? e.amount.toInt().toString()
          : e.amount.toStringAsFixed(ref.read(currencyProvider).decimals);
      _cat = e.categoryId;
      _date = e.date;
      _paidBy = e.paidBy;
      _split = e.splitWith.isEmpty ? trip.members.map((m) => m.id).toSet() : e.splitWith.toSet();
      _photo = e.photo;
      _showNote = e.note.isNotEmpty;
    } else {
      _expr = '';
      // Default to the category used most recently in this trip.
      final recent = ref.read(expensesProvider).where((x) => x.tripId == widget.tripId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cat = recent.isNotEmpty && cats.any((c) => c.id == recent.first.categoryId)
          ? recent.first.categoryId
          : cats.first.id;
      final now = DateTime.now();
      _date = now;
      // For trips in the past, default the date into the trip range.
      if (trip.endDate != null && dateOnly(now).isAfter(dateOnly(trip.endDate!))) {
        _date = DateTime(trip.endDate!.year, trip.endDate!.month, trip.endDate!.day, 12);
      }
      _paidBy = meId;
      _split = trip.members.map((m) => m.id).toSet();
    }
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    // Remove a receipt picked in this sheet if the expense was never saved.
    if (!_saved && _pickedPhoto != null) {
      final f = _db.receiptFile(_pickedPhoto!);
      f.exists().then((exists) {
        if (exists) f.delete();
      });
    }
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  bool _isOp(String c) => c == '+' || c == '−';
  String get _segment {
    final i = max(_expr.lastIndexOf('+'), _expr.lastIndexOf('−'));
    return _expr.substring(i + 1);
  }

  void _key(String k) {
    final decimals = ref.read(currencyProvider).decimals;
    final seg = _segment;
    setState(() {
      switch (k) {
        case '⌫':
          if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
        case '+':
        case '−':
          if (_expr.isEmpty) break;
          if (_isOp(_expr[_expr.length - 1])) {
            _expr = _expr.substring(0, _expr.length - 1) + k;
          } else {
            _expr += k;
          }
        case '.':
          if (decimals == 0 || seg.contains('.')) break;
          _expr += seg.isEmpty ? '0.' : '.';
        default: // digits and 00
          if (_expr.length > 18) break;
          if (seg.contains('.') && seg.split('.').last.length + k.length > decimals) break;
          if (seg == '0') {
            if (k == '0' || k == '00') break;
            _expr = _expr.substring(0, _expr.length - 1);
          }
          if (seg.isEmpty && k == '00') {
            _expr += '0';
          } else {
            _expr += k;
          }
      }
    });
    buzz(ref, Buzz.select);
  }

  String _pretty(String expr) {
    final out = StringBuffer();
    var seg = '';
    void flush() {
      final parts = seg.split('.');
      final grouped = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
      out.write(parts.length > 1 ? '$grouped.${parts[1]}' : grouped);
      seg = '';
    }

    for (final ch in expr.split('')) {
      if (_isOp(ch)) {
        flush();
        out.write(' $ch ');
      } else {
        seg += ch;
      }
    }
    flush();
    return out.toString();
  }

  Future<void> _pickPhoto(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 78);
      if (x == null || !mounted) return;
      final name = '${newId()}.jpg';
      final file = ref.read(receiptFileProvider(name));
      await File(x.path).copy(file.path);
      if (_pickedPhoto != null) {
        await ref.read(expensesProvider.notifier).deletePhoto(_pickedPhoto);
      }
      setState(() {
        _pickedPhoto = name;
        _photo = name;
      });
      buzz(ref, Buzz.light);
    } catch (_) {
      if (mounted) toast(context, 'Could not open ${src == ImageSource.camera ? 'camera' : 'photos'}');
    }
  }

  void _photoMenu() {
    final p = context.p;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Icon(Icons.photo_camera_rounded, color: p.ink),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: p.ink),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_photo != null)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: p.danger),
                title: Text('Remove photo', style: TextStyle(color: p.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _photo = null);
                },
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final trip = ref.read(tripProvider(widget.tripId))!;
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      currentDate: DateTime.now(),
      helpText: trip.title,
    );
    if (d != null) {
      setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
    }
  }

  Future<void> _save() async {
    final amount = evalExpr(_expr);
    if (amount <= 0) {
      buzz(ref, Buzz.heavy);
      setState(() => _shake++);
      return;
    }
    final trip = ref.read(tripProvider(widget.tripId))!;
    final cat = ref.read(categoryMapProvider)[_cat];
    final allIds = trip.members.map((m) => m.id).toSet();
    final split = _split.length == allIds.length || _split.isEmpty ? <String>[] : _split.toList();
    final title = _title.text.trim().isEmpty ? (cat?.name ?? 'Expense') : _title.text.trim();
    final e = widget.edit;
    final expense = e == null
        ? Expense(
            id: newId(),
            tripId: widget.tripId,
            title: title,
            amount: amount,
            categoryId: _cat,
            date: _date,
            paidBy: _paidBy,
            splitWith: split,
            note: _note.text.trim(),
            photo: _photo,
            createdAt: DateTime.now(),
          )
        : e.copyWith(
            title: title,
            amount: amount,
            categoryId: _cat,
            date: _date,
            paidBy: _paidBy,
            splitWith: split,
            note: _note.text.trim(),
            photo: _photo,
            clearPhoto: _photo == null,
          );
    // Clean up a replaced/removed receipt when editing.
    if (e?.photo != null && e!.photo != _photo) {
      await ref.read(expensesProvider.notifier).deletePhoto(e.photo);
    }
    _saved = true;
    await ref.read(expensesProvider.notifier).upsert(expense, isNew: e == null);
    buzz(ref, Buzz.success);
    if (mounted) Navigator.pop(context, expense);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final trip = ref.watch(tripProvider(widget.tripId));
    if (trip == null) return const SizedBox.shrink();
    final cats = ref.watch(categoriesProvider);
    final cur = ref.watch(currencyProvider);
    final money = ref.watch(moneyProvider);
    final hasOp = _expr.contains('+') || _expr.contains('−');
    final value = evalExpr(_expr);
    final today = dayKey(_date) == dayKey(DateTime.now());

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(4)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(children: [
                  Expanded(
                    child: Text(trip.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.muted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            fontSize: 12)),
                  ),
                  Pill(today ? 'Today' : fmtDay(_date),
                      icon: Icons.calendar_today_rounded, onTap: _pickDate),
                ]),
                const SizedBox(height: 10),
                // Amount
                TweenAnimationBuilder<double>(
                  key: ValueKey(_shake),
                  tween: Tween(begin: _shake == 0 ? 0.0 : 1.0, end: 0.0),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, t, child) =>
                      Transform.translate(offset: Offset(sin(t * pi * 6) * 10 * t, 0), child: child),
                  child: SizedBox(
                    height: 72,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic, children: [
                        Text(cur.symbol,
                            style: context.tt.displaySmall?.copyWith(
                                color: p.muted, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Text(
                          _expr.isEmpty ? '0' : _pretty(_expr),
                          style: context.tt.displayLarge?.copyWith(
                            color: _expr.isEmpty ? p.muted.withValues(alpha: 0.5) : p.ink,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: hasOp
                      ? Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('= ${money.exact(value)}',
                              style: TextStyle(
                                  color: p.muted, fontWeight: FontWeight.w700, fontSize: 16)),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 12),
                // Categories
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: cats.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final c = cats[i];
                      return Pill(c.name,
                          icon: c.iconData,
                          selected: c.id == _cat,
                          onTap: () {
                            buzz(ref, Buzz.select);
                            setState(() => _cat = c.id);
                          });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                // Title + extras
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText:
                            'What for? (${cats.firstWhere((c) => c.id == _cat, orElse: () => cats.first).name})',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IconToggle(
                    icon: Icons.notes_rounded,
                    active: _showNote,
                    onTap: () => setState(() => _showNote = !_showNote),
                  ),
                  const SizedBox(width: 8),
                  _photo == null
                      ? _IconToggle(icon: Icons.receipt_long_rounded, onTap: _photoMenu)
                      : GestureDetector(
                          onTap: _photoMenu,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(ref.read(receiptFileProvider(_photo!)),
                                width: 48, height: 48, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _IconToggle(icon: Icons.broken_image_rounded, onTap: _photoMenu)),
                          ),
                        ),
                ]),
                if (_showNote) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _note,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(isDense: true, hintText: 'Note'),
                  ),
                ],
                if (trip.isGroup) ...[
                  const SizedBox(height: 12),
                  _MemberRow(
                    label: 'Paid by',
                    members: trip.members,
                    isSelected: (id) => id == _paidBy,
                    onTap: (id) => setState(() => _paidBy = id),
                  ),
                  const SizedBox(height: 8),
                  _MemberRow(
                    label: 'Split',
                    members: trip.members,
                    isSelected: _split.contains,
                    onTap: (id) => setState(() {
                      if (_split.contains(id)) {
                        if (_split.length > 1) _split.remove(id);
                      } else {
                        _split.add(id);
                      }
                    }),
                  ),
                ],
                const SizedBox(height: 12),
              ]),
            ),
          ),
          _Keypad(
            onKey: _key,
            onClear: () {
              buzz(ref, Buzz.medium);
              setState(() => _expr = '');
            },
            onSave: _save,
            decimals: cur.decimals,
            editing: widget.edit != null,
          ),
        ]),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _IconToggle({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
            color: active ? p.ink : p.card, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: active ? p.bg : p.ink, size: 22),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final String label;
  final List<Member> members;
  final bool Function(String) isSelected;
  final ValueChanged<String> onTap;
  const _MemberRow(
      {required this.label, required this.members, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 64,
        child: Text(label,
            style: TextStyle(color: context.p.muted, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
      Expanded(
        child: SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) => Pill(members[i].name,
                selected: isSelected(members[i].id), onTap: () => onTap(members[i].id)),
          ),
        ),
      ),
    ]);
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onClear;
  final VoidCallback onSave;
  final int decimals;
  final bool editing;
  const _Keypad({
    required this.onKey,
    required this.onClear,
    required this.onSave,
    required this.decimals,
    required this.editing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    Widget key(String k, {Widget? child, VoidCallback? onLong, bool dim = false}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _Key(
              onTap: () => onKey(k),
              onLong: onLong,
              color: dim ? p.card : p.surface,
              child: child ??
                  Text(k, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            ),
          ),
        );

    return Container(
      color: p.bg,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          SizedBox(
            height: 62,
            child: Row(children: [
              for (final k in row) key(k),
              if (row.first == '1')
                key('⌫',
                    dim: true,
                    onLong: onClear,
                    child: Icon(Icons.backspace_outlined, color: p.ink)),
              if (row.first == '4') key('+', dim: true),
              if (row.first == '7') key('−', dim: true),
            ]),
          ),
        SizedBox(
          height: 62,
          child: Row(children: [
            decimals > 0 ? key('.') : key('00'),
            key('0'),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _Key(
                  onTap: onSave,
                  color: p.accent,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_rounded, color: p.onAccent),
                    const SizedBox(width: 6),
                    Text(editing ? 'Update' : 'Save',
                        style: TextStyle(
                            color: p.onAccent, fontSize: 18, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Key extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onLong;
  final Color color;
  final Widget child;
  const _Key({required this.onTap, required this.color, required this.child, this.onLong});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLong,
        child: Center(child: child),
      ),
    );
  }
}

/// Used by other screens to show a compact health label.
String healthLabel(Health h) => switch (h) {
      Health.over => 'Over budget',
      Health.warn => 'Almost there',
      Health.good => 'On track',
      Health.none => 'No budget',
    };
