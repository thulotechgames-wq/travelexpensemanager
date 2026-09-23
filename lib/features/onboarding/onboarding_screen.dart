import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currencies.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../settings/currency_picker.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;
  late String _currency = guessCurrency();

  static const _intro = [
    (
      Icons.luggage_rounded,
      'Every coin,\nevery trip.',
      'Create a trip, log spending in three taps, and always know what\'s left.'
    ),
    (
      Icons.donut_large_rounded,
      'See where\nit all went.',
      'Clean charts by category and day, group splits, and a report you can share.'
    ),
  ];

  void _next() {
    buzz(ref, Buzz.select);
    if (_page < 2) {
      _pc.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    } else {
      buzz(ref, Buzz.success);
      ref.read(settingsProvider.notifier).finishOnboarding(_currency);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final cur = currencyFor(_currency);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: i <= _page ? p.ink : p.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final it in _intro) _IntroPage(icon: it.$1, title: it.$2, body: it.$3),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pick your\ncurrency.', style: context.tt.displayMedium),
                      const SizedBox(height: 12),
                      Text('All amounts use this. You can change it any time in Settings.',
                          style: TextStyle(color: p.muted, fontSize: 16, height: 1.4)),
                    ]),
                  ),
                  Expanded(
                    child: CurrencyList(
                      selected: _currency,
                      onPick: (c) {
                        buzz(ref, Buzz.select);
                        setState(() => _currency = c);
                      },
                    ),
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: FilledButton(
              onPressed: _next,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _page < 2 ? 'Continue' : 'Start with ${cur.code}',
                  key: ValueKey(_page < 2 ? 'c' : cur.code),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _IntroPage({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(40)),
            child: Icon(icon, size: 64, color: p.onAccent),
          ),
        ),
        const Spacer(),
        Text(title, style: context.tt.displayMedium),
        const SizedBox(height: 16),
        Text(body, style: TextStyle(color: p.muted, fontSize: 17, height: 1.45)),
        const SizedBox(height: 24),
      ]),
    );
  }
}
