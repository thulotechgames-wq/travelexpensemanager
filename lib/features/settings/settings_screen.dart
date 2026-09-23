import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currencies.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../badges/badges_screen.dart';
import '../export/export_service.dart';
import 'categories_screen.dart';
import 'currency_picker.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.p;
    final s = ref.watch(settingsProvider);
    final cur = currencyFor(s.currency);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
        const Label('General'),
        _Group(children: [
          _Row(
            icon: Icons.payments_rounded,
            title: 'Currency',
            subtitle: 'Used for every trip. Amounts are not converted.',
            trailing: Text('${cur.symbol}  ${cur.code}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            onTap: () async {
              final code = await Navigator.push<String>(context,
                  MaterialPageRoute(builder: (_) => CurrencyPickerScreen(initial: s.currency)));
              if (code != null && code != s.currency) {
                await ref.read(settingsProvider.notifier).setCurrency(code);
                if (context.mounted) toast(context, 'Currency set to $code');
              }
            },
          ),
          _Row(
            icon: Icons.category_rounded,
            title: 'Categories',
            subtitle: '${ref.watch(categoriesProvider).length} categories',
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
          _Row(
            icon: Icons.emoji_events_rounded,
            title: 'Achievements',
            subtitle: 'Streaks and badges',
            onTap: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
          ),
        ]),
        const SizedBox(height: 16),
        const Label('Appearance'),
        _Group(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              for (final m in ThemeMode.values) ...[
                if (m != ThemeMode.system) const SizedBox(width: 8),
                Expanded(
                  child: Pressable(
                    onTap: () {
                      buzz(ref, Buzz.select);
                      ref.read(settingsProvider.notifier).setThemeMode(m);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: s.themeMode == m ? p.ink : p.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(children: [
                        Icon(
                          switch (m) {
                            ThemeMode.system => Icons.brightness_auto_rounded,
                            ThemeMode.light => Icons.light_mode_rounded,
                            ThemeMode.dark => Icons.dark_mode_rounded,
                          },
                          color: s.themeMode == m ? p.bg : p.ink,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          switch (m) {
                            ThemeMode.system => 'System',
                            ThemeMode.light => 'Light',
                            ThemeMode.dark => 'Dark',
                          },
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: s.themeMode == m ? p.bg : p.ink),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          SwitchListTile(
            value: s.haptics,
            onChanged: (v) => ref.read(settingsProvider.notifier).setHaptics(v),
            title: const Text('Haptic feedback', style: TextStyle(fontWeight: FontWeight.w700)),
            secondary: Icon(Icons.vibration_rounded, color: p.ink),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ]),
        const SizedBox(height: 16),
        const Label('Data'),
        _Group(children: [
          _Row(
            icon: Icons.table_chart_rounded,
            title: 'Export all expenses',
            subtitle: 'CSV file for Excel / Sheets',
            onTap: () async {
              try {
                await ExportService.shareAllCsv(
                  context,
                  ref.read(tripsProvider),
                  ref.read(expensesProvider),
                  ref.read(categoryMapProvider),
                  ref.read(currencyProvider),
                );
              } catch (e) {
                if (context.mounted) toast(context, 'Export failed: $e');
              }
            },
          ),
          _Row(
            icon: Icons.delete_forever_rounded,
            title: 'Erase all data',
            subtitle: 'Trips, expenses, receipts and progress',
            danger: true,
            onTap: () async {
              final ok = await confirm(context,
                  title: 'Erase everything?',
                  message: 'This permanently deletes all trips, expenses and receipt photos.',
                  ok: 'Erase');
              if (!ok || !context.mounted) return;
              // This screen is about to close, so use the app-wide container.
              final c = ProviderScope.containerOf(context, listen: false);
              Navigator.of(context).popUntil((r) => r.isFirst);
              await c.read(storageProvider).wipe();
              c.read(categoriesProvider.notifier).reload();
              c.read(expensesProvider.notifier).reload();
              c.read(tripsProvider.notifier).reload();
              c.read(settingsProvider.notifier).reload();
            },
          ),
        ]),
        const SizedBox(height: 32),
        Center(
          child: Text('Travel Expenses Manager · v1.0\nWorks offline. Your data stays on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
        ),
      ]),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.p.line),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool danger;
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final c = danger ? p.danger : p.ink;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: c)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: p.muted, fontSize: 12)),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: p.muted),
    );
  }
}
