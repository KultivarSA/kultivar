import 'package:flutter/material.dart';

import '../models/environment_log.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ── Issue severity ────────────────────────────────

enum _IssueSeverity { critical, high, medium, low }

_IssueSeverity _severityFor(String? issueName) {
  final name = (issueName ?? '').toLowerCase();
  if (name.contains('mold')) {
    return _IssueSeverity.critical;
  }
  if (name.contains('pest')) {
    return _IssueSeverity.high;
  }
  if (name.contains('nutrient') || name.contains('deficiency')) {
    return _IssueSeverity.medium;
  }
  if (name.contains('yellowing') || name.contains('burn')) {
    return _IssueSeverity.low;
  }
  return _IssueSeverity.low;
}

// ── Recurring issue tips ──────────────────────────

String? _recurringTip(String? issueName) {
  final name = (issueName ?? '').toLowerCase();
  if (name.contains('mold')) {
    return 'Recurring mold detected. Consider '
        'increasing airflow, reducing humidity by '
        '5–10%, or improving canopy pruning.';
  }
  if (name.contains('pest')) {
    return 'Recurring pest issue. Review your IPM '
        'schedule and consider a preventative '
        'foliar application.';
  }
  if (name.contains('nutrient') || name.contains('deficiency')) {
    return 'Recurring deficiency. Check your pH '
        'range (6.0–7.0 soil / 5.5–6.5 hydro) '
        'and review feed ratios.';
  }
  return null;
}

// ── Grade model ───────────────────────────────────

class _Grade {
  final String label;
  final String title;
  final String description;
  final Color color;

  const _Grade({
    required this.label,
    required this.title,
    required this.description,
    required this.color,
  });
}

class HealthScoreCard extends StatelessWidget {
  final Plant plant;
  final List<EnvironmentLog> spaceEnvironmentLogs;
  final List<PlantNote> plantNotes;

  const HealthScoreCard({
    super.key,
    required this.plant,
    required this.spaceEnvironmentLogs,
    required this.plantNotes,
  });

  // ── Grade calculation ─────────────────────────

  _Grade get _grade {
    // Removed plants always F
    if (plant.status == PlantStatus.removed) {
      return const _Grade(
        label: 'F',
        title: 'Plant Removed',
        description: 'This plant did not complete its lifecycle.',
        color: AppColors.danger,
      );
    }

    final issueNotes =
        plantNotes.where((n) => n.category == NoteCategory.issue).toList();

    final unresolvedIssues = issueNotes.where((n) => !n.isResolved).toList();

    final resolvedIssues = issueNotes.where((n) => n.isResolved).toList();

    // Check for recurring issues (same type 2+)
    final issueCounts = <String, int>{};
    for (final n in issueNotes) {
      final key = (n.issueName ?? 'other').toLowerCase();
      issueCounts[key] = (issueCounts[key] ?? 0) + 1;
    }
    final hasRecurring = issueCounts.values.any((c) => c >= 2);

    // Highest unresolved severity
    _IssueSeverity? worstUnresolved;
    for (final n in unresolvedIssues) {
      final s = _severityFor(n.issueName);
      if (worstUnresolved == null || s.index < worstUnresolved.index) {
        worstUnresolved = s;
      }
    }

    // Environment score (last 7 days)
    final recentLogs = spaceEnvironmentLogs
        .where((l) => DateTime.now().difference(l.recordedAt).inDays <= 7)
        .toList();
    final envRatio = recentLogs.isEmpty
        ? null
        : recentLogs.where((l) => l.isOptimal).length / recentLogs.length;

    // ── Grade rules ───────────────────────────

    // AAA: no issues ever, env good or no data
    if (issueNotes.isEmpty && (envRatio == null || envRatio >= 0.85)) {
      return const _Grade(
        label: 'AAA',
        title: 'Exceptional',
        description: 'No issues detected. Environment '
            'consistently optimal.',
        color: Color(0xFF00E5B0),
      );
    }

    // AA: issues existed but ALL resolved,
    //     no recurring, env acceptable
    if (unresolvedIssues.isEmpty &&
        resolvedIssues.isNotEmpty &&
        !hasRecurring &&
        (envRatio == null || envRatio >= 0.7)) {
      return const _Grade(
        label: 'AA',
        title: 'Very Good',
        description: 'All issues resolved. Plant is '
            'back on track.',
        color: AppColors.completed,
      );
    }

    // A: issues resolved but env had variation,
    //    or minor unresolved + no critical
    if (unresolvedIssues.isEmpty && resolvedIssues.isNotEmpty) {
      return const _Grade(
        label: 'A',
        title: 'Good',
        description: 'Issues resolved. Minor environment '
            'variation noted.',
        color: AppColors.growing,
      );
    }

    // B: 1 low/medium unresolved, no critical
    if (unresolvedIssues.length == 1 &&
        (worstUnresolved == _IssueSeverity.low ||
            worstUnresolved == _IssueSeverity.medium)) {
      return const _Grade(
        label: 'B',
        title: 'Needs Attention',
        description: 'An open issue requires resolution.',
        color: AppColors.harvested,
      );
    }

    // C: multiple unresolved minor issues
    //    or 1 high severity unresolved
    if (worstUnresolved == _IssueSeverity.high ||
        unresolvedIssues.length >= 2) {
      return const _Grade(
        label: 'C',
        title: 'Under Stress',
        description: 'Multiple or significant issues '
            'need attention.',
        color: AppColors.warning,
      );
    }

    // D: critical unresolved (mold etc)
    if (worstUnresolved == _IssueSeverity.critical) {
      return const _Grade(
        label: 'D',
        title: 'Critical Issue',
        description: 'A critical issue requires '
            'immediate action.',
        color: Colors.deepOrange,
      );
    }

    // Fallback — no issues but env suboptimal
    return const _Grade(
      label: 'B',
      title: 'Monitor Environment',
      description: 'No plant issues, but environment '
          'readings are outside optimal range.',
      color: AppColors.harvested,
    );
  }

