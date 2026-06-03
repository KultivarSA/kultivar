import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/training_reference.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'training_log_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TrainingSection
//
// Card shown on the plant detail screen.  Displays:
//  • Recovery banner — if the most recent high-stress event is still healing
//  • Horizontal timeline — every training note newest-first as tappable chips
//  • Empty state — friendly prompt when no training has been logged
//  • "Log Training" primary action
//
// Usage:
//   TrainingSection(plant: plant, notes: trainingNotes)
// ─────────────────────────────────────────────────────────────────────────────

class TrainingSection extends StatelessWidget {
  final Plant plant;

  /// All notes for this plant — the widget filters to NoteCategory.training.
  final List<PlantNote> allNotes;

  const TrainingSection({
    super.key,
    required this.plant,
    required this.allNotes,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<PlantNote> get _trainingNotes => allNotes
      .where((n) => n.category == NoteCategory.training &&
          n.trainingDetails != null)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// The most recent note that is still within its recovery window.
  PlantNote? _activeRecovery(List<PlantNote> notes) {
    for (final note in notes) {
      final d = note.trainingDetails!;
      if (d.isRecovering(note.createdAt)) return note;
    }
    return null;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notes = _trainingNotes;
    final recovery = _activeRecovery(notes);

    return Container(
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.colBorderFaint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.training.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.content_cut_rounded,
                    size: 15,
                    color: AppColors.training,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Training',
                  style: AppTypography.labelLarge(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.training.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      '${notes.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.training,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Technique frequency summary (up to 2 unique techniques)
                if (notes.isNotEmpty) _TechniqueFrequencyRow(notes: notes),
              ],
            ),
          ),

          // ── Recovery banner ───────────────────────────────────────────────
          if (recovery != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _RecoveryBanner(note: recovery),
          ],

          // ── Timeline strip ────────────────────────────────────────────────
          if (notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _TimelineStrip(notes: notes),
          ] else ...[
            _EmptyState(plant: plant),
          ],

          const SizedBox(height: AppSpacing.sm),
          // A4 — theme-aware so the bumped dark-mode borderFaint
          // doesn't bleed into light-mode rendering.
          Divider(height: 1, color: context.colBorderFaint),

          // ── Log Training button ───────────────────────────────────────────
          _LogButton(plant: plant),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recovery banner
// ─────────────────────────────────────────────────────────────────────────────

class _RecoveryBanner extends StatelessWidget {
  final PlantNote note;
  const _RecoveryBanner({required this.note});

  @override
  Widget build(BuildContext context) {
    final d = note.trainingDetails!;
    final progress = d.recoveryProgress(note.createdAt);
    final daysLeft = d.daysRemaining(note.createdAt);
    final daysDone = d.recoveryDays - daysLeft;

    // Colour transitions: red → amber → green as recovery progresses
    final Color bannerColor;
    if (progress < 0.4) {
      bannerColor = AppColors.danger;
    } else if (progress < 0.75) {
      bannerColor = AppColors.warning;
    } else {
      bannerColor = AppColors.growing;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        decoration: BoxDecoration(
          color: bannerColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.healing_rounded, size: 13, color: bannerColor),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Recovering from ${d.technique.label}'
                    '${d.targetSite != null ? ' · ${d.targetSite}' : ''}',
                    style: AppTypography.bodySmall(context).copyWith(
                      color: bannerColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                  style: TextStyle(
                    fontSize: 11,
                    color: bannerColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: bannerColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(bannerColor),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Day $daysDone of ${d.recoveryDays}',
              style: TextStyle(
                fontSize: 10,
                color: bannerColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Technique frequency summary — shown in header, up to 2 top techniques
// ─────────────────────────────────────────────────────────────────────────────

class _TechniqueFrequencyRow extends StatelessWidget {
  final List<PlantNote> notes;
  const _TechniqueFrequencyRow({required this.notes});

  @override
  Widget build(BuildContext context) {
    // Count by technique
    final freq = <TrainingTechnique, int>{};
    for (final n in notes) {
      final t = n.trainingDetails!.technique;
      freq[t] = (freq[t] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(2).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: top.map((e) {
        final info = kTrainingReference[e.key]!;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Tooltip(
            message: '${info.name} × ${e.value}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: info.stressColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                    color: info.stressColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(info.icon, size: 10, color: info.stressColor),
                  const SizedBox(width: 3),
                  Text(
                    '×${e.value}',
                    style: TextStyle(
                      fontSize: 10,
                      color: info.stressColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal timeline strip
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineStrip extends StatelessWidget {
  final List<PlantNote> notes;
  const _TimelineStrip({required this.notes});

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return '1d ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: notes.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final note = notes[i];
          final d = note.trainingDetails!;
          final info = kTrainingReference[d.technique]!;
          final isRecovering = d.isRecovering(note.createdAt);

          return GestureDetector(
            onTap: () => _showEventDetail(context, note),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: isRecovering
                    ? info.stressColor.withValues(alpha: 0.1)
                    : context.colSurface3,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: isRecovering
                      ? info.stressColor.withValues(alpha: 0.4)
                      : context.colBorder,
                  width: isRecovering ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(info.icon,
                          size: 13, color: info.stressColor),
                      const SizedBox(width: 5),
                      Text(
                        d.technique.shortLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isRecovering
                              ? info.stressColor
                              : context.colTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _relativeDate(note.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colTextMuted,
                        ),
                      ),
                      if (d.targetSite != null) ...[
                        Text(
                          ' · ${d.targetSite}',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.colTextMuted,
                          ),
                        ),
                      ],
                      if (isRecovering) ...[
                        const SizedBox(width: AppSpacing.xxs),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: info.stressColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEventDetail(BuildContext context, PlantNote note) {
    final d = note.trainingDetails!;
    final info = kTrainingReference[d.technique]!;

    // Bug fix: pop-with-result pattern -- the delete action used to
    // call repo.deleteNote synchronously then Navigator.pop, which
    // could trigger the _dependents.isEmpty race.  Now the sheet
    // pops with `true` for delete and the deletion happens here.
    final repo = context.read<GrowRepository>();
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventDetailSheet(note: note, info: info),
    ).then((deleted) {
      if (deleted != true) return;
      // Bug fix v7 -- see batch_care_sheet.dart.
      Future.delayed(
          const Duration(milliseconds: 500), () => repo.deleteNote(note.id));
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event detail mini-sheet — tap a timeline chip to open
// ─────────────────────────────────────────────────────────────────────────────

class _EventDetailSheet extends StatelessWidget {
  final PlantNote note;
  final TrainingTechniqueInfo info;

  const _EventDetailSheet({required this.note, required this.info});

  @override
  Widget build(BuildContext context) {
    final d = note.trainingDetails!;
    final daysAgo = DateTime.now().difference(note.createdAt).inDays;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            info.stressColor.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(info.icon,
                          size: 18, color: info.stressColor),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.technique.label,
                            style: AppTypography.labelLarge(context)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            daysAgo == 0
                                ? 'Today'
                                : '$daysAgo day${daysAgo == 1 ? '' : 's'} ago',
                            style: AppTypography.bodySmall(context)
                                .copyWith(color: context.colTextMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: info.stressColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull),
                        border: Border.all(
                            color:
                                info.stressColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        info.stressLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: info.stressColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Details grid
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (d.severity != null)
                      _DetailChip(
                        icon: Icons.tune_rounded,
                        label: d.severity!.label,
                        color: AppColors.training,
                      ),
                    if (d.targetSite != null)
                      _DetailChip(
                        icon: Icons.location_on_rounded,
                        label: d.targetSite!,
                        color: AppColors.secondary,
                      ),
                    if (d.nodeNumber != null)
                      _DetailChip(
                        icon: Icons.looks_one_rounded,
                        label: 'Node ${d.nodeNumber}',
                        color: AppColors.secondary,
                      ),
                    if (d.recoveryDays > 0)
                      _DetailChip(
                        icon: Icons.healing_rounded,
                        label: '${d.recoveryDays}d recovery',
                        color: AppColors.growing,
                      ),
                  ],
                ),

                // Recovery progress (if still active)
                if (d.isRecovering(note.createdAt)) ...[
                  const SizedBox(height: AppSpacing.md),
                  _RecoveryBanner(note: note),
                ],

                // Note content
                if (note.content.isNotEmpty &&
                    note.content != d.technique.label) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    note.content,
                    style: AppTypography.bodySmall(context)
                        .copyWith(height: 1.5),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),
                // Delete button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16),
                    label: const Text('Delete event'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.4)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Plant plant;
  const _EmptyState({required this.plant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
      child: Column(
        children: [
          Icon(
            Icons.content_cut_rounded,
            size: 32,
            color: context.colTextMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No training logged yet',
            style: AppTypography.bodyMedium(context)
                .copyWith(color: context.colTextMuted),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Tap Log Training to record your first\ntopping, LST, defoliation, or more.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(context).copyWith(
              color: context.colTextMuted.withValues(alpha: 0.7),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log Training CTA
// ─────────────────────────────────────────────────────────────────────────────

class _LogButton extends StatelessWidget {
  final Plant plant;
  const _LogButton({required this.plant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add_rounded, size: 17),
          label: const Text('Log Training'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.training,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () =>
              TrainingLogSheet.show(context, plant: plant),
        ),
      ),
    );
  }
}
