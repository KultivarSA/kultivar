import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/recommendation_engine.dart';

class RecommendationsPanel extends StatelessWidget {
  final List<Recommendation> recommendations;

  const RecommendationsPanel({
    super.key,
    required this.recommendations,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      children: recommendations.map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: ListTile(
            leading: const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.accent,
              size: 20,
            ),
            title: Text(r.message, style: AppTypography.bodyMedium(context)),
            contentPadding: EdgeInsets.zero,
          ),
        );
      }).toList(),
    );
  }
}
