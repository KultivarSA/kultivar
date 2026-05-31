import 'package:flutter/material.dart';

import '../../models/plant.dart';
import '../../screens/nutrient_calculator_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Entry-point button to the nutrient calculator, pre-filled with the
/// current plant's stage + medium when available.
///
/// Extracted from `plant_detail_screen.dart` (Q1a) — kept public so it
/// can be reused from anywhere a context-aware nutrient guide button
/// makes sense.
class NutrientGuideButton extends StatelessWidget {
  final GrowStage? growStage;
  final String? medium;

  const NutrientGuideButton({super.key, this.growStage, this.medium});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NutrientCalculatorScreen(
            initialStage: growStage,
            initialMedium: medium,
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.colBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Nutrient Guide',
                style: AppTypography.bodyMedium(context),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.colTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}