  // ── Recurring tips ────────────────────────────

  List<String> get _recurringTips {
    final tips = <String>[];
    final issueCounts = <String, int>{};
    for (final n in plantNotes.where((n) => n.category == NoteCategory.issue)) {
      final key = (n.issueName ?? 'other').toLowerCase();
      issueCounts[key] = (issueCounts[key] ?? 0) + 1;
    }
    for (final entry in issueCounts.entries) {
      if (entry.value >= 2) {
        final tip = _recurringTip(entry.key);
        if (tip != null) {
          tips.add(tip);
        }
      }
    }
    return tips;
  }

  @override
  Widget build(BuildContext context) {
    final grade = _grade;
    final issueNotes =
        plantNotes.where((n) => n.category == NoteCategory.issue).toList();
    final unresolved = issueNotes.where((n) => !n.isResolved).length;
    final resolved = issueNotes.where((n) => n.isResolved).length;
    final tips = _recurringTips;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: grade.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Grade badge
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: grade.color.withValues(alpha: 0.12),
                  border: Border.all(color: grade.color, width: 2),
                ),
                child: Center(
                  child: Text(
                    grade.label,
                    style: AppTypography.headlineSmall(
                      context,
                    ).copyWith(
                      color: grade.color,
                      fontWeight: FontWeight.w800,
                      fontSize: grade.label.length > 2 ? 16 : 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plant Health',
                        style: AppTypography.headlineSmall(
                          context,
                        )),
                    const SizedBox(height: 3),
                    Text(grade.title,
                        style: AppTypography.labelLarge(
                          context,
                        ).copyWith(color: grade.color)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(grade.description,
                        style: AppTypography.bodySmall(
                          context,
                        )),
                  ],
                ),
              ),
            ],
          ),

          // Issue summary row
          if (issueNotes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: context.colBorder),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              if (unresolved > 0) ...[
                _badge(
                  context,
                  '$unresolved open',
                  AppColors.danger,
                  Icons.warning_rounded,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              if (resolved > 0)
                _badge(
                  context,
                  '$resolved resolved',
                  AppColors.growing,
                  Icons.check_circle_rounded,
                ),
            ]),
          ],

          // Recurring issue tips
          if (tips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...tips.map((tip) => Container(
                  margin: const EdgeInsets.only(top: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb,
                          color: AppColors.warning, size: 14),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(tip,
                            style: AppTypography.bodySmall(
                              context,
                            ).copyWith(color: AppColors.warning)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _badge(
      BuildContext context, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: AppSpacing.xxs),
          Text(label,
              style: AppTypography.labelSmall(
                context,
              ).copyWith(color: color)),
        ],
      ),
    );
  }
}
