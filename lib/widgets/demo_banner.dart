import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../repository/grow_repository.dart';
import '../services/demo_data_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/confirm_sheet.dart';

/// Persistent top-of-screen banner shown while demo mode is active.
///
/// Rendered inside [ShellScreen] via [ValueListenableBuilder] on
/// [KultivarApp.isDemoModeNotifier]. Disappears automatically once the user
/// clears sample data and the notifier flips back to false.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Bug fix (real-device finding): the banner used to render flush
    // against the top of the screen, which pushed UP into Android's
    // system status bar (time / wifi / battery indicators).  Wrap in
    // SafeArea so the OS-reserved area pushes the banner down, AND
    // tint the safe-area inset the same colour so the result looks
    // intentional rather than a strip of background poking through.
    return ColoredBox(
      color: AppColors.warning.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: 9,
      ),
      child: Row(
        children: [
          // ── Icon + label ───────────────────────────
          const Icon(Icons.science_rounded,
              color: AppColors.warning, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Demo mode — sample data loaded.',
              style: AppTypography.bodySmall(context).copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // ── CTA ────────────────────────────────────
          GestureDetector(
            onTap: () => _confirmClear(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.18),
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
              ),
              child: Text(
                'Clear & Start Fresh',
                style: AppTypography.labelSmall(context).copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    final repo = context.read<GrowRepository>();
    ConfirmSheet.show(
      context,
      icon: Icons.delete_sweep_rounded,
      iconColor: AppColors.warning,
      title: 'Clear Sample Data?',
      body: 'This removes all demo grows, spaces, and logs, '
          'then walks you through setting up your own journal.',
      confirmLabel: 'Clear & Start Fresh',
      confirmColor: AppColors.warning,
      onConfirm: () async {
        await DemoDataService.clear(repo);
        KultivarApp.isDemoModeNotifier.value = false;
      },
    );
  }
}
