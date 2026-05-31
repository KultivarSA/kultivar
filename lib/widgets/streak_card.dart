import 'package:flutter/material.dart';

import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class StreakCard extends StatelessWidget {
  final StreakData streak;

  const StreakCard({super.key, required this.streak});

  String get _flameEmoji {
    if (streak.currentStreak >= 30) return '🔥🔥🔥';
    if (streak.currentStreak >= 14) return '🔥🔥';
    if (streak.currentStreak >= 3) return '🔥';
    return '🌱';
  }

  String get _message {
    if (streak.currentStreak == 0) {
      return 'Log something today to start your streak!';
    }
    if (streak.currentStreak == 1) {
      return 'Great start — come back tomorrow!';
    }
    if (streak.currentStreak >= 30) {
      return 'Legendary grower! Keep it up!';
    }
    if (streak.currentStreak >= 14) {
      return 'On fire! Two weeks strong!';
    }
    if (streak.currentStreak >= 7) {
      return 'One week streak — impressive!';
    }
    return 'Keep the momentum going!';
  }

  @override
  Widget build(BuildContext context) {
    final hasStreak = streak.currentStreak > 0;
    final color = hasStreak ? AppColors.harvested : context.colTextMuted;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        gradient: hasStreak
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.harvested.withValues(alpha: 0.08),
                  context.colSurface1,
                ],
              )
            : null,
      ),
      child: Row(
        children: [
          Text(_flameEmoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${streak.currentStreak}',
                      style: AppTypography.displayMedium(context)
                          .copyWith(color: color),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'day${streak.currentStreak == 1 ? '' : 's'}',
                      style: AppTypography.headlineSmall(context)
                          .copyWith(color: context.colTextSecondary),
                    ),
                  ],
                ),
                Text(_message, style: AppTypography.bodyMedium(context)),
              ],
            ),
          ),
          if (streak.longestStreak > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Best', style: AppTypography.labelSmall(context)),
                Text(
                  '${streak.longestStreak}d',
                  style: AppTypography.headlineSmall(context)
                      .copyWith(color: context.colTextSecondary),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
