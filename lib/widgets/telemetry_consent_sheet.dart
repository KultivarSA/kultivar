import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/telemetry_consent_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_sheet.dart';

/// SR6 — First-launch telemetry consent sheet.
///
/// Shown ONCE, immediately after onboarding completes on a fresh
/// install.  Either button persists the user's choice via
/// [TelemetryConsentService] and dismisses the sheet; a tap on the
/// barrier (or a swipe-down dismiss) counts as **decline** —
/// privacy-first default.
///
/// Copy is intentionally short and direct:
///   • What we'd collect (crash reports + anonymous interaction
///     events for performance work)
///   • What we'd NEVER collect (grow data, personal info)
///   • Where to change later (Settings → Privacy)
///
/// Three rules the body follows so the sheet stays App Store /
/// Play Store compliant:
///   1. No pre-ticked checkbox — the user must perform an explicit
///      action to opt in.
///   2. "Decline" is at least as prominent as "Help improve"
///      (Material's primary FilledButton + secondary TextButton —
///      same visual weight).
///   3. Refusal is consequence-free — both choices land the user
///      in the same shell screen with identical functionality.
class TelemetryConsentSheet extends StatelessWidget {
  const TelemetryConsentSheet({super.key});

  /// Convenience launcher.  Returns once the user has chosen (or
  /// dismissed — which counts as decline).
  static Future<void> show(BuildContext context) async {
    final service = context.read<TelemetryConsentService>();
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => const TelemetryConsentSheet(),
    );
    // Dismissed by barrier tap / swipe = decline.  Either button
    // sets the result explicitly before popping.
    if (result == null) {
      await service.decline();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      icon: Icons.shield_outlined,
      iconColor: AppColors.primary,
      title: 'Help improve Kultivar?',
      subtitle: 'Privacy-first by default',
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sharing anonymous crash reports + interaction events helps '
          'us find the slow bits and fix them faster. No grow data, '
          'no personal info, no identifiers — ever.',
          style: AppTypography.bodyMedium(context),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── What we collect / what we don't ────────────
        const _Row(
          icon: Icons.check_circle_rounded,
          color: AppColors.growing,
          text:
              'Crash stack traces, screen-load times, version + device '
              'class.',
        ),
        const SizedBox(height: AppSpacing.xs),
        const _Row(
          icon: Icons.cancel_rounded,
          color: AppColors.danger,
          text:
              'Plant names, strain names, photos, notes, harvest '
              'weights, expense data — never sent.',
        ),

        const SizedBox(height: AppSpacing.md),
        Text(
          'You can change your mind any time in Settings → Privacy.',
          style: AppTypography.bodySmall(context).copyWith(
            color: context.colTextMuted,
            fontStyle: FontStyle.italic,
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Buttons ────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await context.read<TelemetryConsentService>().decline();
                  if (!context.mounted) return;
                  Navigator.of(context).pop(false);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colTextSecondary,
                  side: BorderSide(color: context.colBorder),
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md),
                ),
                child: const Text('No thanks'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  await context.read<TelemetryConsentService>().grant();
                  if (!context.mounted) return;
                  Navigator.of(context).pop(true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md),
                ),
                child: const Text('Help improve'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Row({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall(context),
          ),
        ),
      ],
    );
  }
}
