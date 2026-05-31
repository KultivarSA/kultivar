import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_toast.dart';
import '../widgets/empty_state.dart';
import '../widgets/empty_state_art.dart';
import 'plant_detail_screen.dart';

class PlantNotesTab extends StatelessWidget {
  const PlantNotesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();
    final l = AppLocalizations.of(context);

    final growing =
        repo.plants.where((p) => p.status == PlantStatus.growing).toList();
    final drying =
        repo.plants.where((p) => p.status == PlantStatus.drying).toList();
    final curing =
        repo.plants.where((p) => p.status == PlantStatus.curing).toList();
    final harvested =
        repo.plants.where((p) => p.status == PlantStatus.harvested).toList();
    final completed =
        repo.plants.where((p) => p.status == PlantStatus.completed).toList();
    final removed =
        repo.plants.where((p) => p.status == PlantStatus.removed).toList();

    // Build once — avoids O(plants × notes) repeated where() calls below.
    final notesByPlant = <String, List<PlantNote>>{};
    for (final note in repo.notes) {
      (notesByPlant[note.plantId] ??= []).add(note);
    }
    for (final list in notesByPlant.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final totalNotes = repo.notes.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.xs),
            Text(l.notesTitle,
                style: AppTypography.headlineLarge(context)
                    .copyWith(color: AppColors.primary)),
            const Spacer(),
            if (totalNotes > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$totalNotes notes',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
      body: repo.plants.isEmpty
          ? EmptyState(
              art: EmptyArt.note,
              title: l.notesEmptyNoPlantsTitle,
              subtitle: l.notesEmptyNoPlantsBody,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.pagePadding,
                AppSpacing.pagePadding,
                100,
              ),
              children: [
                _section(context, l.statusGrowing, AppColors.growing, growing,
                    Icons.eco_rounded, notesByPlant),
                _section(context, l.statusDrying, AppColors.drying, drying,
                    Icons.air_rounded, notesByPlant),
                _section(context, l.statusCuring, AppColors.curing, curing,
                    Icons.inventory_2_rounded, notesByPlant),
                _section(context, l.statusHarvested, AppColors.harvested,
                    harvested, Icons.agriculture_rounded, notesByPlant),
                _section(context, l.statusCompleted, AppColors.completed,
                    completed, Icons.verified_rounded, notesByPlant),
                _section(context, l.statusRemoved, AppColors.danger, removed,
                    Icons.cancel_rounded, notesByPlant),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'plant_notes_fab',
        onPressed: () => _showPlantPicker(context, repo),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 0,
        icon: const Icon(Icons.add),
        label: Text(l.notesAddButton,
            style: AppTypography.labelLarge(context)
                .copyWith(color: Colors.black)),
      ),
    );
  }

  // ── Section builder ───────────────────────────

  Widget _section(
    BuildContext context,
    String title,
    Color color,
    List<Plant> plants,
    IconData icon,
    Map<String, List<PlantNote>> notesByPlant,
  ) {
    if (plants.isEmpty) return const SizedBox.shrink();

    // If every plant in this section has no notes, show a single hint line
    // instead of N identical "No notes yet" tiles.
    final allEmpty =
        plants.every((p) => (notesByPlant[p.id] ?? []).isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: AppTypography.labelLarge(context).copyWith(
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  '${plants.length}',
                  style:
                      AppTypography.labelSmall(context).copyWith(color: color),
                ),
              ),
            ],
          ),
        ),

        // Section-level empty hint — avoids N identical "No notes yet" tiles.
        if (allEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(
              AppLocalizations.of(context).notesEmptyNoNotesPrompt,
              style: AppTypography.bodySmall(context).copyWith(
                color: context.colTextMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ] else
          ...plants.map((plant) {
          final plantNotes = notesByPlant[plant.id] ?? [];
          final noteCount = plantNotes.length;
          final lastNote = plantNotes; // already sorted desc
          final preview = lastNote.isEmpty
              ? AppLocalizations.of(context).notesEmptyNoNotes
              : lastNote.first.content.length > 55
                  ? '${lastNote.first.content.substring(0, 55)}…'
                  : lastNote.first.content;

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlantDetailScreen(plant: plant),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.colSurface1,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plant.name,
                            style: AppTypography.labelLarge(context)),
                        const SizedBox(height: 2),
                        Text(plant.strain,
                            style: AppTypography.bodySmall(context)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          preview,
                          style: AppTypography.bodySmall(context).copyWith(
                            color: noteCount == 0
                                ? context.colTextMuted
                                : context.colTextSecondary,
                            fontStyle: noteCount == 0
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: noteCount > 0
                              ? color.withValues(alpha: 0.15)
                              : context.colSurface3,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          '$noteCount',
                          style: AppTypography.labelLarge(context).copyWith(
                            color: noteCount > 0 ? color : context.colTextMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        noteCount == 1 ? 'note' : 'notes',
                        style: AppTypography.bodySmall(context),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.chevron_right,
                      color: context.colTextMuted, size: 18),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  // ── Plant picker sheet ────────────────────────

  void _showPlantPicker(BuildContext context, GrowRepository repo) {
    if (repo.plants.isEmpty) {
      AppToast.show(
        context,
        AppLocalizations.of(context).notesAddNoPlantToast,
        type: ToastType.info,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.lg,
              AppSpacing.pagePadding,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text(AppLocalizations.of(context).notesAddToSheetTitle,
                    style: AppTypography.headlineMedium(context)),
              ],
            ),
          ),
          Divider(color: context.colBorder, height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: repo.plants.length,
              itemBuilder: (context, index) {
                final plant = repo.plants[index];
                final color = AppColors.statusColor(plant.statusLabel);
                return ListTile(
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  title: Text(plant.name,
                      style: AppTypography.labelLarge(context)),
                  subtitle: Text(plant.statusLabel,
                      style: AppTypography.bodySmall(context)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlantDetailScreen(plant: plant),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
