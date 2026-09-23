import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../state/stats.dart';

// ─── Haptics ─────────────────────────────────────────────────────────────────
enum Buzz { light, medium, heavy, select, success }

void buzz(WidgetRef ref, [Buzz kind = Buzz.light]) {
  if (!ref.read(settingsProvider).haptics) return;
  switch (kind) {
    case Buzz.light:
      HapticFeedback.lightImpact();
    case Buzz.medium:
      HapticFeedback.mediumImpact();
    case Buzz.heavy:
      HapticFeedback.heavyImpact();
    case Buzz.select:
      HapticFeedback.selectionClick();
    case Buzz.success:
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 90), HapticFeedback.lightImpact);
  }
}

// ─── Pressable: subtle scale on press, makes every card feel tactile ─────────
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─── Budget bar ──────────────────────────────────────────────────────────────
Color healthColor(BuildContext context, Health h) {
  final p = context.p;
  switch (h) {
    case Health.over:
      return p.danger;
    case Health.warn:
      return p.ink;
    case Health.good:
    case Health.none:
      return p.accent;
  }
}

class BudgetBar extends StatelessWidget {
  final double pct;
  final Health health;
  final double height;

  /// Optional marker showing where "today" should be if spending evenly.
  final double? pace;
  const BudgetBar({super.key, required this.pct, required this.health, this.height = 10, this.pace});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: height,
        child: Stack(children: [
          Container(
            decoration:
                BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(height)),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct.clamp(0, 1).toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Container(
              width: max(height, w * v),
              decoration: BoxDecoration(
                color: healthColor(context, health),
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
          if (pace != null && pace! > 0 && pace! < 1)
            Positioned(
              left: w * pace! - 1,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: p.muted),
            ),
        ]),
      );
    });
  }
}

// ─── Small building blocks ───────────────────────────────────────────────────
class CatIcon extends StatelessWidget {
  final SpendCategory category;
  final double size;
  final bool highlight;
  const CatIcon(this.category, {super.key, this.size = 44, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: highlight ? p.accent : p.card,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(category.iconData,
          size: size * 0.5, color: highlight ? p.onAccent : p.ink),
    );
  }
}

class Label extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const Label(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(children: [
        Expanded(
          child: Text(text.toUpperCase(),
              style: TextStyle(
                  color: context.p.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class Tile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  const Tile({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.p.line),
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

class Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool accent;
  const Pill(this.text, {super.key, this.icon, this.selected = false, this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final bg = accent ? p.accent : (selected ? p.ink : p.card);
    final fg = accent ? p.onAccent : (selected ? p.bg : p.ink);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(40)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
          Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24)),
          child: Icon(icon, size: 32, color: p.ink),
        ),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: context.tt.titleLarge),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.4)),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ]),
    );
  }
}

/// Big animated number that counts up — used for totals.
class CountUp extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle? style;
  const CountUp({super.key, required this.value, required this.format, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(format(v), style: style),
      ),
    );
  }
}

// ─── Celebration with confetti ───────────────────────────────────────────────
Future<void> celebrate(BuildContext context,
    {required IconData icon, required String title, required String subtitle}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, a, b) => _Celebration(icon: icon, title: title, subtitle: subtitle),
    transitionBuilder: (context, a, b, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: a, child: child),
    ),
  );
}

class _Celebration extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Celebration({required this.icon, required this.title, required this.subtitle});

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  final _parts = List.generate(46, (_) => _Particle(Random()));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _ConfettiPainter(_parts, _c.value, p.accent, Colors.white),
            ),
          ),
        ),
      ),
      Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
            decoration:
                BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(32)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                child: Icon(widget.icon, size: 40, color: p.onAccent),
              ),
              const SizedBox(height: 20),
              Text(widget.title,
                  textAlign: TextAlign.center, style: context.tt.headlineSmall),
              const SizedBox(height: 8),
              Text(widget.subtitle,
                  textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.4)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Nice!'),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _Particle {
  final double x, speed, drift, size, rot;
  final bool accent;
  _Particle(Random r)
      : x = r.nextDouble(),
        speed = 0.6 + r.nextDouble() * 0.8,
        drift = (r.nextDouble() - 0.5) * 0.3,
        size = 5 + r.nextDouble() * 7,
        rot = r.nextDouble() * pi,
        accent = r.nextBool();
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> parts;
  final double t;
  final Color a, b;
  _ConfettiPainter(this.parts, this.t, this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final pt in parts) {
      final y = -20 + (size.height + 40) * (t * pt.speed);
      final x = size.width * (pt.x + pt.drift * t);
      paint.color = (pt.accent ? a : b).withValues(alpha: (1 - t).clamp(0, 1).toDouble());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(pt.rot + t * 8);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: pt.size, height: pt.size * 0.5),
              const Radius.circular(2)),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

void toast(BuildContext context, String msg, {String? action, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    duration: const Duration(seconds: 3),
    action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
  ));
}

Future<bool> confirm(BuildContext context,
    {required String title, required String message, String ok = 'Delete'}) async {
  final p = context.p;
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message, style: TextStyle(color: p.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(ok, style: TextStyle(color: p.danger)),
        ),
      ],
    ),
  );
  return r ?? false;
}
