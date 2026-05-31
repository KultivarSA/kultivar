import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plant.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class CullPlantDialog extends StatefulWidget {
  final Plant plant;

  const CullPlantDialog({super.key, required this.plant});

  /// Shows the archive bottom sheet and returns the created note ID,
  /// or null if the user cancelled.
  static Future<String?> show(BuildContext context, {required Plant plant}) =>
      showModalBottomSheet<String?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colSurface2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl)),
        ),
        builder: (_) => CullPlantDialog(plant: plant),
      );

  @override
  State<CullPlantDialog> createState() => _CullPlantDialogState();
}

class _CullPlantDialogState extends State<CullPlantDialog> {
  String _selectedReason = 'Mold';
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  static const _reasons = [
    'Mold',
    'Pests',
    'Genetics',
    'Stress',
    'Hermaphrodite',
    'User decision',
    'Other',
  ];

  static const _hintByReason = {
    'Mold': 'e.g. Visible mold on lower buds',
    'Pests': 'e.g. Spider mites found on fan leaves',
    'Genetics': 'e.g. Slow growth, poor structure, hermied early',
    'Stress': 'e.g. Light burn, root-bound, overwatered',
    'Hermaphrodite': 'e.g. Pollen sacs noticed at week 4',
    'User decision': 'e.g. Clearing space for a new run',
    'Other': 'Describe the reason…',
  };

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GrowRepository>();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.sm,
          AppSpacing.pagePadding,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ───────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: context.colBorderFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ────────────────────────
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.content_cut_rounded,
                    color: AppColors.danger, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Archive Plant',
                        style: AppTypography.headlineMedium(context)),
                    Text(widget.plant.name,
                        style: AppTypography.bodySmall(context)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),

            // ── Warning banner ────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: AppColors.danger, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'This archives the plant and preserves its full history.',
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: AppColors.danger),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Reason ────────────────────────
            Text(
              'REASON',
              style: AppTypography.labelSmall(context)
                  .copyWith(color: context.colTextMuted, letterSpacing: 0.8),
            ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              dropdownColor: context.colSurface2,
              items: _reasons
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r,
                            style:
                                TextStyle(color: context.colTextPrimary)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedReason = v!),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Notes ─────────────────────────
            Text(
              'NOTES (OPTIONAL)',
              style: AppTypography.labelSmall(context)
                  .copyWith(color: context.colTextMuted, letterSpacing: 0.8),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(color: context.colTextPrimary),
              decoration: InputDecoration(
                hintText: _hintByReason[_selectedReason] ?? 'Add notes…',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Action ────────────────────────
            ElevatedButton.icon(
              icon: const Icon(Icons.content_cut_rounded, size: 18),
              label: const Text('Archive Plant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              onPressed: () {
                final noteId = repo.archivePlantWithReason(
                  plant: widget.plant,
                  reason: _selectedReason,
                  notesText: _notesController.text,
                );
                Navigator.pop(context, noteId);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: AppTypography.labelLarge(context)
                      .copyWith(color: context.colTextSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
