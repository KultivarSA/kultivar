import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const _fontFamily = 'SF Pro Display';

  static bool _dark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  // ── Display ───────────────────────────────────

  static TextStyle displayLarge(BuildContext c) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: _dark(c) ? AppColors.textPrimary : AppLightColors.textPrimary,
      );

  static TextStyle displayMedium(BuildContext c) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: _dark(c) ? AppColors.textPrimary : AppLightColors.textPrimary,
      );

  // ── Headlines ─────────────────────────────────

  static TextStyle headlineLarge(BuildContext c) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: _dark(c) ? AppColors.textPrimary : AppLightColors.textPrimary,
      );

  static TextStyle headlineMedium(BuildContext c) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: _dark(c) ? AppColors.textPrimary : AppLightColors.textPrimary,
      );

  static TextStyle headlineSmall(BuildContext c) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: _dark(c) ? AppColors.textPrimary : AppLightColors.textPrimary,
      );

  // ── Body ──────────────────────────────────────

  static TextStyle bodyLarge(BuildContext c) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: -0.2,
        color: _dark(c) ? AppColors.textPrimary : AppLightColors.textPrimary,
      );

  static TextStyle bodyMedium(BuildContext c) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: -0.2,
        color:
            _dark(c) ? AppColors.textSecondary : AppLightColors.textSecondary,
      );

  static TextStyle bodySmall(BuildContext c) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: _dark(c) ? AppColors.textMuted : AppLightColors.textMuted,
      );

  // ── Labels ────────────────────────────────────

  static TextStyle labelLarge(BuildContext c) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: _dark(c) ? AppColors.textPrimary : AppLightColors.textPrimary,
      );

  static TextStyle labelSmall(BuildContext c) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: _dark(c) ? AppColors.textMuted : AppLightColors.textMuted,
      );

  // ── Mono ──────────────────────────────────────

  static TextStyle mono(BuildContext c) => TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        letterSpacing: -0.2,
        color: _dark(c) ? AppColors.textPrimary : AppLightColors.textPrimary,
      );
}
