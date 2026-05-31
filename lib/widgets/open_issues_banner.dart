import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../models/plant_note.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';

/// A compact banner shown on the home screen when any active plant has
/// unresolved issue notes.  Tapping an item navigates to the callback.
class OpenIssuesBanner extends StatelessWidget {
  final List<Plant> plants;
  final List<PlantNote> allNotes;
  final GrowRepository repo;

  /// Called with the plant whose row was tapped so the parent can push
  /// [PlantDetailScreen].  Declared as dynamic to avoid a circular import
  /// between home_screen and plant_detail_screen.
  final void Function(Plant) onPlantTap;

  const OpenIssuesBanner({
    super.key,
    required this.plants,
    required this.allNotes,
    required this.repo,
    required this.onPlantTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build once, look up O(1) below — the sort comparator + the row
    // builder used to do `plants.firstWhere(...)` per issue, which scales
    // poorly when many plants have open issues.
    final byId = <String, Plant>{for (final p in plants) p.id: p};
    // Only look at active (non-archived) plants.
    final activePlantIds = <String>{
      for (final p in plants)
        if (!p.isArchived) p.id
    };

    // Collect unresolved issue notes grouped by plant.
    final Map<String, List<PlantNote>> issuesByPlant = {};
    for (final note in allNotes) {
      if (!activePlantIds.contains(note.plantId)) continue;
      if (note.category != NoteCategory.issue) continue;
      if (note.isResolved) continue;
      issuesByPlant.putIfAbsent(note.plantId, () => []).add(note);
    }

    if (issuesByPlant.isEmpty) return const SizedBox.shrink();

    // Sort entries: most issues first, then alphabetically.
    final entries = issuesByPlant.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.length.compareTo(a.value.length);
        if (cmp != 0) return cmp;
        // byId hits are O(1) — no per-iteration plants scan.
        final pA = byId[a.key];
        final pB = byId[b.key];
        return (pA?.name ?? '').compareTo(pB?.name ?? '');
      });

    final totalIssues =
        issuesByPlant.values.fold<int>(0, (s, l) => s + l.length);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '$totalIssues Open Issue${totalIssues == 1 ? '' : 's'}',
                  style: AppTypography.labelLarge(context)
                      .copyWith(color: AppColors.danger),
                ),
                const Spacer(),
                Text(
                  '${issuesByPlant.length} plant${issuesByPlant.length == 1 ? '' : 's'}',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: AppColors.danger.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xs),
          Divider(
              color: AppColors.danger.withValues(alpha: 0.15), height: 1),

          // ── Issue rows ───────────────────────
          ...entries.map((entry) {
            // Skip rows whose plant somehow vanished between scan + render
            // (e.g. concurrent delete) rather than throwing StateError.
            final plant = byId[entry.key];
            if (plant == null) return const SizedBox.shrink();
            final issues = entry.value
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final latestIssue = issues.first;

            return _IssueRow(
              plant: plant,
              issues: issues,
              latestIssue: latestIssue,
              repo: repo,
              onTap: () => onPlantTap(plant),
            );
          }),
        ],
      ),
    );
  }
}

// ── Single plant issue row ─────────────────────────

class _IssueRow extends StatelessWidget {
  final Plant plant;
  final List<PlantNote> issues;
  final PlantNote latestIssue;
  final GrowRepository repo;
  final VoidCallback onTap;

  const _IssueRow({
    required this.plant,
    required this.issues,
    required this.latestIssue,
    required this.repo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final issueLabel = latestIssue.issueName?.isNotEmpty == true
        ? latestIssue.issueName!
        : latestIssue.content.split('\n').first;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 10),
        child: Row(
          children: [
            // Count bubble
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${issues.length}',
                  style: AppTypography.labelSmall(context).copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Plant name + issue preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.name,
                    style: AppTypography.labelLarge(context)
                        .copyWith(fontSize: 13),
                  ),
                  Text(
                    issueLabel,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: context.colTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Date + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtShortDate(latestIssue.createdAt),
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 9),
                ),
                const SizedBox(height: 2),
                Icon(Icons.chevron_right,
                    size: 14, color: context.colTextMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
