import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.p;
    final cats = ref.watch(categoriesProvider);
    final used = <String, int>{};
    for (final e in ref.watch(expensesProvider)) {
      used[e.categoryId] = (used[e.categoryId] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('Drag to reorder. The order here is the order in the quick-add sheet.',
              style: TextStyle(color: p.muted, fontSize: 13)),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
            itemCount: cats.length,
            onReorder: (a, b) {
              buzz(ref, Buzz.select);
              ref.read(categoriesProvider.notifier).reorder(a, b);
            },
            itemBuilder: (context, i) {
              final c = cats[i];
              final n = used[c.id] ?? 0;
              return ListTile(
                key: ValueKey(c.id),
                onTap: () => _edit(context, ref, c),
                leading: CatIcon(c),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(n == 0 ? 'Not used yet' : 'Used $n ${n == 1 ? 'time' : 'times'}',
                    style: TextStyle(color: p.muted, fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (c.id != 'other')
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: p.muted),
                      onPressed: () async {
                        final ok = await confirm(context,
                            title: 'Delete "${c.name}"?',
                            message: n == 0
                                ? 'This category will be removed.'
                                : '$n expenses will show under "Other".');
                        if (ok) ref.read(categoriesProvider.notifier).remove(c.id);
                      },
                    ),
                  ReorderableDragStartListener(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle_rounded, color: p.muted),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, SpendCategory? c) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CategoryEditor(category: c),
    );
  }
}

class _CategoryEditor extends ConsumerStatefulWidget {
  final SpendCategory? category;
  const _CategoryEditor({this.category});

  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late String _icon = widget.category?.icon ?? 'coffee';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    final notifier = ref.read(categoriesProvider.notifier);
    if (widget.category == null) {
      await notifier.add(n, _icon);
    } else {
      await notifier.edit(widget.category!.copyWith(name: n, icon: _icon));
    }
    buzz(ref, Buzz.success);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.category == null ? 'New category' : 'Edit category',
              style: context.tt.headlineMedium),
          const SizedBox(height: 20),
          Row(children: [
            CatIcon(SpendCategory(id: '_', name: '', icon: _icon), size: 56, highlight: true),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _name,
                autofocus: widget.category == null,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(hintText: 'Name, e.g. Coffee'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          const Label('Icon'),
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final k in categoryIcons.keys)
                Pressable(
                  onTap: () {
                    buzz(ref, Buzz.select);
                    setState(() => _icon = k);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: _icon == k ? p.ink : p.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(categoryIcons[k], color: _icon == k ? p.bg : p.ink, size: 22),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _name.text.trim().isEmpty ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              disabledBackgroundColor: p.card,
            ),
            child: const Text('Save'),
          ),
        ]),
      ),
    );
  }
}
