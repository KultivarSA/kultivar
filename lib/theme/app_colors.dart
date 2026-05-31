import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────
  static const primary = Color(0xFF00C896); // teal-green
  static const secondary = Color(0xFF7B61FF); // purple
  static const accent = Color(0xFFFFB547); // amber

  // ── Surface hierarchy ────────────────────────
  static const bg = Color(0xFF0A0A0F); // deepest background
  static const surface1 = Color(0xFF13131A); // cards
  static const surface2 = Color(0xFF1C1C27); // elevated cards
  static const surface3 = Color(0xFF252534); // inputs, chips

  // ── Borders ───────────────────────────────────
  //
  // A4 — `borderFaint` was previously `0xFF1E1E2E`, only ~11 RGB units
  // brighter than `surface1` (0xFF13131A).  On OLED phones the line
  // essentially vanished against cards in dark mode.  Bumped to
  // `0xFF26263B` (~25% lift in each channel) — clearly visible against
  // both surface1 + surface2 but still subordinate to the regular
  // `border` token below.  Light-mode token also nudged darker for the
  // matching contrast story on white cards.
  static const border = Color(0xFF2A2A3D);
  static const borderFaint = Color(0xFF26263B);

  // ── Text ──────────────────────────────────────
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF9090AA);
  static const textMuted = Color(0xFF5A5A70);

  // ── Note-category accents ─────────────────────
  static const info = Color(0xFF3B82F6);      // observation
  static const water = Color(0xFF06B6D4);     // watering
  static const ipmColor = Color(0xFFF97316);  // IPM / pest control
  static const training = Color(0xFF14B8A6);  // training techniques

  // ── Status ────────────────────────────────────
  static const growing = Color(0xFF00C896);
  static const harvested = Color(0xFFFFB547);
  static const drying = Color(0xFFFFD166);
  static const curing = Color(0xFF7B61FF);
  static const completed = Color(0xFF06D6A0);
  static const removed = Color(0xFFEF4565);
  static const optimal = Color(0xFF00C896);
  static const warning = Color(0xFFFFB547);
  static const danger = Color(0xFFEF4565);

  // ── Gradients ─────────────────────────────────
  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C896), Color(0xFF00A878)],
  );

  static const gradientPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B61FF), Color(0xFF5A45CC)],
  );

  static const gradientAmber = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB547), Color(0xFFE09030)],
  );

  static const gradientCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C1C27), Color(0xFF13131A)],
  );

  // ── Status color lookup ────────────────────────
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'growing':
        return growing;
      case 'harvested':
        return harvested;
      case 'drying':
        return drying;
      case 'curing':
        return curing;
      case 'completed':
        return completed;
      case 'removed':
        return removed;
      default:
        return textSecondary;
    }
  }
}
// ── Light colour tokens ───────────────────────────

class AppLightColors {
  AppLightColors._();

  static const bg = Color(0xFFF4F6F9);
  static const surface1 = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF0F2F5);
  static const surface3 = Color(0xFFE8EBF0);
  static const border = Color(0xFFD8DCE5);
  // A4 — bumped from 0xFFECEFF4 → 0xFFE2E6EE.  The prior value was
  // only ~19 RGB units off pure white, vanishing on white cards.
  static const borderFaint = Color(0xFFE2E6EE);

  static const textPrimary = Color(0xFF0F1117);
  static const textSecondary = Color(0xFF4A4F60);
  static const textMuted = Color(0xFF8A8FA0);
}

// ── Theme-aware colour extension ─────────────────

extension AppColorsTheme on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get colBg => _isDark ? AppColors.bg : AppLightColors.bg;
  Color get colSurface1 =>
      _isDark ? AppColors.surface1 : AppLightColors.surface1;
  Color get colSurface2 =>
      _isDark ? AppColors.surface2 : AppLightColors.surface2;
  Color get colSurface3 =>
      _isDark ? AppColors.surface3 : AppLightColors.surface3;
  Color get colBorder => _isDark ? AppColors.border : AppLightColors.border;
  Color get colBorderFaint =>
      _isDark ? AppColors.borderFaint : AppLightColors.borderFaint;
  Color get colTextPrimary =>
      _isDark ? AppColors.textPrimary : AppLightColors.textPrimary;
  Color get colTextSecondary =>
      _isDark ? AppColors.textSecondary : AppLightColors.textSecondary;
  Color get colTextMuted =>
      _isDark ? AppColors.textMuted : AppLightColors.textMuted;
}
