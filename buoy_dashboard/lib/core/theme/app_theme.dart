import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette from "Dashboard UI.pdf".
class AppColors extends ThemeExtension<AppColors> {
  final Color bg,
      panel,
      sunken,
      text,
      muted,
      line,
      teal,
      aurora,
      wave,
      solar,
      alert;
  const AppColors({
    required this.bg,
    required this.panel,
    required this.sunken,
    required this.text,
    required this.muted,
    required this.line,
    required this.teal,
    required this.aurora,
    required this.wave,
    required this.solar,
    required this.alert,
  });

  static const light = AppColors(
    bg: Color(0xFFEEF3F4),
    panel: Color(0xFFFFFFFF),
    sunken: Color(0xFFE3ECEE),
    text: Color(0xFF132630),
    muted: Color(0xFF5C7580),
    line: Color(0x1F132630),
    teal: Color(0xFF1C6E77),
    aurora: Color(0xFF3E8E63),
    wave: Color(0xFF3E6E9E),
    solar: Color(0xFFC98A34),
    alert: Color(0xFFB84A3E),
  );

  static const dark = AppColors(
    bg: Color(0xFF081620),
    panel: Color(0xFF0E222D),
    sunken: Color(0xFF0B1B24),
    text: Color(0xFFDCE8EA),
    muted: Color(0xFF87A2AB),
    line: Color(0x1FDCE8EA),
    teal: Color(0xFF4FC1CE),
    aurora: Color(0xFF5FD9A0),
    wave: Color(0xFF7FB3E0),
    solar: Color(0xFFE3A855),
    alert: Color(0xFFE5836E),
  );

  List<Color> get palette => [teal, wave, aurora, solar, alert];

  /// A very quiet top-to-bottom wash behind the whole app — depth without
  /// competing with the data. Keep this subtle; it should read as "premium
  /// paper", not as a colored background.
  LinearGradient get backdrop => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [teal.withValues(alpha: 0.05), bg],
        stops: const [0.0, 0.35],
      );

  @override
  ThemeExtension<AppColors> copyWith() => this;

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) =>
      t < 0.5 ? this : (other as AppColors? ?? this);
}

extension ThemeCtx on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildTheme(AppColors c, Brightness b) {
  final base = ThemeData(brightness: b, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: c.teal, brightness: b)
        .copyWith(primary: c.teal, surface: c.panel),
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: c.text, displayColor: c.text),
    dividerColor: c.line,
    dividerTheme: DividerThemeData(color: c.line, thickness: 1),
    splashFactory: InkSparkle.splashFactory,
    extensions: [c],
  );
}

// ---- Text helpers ----
TextStyle display(BuildContext ctx, double size,
        {FontWeight w = FontWeight.w500, Color? color, bool italic = false}) =>
    GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: w,
      color: color ?? ctx.c.text,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );

TextStyle numStyle(BuildContext ctx,
        {double size = 14, Color? color, FontWeight w = FontWeight.w500}) =>
    GoogleFonts.inter(
      fontSize: size,
      fontWeight: w,
      color: color ?? ctx.c.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle mutedStyle(BuildContext ctx, {double size = 12}) =>
    GoogleFonts.inter(fontSize: size, color: ctx.c.muted);

/// Standard motion timings, kept in one place so the whole app feels
/// consistent (same easing/duration language everywhere).
class Motion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);
  static const curve = Curves.easeOutCubic;
}
