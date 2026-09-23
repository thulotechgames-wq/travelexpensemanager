import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Shows a celebration for any newly unlocked badge, then marks all as seen.
Future<void> checkBadges(BuildContext context, WidgetRef ref) async {
  final seen = ref.read(settingsProvider).seenBadges;
  final fresh = ref.read(badgesProvider).where((b) => b.unlocked && !seen.contains(b.def.id)).toList();
  if (fresh.isEmpty) return;
  await ref.read(settingsProvider.notifier).markBadgesSeen(fresh.map((b) => b.def.id));
  if (!context.mounted) return;
  buzz(ref, Buzz.success);
  final b = fresh.first;
  await celebrate(
    context,
    icon: b.def.icon,
    title: b.def.title,
    subtitle: fresh.length > 1
        ? '${b.def.desc}\n+${fresh.length - 1} more badge${fresh.length > 2 ? 's' : ''} unlocked'
        : 'Badge unlocked · ${b.def.desc}',
  );
}

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.p;
    final badges = ref.watch(badgesProvider);
    final streak = ref.watch(streakProvider);
    final unlocked = badges.where((b) => b.unlocked).length;
    // Closest-to-unlock first among locked badges → "almost there" pull.
    final sorted = [...badges]..sort((a, b) {
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        return b.progress.compareTo(a.progress);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
        Row(children: [
          Expanded(child: _Big(value: '$unlocked/${badges.length}', label: 'Badges')),
          const SizedBox(width: 12),
          Expanded(child: _Big(value: '${streak.current}', label: 'Current streak')),
          const SizedBox(width: 12),
          Expanded(child: _Big(value: '${streak.best}', label: 'Best streak')),
        ]),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sorted.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, i) {
            final b = sorted[i];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: b.unlocked ? p.ink : p.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: b.unlocked ? p.ink : p.line),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: b.unlocked ? p.accent : p.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(b.unlocked ? b.def.icon : Icons.lock_rounded,
                      color: b.unlocked ? p.onAccent : p.muted),
                ),
                const Spacer(),
                Text(b.def.title,
                    style: TextStyle(
                        color: b.unlocked ? p.bg : p.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(b.def.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: b.unlocked ? p.bg.withValues(alpha: 0.6) : p.muted, fontSize: 12)),
                if (!b.unlocked) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: b.progress,
                      minHeight: 5,
                      backgroundColor: p.card,
                      color: p.ink,
                    ),
                  ),
                ],
              ]),
            );
          },
        ),
      ]),
    );
  }
}

class _Big extends StatelessWidget {
  final String value;
  final String label;
  const _Big({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
