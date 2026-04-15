import 'package:flutter/material.dart';

@immutable
class DashboardColors extends ThemeExtension<DashboardColors> {
  const DashboardColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.panel,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.muted,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.heroGradientStart,
    required this.heroGradientEnd,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color panel;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color muted;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color heroGradientStart;
  final Color heroGradientEnd;

  static const dark = DashboardColors(
    background: Color(0xFF070B17),
    surface: Color(0xFF10182A),
    surfaceAlt: Color(0xFF0F1528),
    panel: Color(0xFF0B1120),
    border: Color(0xFF202A43),
    primary: Color(0xFF6C4DFF),
    secondary: Color(0xFF19D3C5),
    muted: Color(0xFF94A3C7),
    success: Color(0xFF25C685),
    warning: Color(0xFFFFB648),
    error: Color(0xFFFF6B6B),
    info: Color(0xFF57A6FF),
    heroGradientStart: Color(0xFF22164A),
    heroGradientEnd: Color(0xFF101727),
  );

  static const light = DashboardColors(
    background: Color(0xFFF4F7FC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF8FAFF),
    panel: Color(0xFFEFF3FB),
    border: Color(0xFFD8E0F0),
    primary: Color(0xFF5B48E0),
    secondary: Color(0xFF0EA5A4),
    muted: Color(0xFF5A6885),
    success: Color(0xFF169B62),
    warning: Color(0xFFC98607),
    error: Color(0xFFD64545),
    info: Color(0xFF2F7CF6),
    heroGradientStart: Color(0xFFE7EAFF),
    heroGradientEnd: Color(0xFFF6F8FF),
  );

  @override
  DashboardColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? panel,
    Color? border,
    Color? primary,
    Color? secondary,
    Color? muted,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? heroGradientStart,
    Color? heroGradientEnd,
  }) {
    return DashboardColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      panel: panel ?? this.panel,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      muted: muted ?? this.muted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
    );
  }

  @override
  DashboardColors lerp(ThemeExtension<DashboardColors>? other, double t) {
    if (other is! DashboardColors) return this;
    return DashboardColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      heroGradientStart: Color.lerp(
        heroGradientStart,
        other.heroGradientStart,
        t,
      )!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
    );
  }
}

extension DashboardThemeX on BuildContext {
  DashboardColors get dashboardColors =>
      Theme.of(this).extension<DashboardColors>() ?? DashboardColors.dark;
}
