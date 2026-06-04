import 'package:flutter/material.dart';

import '../config/whats_new_content.dart';
import '../services/whats_new_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_sheet.dart';

/// Modal bottom sheet that presents the changes a user is getting on
/// their first launch after a Play Store update.
///
/// Reuses [AppSheet]'s standard chrome (drag handle, padding, etc.)
/// so it sits visually consistent with every other modal in the app.
/// The only structural addition is the version pill at the top and
/// the bullet list -- both deliberately spartan; the goal is to
/// inform, not to advertise.
class WhatsNewSheet extends StatelessWidget {
  final WhatsNewEntry entry;
  final int buildNumber;

  const WhatsNewSheet({
    super.key,
    required this.entry,
    required this.buildNumber,
  });

  /// Convenience constructor.  Wraps the sheet in `showModalBottomSheet`
  /// with the project conventions (transparent background, scroll-
  /// controlled, blocking).  Marks the build as seen on dismiss so a
  /// hard-back / scrim-tap counts the same as the explicit Got It.
  static Future<void> show(
    BuildContext context, {
    required WhatsNewEntry entry,
    required int buildNumber,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          WhatsNewSheet(entry: entry, buildNumber: buildNumber),
    );
    // Mark seen regardless of how the sheet closed.  If we only
    // marked on the explicit Got It tap, a back-gesture dismiss
    // would re-trigger the sheet on the next app start -- annoying.
    await WhatsNewService.markSeen(buildNumber);
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: "What's new",
      subtitle: entry.headline,
      icon: Icons.auto_awesome_rounded,
      iconColor: AppColors.primary,
      children: [
        // Version pill -- small chip below the standard AppSheet
        // header that anchors the bullets to a concrete release.
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'v${entry.versionName}',
              style: AppTypography.labelSmall(context)
                  .copyWith(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Bullets.  Each row is a flex-aligned bullet + line so long
        // strings wrap cleanly under the dot rather than under the
        // first character of text.
        ...entry.highlights.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      line,
                      style: AppTypography.bodyMedium(context),
                    ),
                  ),
                ],
              ),
            )),

        const SizedBox(height: AppSpacing.md),

        // Single-action CTA -- no Cancel, no secondary buttons.
        // The sheet's purpose is to inform, not to gate; the dismiss
        // is unconditional.
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusMd),
              ),
              elevation: 0,
            ),
            child: Text(
              'Got it',
              style: AppTypography.labelLarge(context).copyWith(
                color: Colors.black,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
