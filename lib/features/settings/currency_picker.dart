import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/currencies.dart';
import '../../core/theme.dart';

/// Guess the user's currency from the device locale.
String guessCurrency() {
  try {
    final loc = WidgetsBinding.instance.platformDispatcher.locale;
    final code = NumberFormat.simpleCurrency(locale: loc.toString()).currencyName;
    if (code != null && currencies.any((c) => c.code == code)) return code;
  } catch (_) {}
  return 'USD';
}

class CurrencyList extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onPick;
  const CurrencyList({super.key, required this.selected, required this.onPick});

  @override
  State<CurrencyList> createState() => _CurrencyListState();
}

class _CurrencyListState extends State<CurrencyList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final q = _q.toLowerCase();
    final list = currencies
        .where((c) =>
            q.isEmpty ||
            c.code.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q) ||
            c.symbol.toLowerCase().contains(q))
        .toList();
    // Selected currency floats to the top.
    list.sort((a, b) => (b.code == widget.selected ? 1 : 0) - (a.code == widget.selected ? 1 : 0));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(
            hintText: 'Search currency',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final c = list[i];
            final sel = c.code == widget.selected;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: sel ? p.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                onTap: () => widget.onPick(c.code),
                leading: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? p.onAccent : p.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(c.symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: c.symbol.length > 2 ? 12 : 18,
                        color: sel ? p.accent : p.ink,
                      )),
                ),
                title: Text(c.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: sel ? p.onAccent : p.ink)),
                subtitle: Text(c.code,
                    style: TextStyle(color: sel ? p.onAccent.withValues(alpha: 0.7) : p.muted)),
                trailing: sel ? Icon(Icons.check_circle_rounded, color: p.onAccent) : null,
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class CurrencyPickerScreen extends StatefulWidget {
  final String initial;
  const CurrencyPickerScreen({super.key, required this.initial});

  @override
  State<CurrencyPickerScreen> createState() => _CurrencyPickerScreenState();
}

class _CurrencyPickerScreenState extends State<CurrencyPickerScreen> {
  late String _sel = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Currency')),
      body: CurrencyList(
        selected: _sel,
        onPick: (c) {
          setState(() => _sel = c);
          Navigator.pop(context, c);
        },
      ),
    );
  }
}
