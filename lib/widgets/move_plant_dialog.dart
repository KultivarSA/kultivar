import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plant.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class MovePlantDialog extends StatefulWidget {
  final Plant plant;

  const MovePlantDialog({super.key, required this.plant});

  /// Shows the move-plant bottom sheet.
  static Future<void> show(BuildContext context, {required Plant plant}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colSurface2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl)),
        ),
        builder: (_) => MovePlantDialog(plant: plant),
      );

  @override
  State<MovePlantDialog> createState() => _MovePlantDialogState();
}

class _MovePlantDialogState extends State<MovePlantDialog> {
  String? _selectedSpaceId;

  @override
  void initState() {
    super.initState();
    final repo = context.read<GrowRepository>();
    final available = repo.growSpaces
        .where((s) => s.id != widget.plant.growSpaceId)
        .toList();
    _selectedSpaceId = available.isNotEmpty ? available.first.id : null;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();
    final spaces = repo.growSpaces
        .where((s) => s.id != widget.plant.growSpaceId)
        .toList();
    final plantCountBySpace = {
      for (final s in spaces)
        s.id: repo.plants
            .where((p) => p.growSpaceId == s.id && !p.isArchived)
            .length,
    };

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
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.swap_horiz_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Move Plant',
                        style: AppTypography.headlineMedium(context)),
                    Text(widget.plant.name,
                        style: AppTypography.bodySmall(context)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),

            if (spaces.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.colSurface1,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: context.colBorder),
                ),
                child: Text(
                  'No other grow spaces available.',
                  style: AppTypography.bodyMedium(context)
                      .copyWith(color: context.colTextMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              // ── Space picker ──────────────
              Text(
                'DESTINATION SPACE',
                style: AppTypography.labelSmall(context)
                    .copyWith(color: context.colTextMuted, letterSpacing: 0.8),
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _selectedSpaceId,
                dropdownColor: context.colSurface2,
                style: TextStyle(color: context.colTextPrimary),
                items: spaces
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.name}  ·  ${plantCountBySpace[s.id] ?? 0} '
                            'plant${(plantCountBySpace[s.id] ?? 0) == 1 ? '' : 's'}',
                            style:
                                TextStyle(color: context.colTextPrimary),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSpaceId = v),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Action ────────────────────
              ElevatedButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Move Plant'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                onPressed: _selectedSpaceId == null
                    ? null
                    : () {
                        repo.movePlant(
                          plant: widget.plant,
                          newGrowSpaceId: _selectedSpaceId!,
                        );
                        Navigator.pop(context);
                      },
              ),
            ],
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
