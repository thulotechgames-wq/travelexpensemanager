import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Monochrome palette + a single electric-lime accent.
@immutable
class Palette extends ThemeExtension<Palette> {
  final Color bg;
  final Color surface;
  final Color card;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color danger;

  const Palette({
    required this.bg,
    required this.surface,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.danger,
  });

  static const lime = Color(0xFFC6F432);

  static const light = Palette(
    bg: Color(0xFFF7F7F5),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFEFEFEC),
    ink: Color(0xFF0E0E0E),
    muted: Color(0xFF8A8A86),
    line: Color(0xFFE3E3DF),
    accent: lime,
    onAccent: Color(0xFF0E0E0E),
    danger: Color(0xFFE5484D),
  );

  static const dark = Palette(
    bg: Color(0xFF0B0B0B),
    surface: Color(0xFF151515),
    card: Color(0xFF1E1E1E),
    ink: Color(0xFFF4F4F2),
    muted: Color(0xFF8C8C88),
    line: Color(0xFF2A2A2A),
    accent: lime,
    onAccent: Color(0xFF0E0E0E),
    danger: Color(0xFFFF6369),
  );

  /// Monochrome shades used for chart series (accent is used for the top item).
  List<Color> get series => [
        accent,
        ink,
        ink.withValues(alpha: 0.70),
        ink.withValues(alpha: 0.50),
        ink.withValues(alpha: 0.34),
        ink.withValues(alpha: 0.22),
        ink.withValues(alpha: 0.14),
      ];

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    return Palette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension PaletteX on BuildContext {
  Palette get p => Theme.of(this).extension<Palette>()!;
  TextTheme get tt => Theme.of(this).textTheme;
}

const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.light ? Palette.light : Palette.dark;
  final scheme = ColorScheme(
    brightness: b,
    primary: p.ink,
    onPrimary: p.bg,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: p.danger,
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.ink,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink).copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w800, letterSpacing: -2, color: p.ink, fontFeatures: tabular),
        displayMedium: base.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800, letterSpacing: -1.5, color: p.ink, fontFeatures: tabular),
        headlineLarge: base.textTheme.headlineLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1, color: p.ink),
        headlineMedium: base.textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8, color: p.ink),
        headlineSmall: base.textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5, color: p.ink),
        titleLarge:
            base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: p.ink),
        titleMedium:
            base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: p.ink),
        labelLarge:
            base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: p.ink),
      );

  return base.copyWith(
    textTheme: text,
    extensions: [p],
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle:
          b == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.line,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(color: p.bg, fontWeight: FontWeight.w600),
      actionTextColor: p.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      hintStyle: TextStyle(color: p.muted),
      labelStyle: TextStyle(color: p.muted),
      floatingLabelStyle: TextStyle(color: p.ink),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.ink, width: 1.5)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      elevation: 0,
      highlightElevation: 0,
      shape: const StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.ink,
        foregroundColor: p.bg,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : p.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.card),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.ink,
      unselectedLabelColor: p.muted,
      indicatorColor: p.ink,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      indicatorSize: TabBarIndicatorSize.label,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: p.bg,
      headerForegroundColor: p.ink,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
