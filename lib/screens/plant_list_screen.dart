import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/grow_space.dart';
import '../models/plant.dart';
import '../repository/grow_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/bulk_report_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/empty_state_art.dart';
import '../widgets/undo_overlay.dart';
import 'plant_detail_screen.dart';

class PlantListScreen extends StatefulWidget {
  final String title;
  final bool Function(Plant) filter;

  const PlantListScreen({
    super.key,
    required this.title,
    required this.filter,
  });

  @override
  State<PlantListScreen> createState() => _PlantListScreenState();
}

class _PlantListScreenState extends State<PlantListScreen> {
  final Set<String> _selected = {};
  bool _selectionMode = false;

  // ── Selection helpers ──────────────────────────

  void _enterSelection(String plantId) {
    // Tactile confirmation matches the iOS Files / Photos pattern users
    // expect when entering multi-select via long-press.
    HapticFeedback.selectionClick();
    setState(() {
      _selectionMode = true;
      _selected.add(plantId);
    });
  }

  void _toggleItem(String plantId) {
    // Subtle haptic on every selection toggle — same intent as the
    // iOS Mail / Photos checkmark rows.
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(plantId)) {
        _selected.remove(plantId);
        if (_selected.isEmpty) _selectionMode = false;
      } else {
        _selected.add(plantId);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  void _selectAll(List<Plant> plants) {
    setState(() {
      if (_selected.length == plants.length) {
        _selected.clear();
        if (_selected.isEmpty) _selectionMode = false;
      } else {
        _selected
          ..clear()
          ..addAll(plants.map((p) => p.id));
      }
    });
  }

  // ── Batch actions ──────────────────────────────

  void _showMoveSheet(BuildContext context, GrowRepository repo,
      List<Plant> allPlants) {
    final spaces = repo.growSpaces;
    if (spaces.isEmpty) {
      AppToast.show(context, 'No grow spaces available', type: ToastType.info);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.pagePadding,
          right: AppSpacing.pagePadding,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: ctx.colBorder,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.swap_horiz_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Move to Space',
                        style: AppTypography.headlineMedium(ctx)),
                    Text(
                      '${_selected.length} '
                      '${_selected.length == 1 ? 'plant' : 'plants'} selected',
                      style: AppTypography.bodySmall(ctx)
                          .copyWith(color: ctx.colTextMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Space list
            ...spaces.map((space) {
              final count = repo.plants
                  .where((p) =>
                      p.growSpaceId == space.id && !p.isArchived)
                  .length;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.home_work_rounded,
                      color: AppColors.secondary, size: 20),
                ),
                title: Text(space.name,
                    style: AppTypography.labelLarge(ctx)),
                subtitle: Text(
                  '$count active ${count == 1 ? 'plant' : 'plants'} · ${space.type}',
                  style: AppTypography.bodySmall(ctx)
                      .copyWith(color: ctx.colTextMuted),
                ),
                trailing: Icon(Icons.chevron_right,
                    color: ctx.colTextMuted),
                onTap: () {
                  final selected = Set<String>.from(_selected);
                  Navigator.pop(ctx);
                  _movePlants(context, repo, allPlants, space, selected);
                },
              );
            }),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm)),
                child: Text('Cancel',
                    style: AppTypography.labelLarge(ctx)
                        .copyWith(color: ctx.colTextSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _movePlants(
    BuildContext context,
    GrowRepository repo,
    List<Plant> allPlants,
    GrowSpace destination,
    Set<String> ids,
  ) {
    int moved = 0;
    for (final plant
        in allPlants.where((p) => ids.contains(p.id))) {
      if (plant.growSpaceId == destination.id) continue;
      repo.updatePlant(plant.copyWith(growSpaceId: destination.id));
      moved++;
    }
    _exitSelection();
    if (moved > 0) {
      AppToast.show(
        context,
        'Moved $moved ${moved == 1 ? 'plant' : 'plants'} to ${destination.name}',
        type: ToastType.success,
      );
    } else {
      AppToast.show(context, 'All selected plants are already in that space',
          type: ToastType.info);
    }
  }

  Future<void> _exportSelected(
      BuildContext context, GrowRepository repo, List<Plant> allPlants) async {
    final ids = Set<String>.from(_selected);
    final selected = allPlants.where((p) => ids.contains(p.id)).toList();
    if (selected.isEmpty) return;
    final count = selected.length;
    try {
      // Build + share happens off the UI thread inside the pdf package.
      await BulkReportService.buildAndShare(repo: repo, plants: selected);
      if (!context.mounted) return;
      _exitSelection();
      AppToast.show(
        context,
        'Generated PDF for $count ${count == 1 ? 'plant' : 'plants'}',
        type: ToastType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'PDF export failed: $e',
          type: ToastType.error);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, GrowRepository repo, List<Plant> allPlants) async {
    final count = _selected.length;
    final confirmed = await ConfirmSheet.show(
      context,
      icon: Icons.delete_forever_rounded,
      iconColor: AppColors.danger,
      title: 'Delete $count ${count == 1 ? 'Plant' : 'Plants'}?',
      body: 'All notes, photos and harvest data will be deleted. '
          'You\'ll have 5 seconds to undo.',
      confirmLabel: 'Delete',
    );

    if (!confirmed || !context.mounted) return;

    final ids = Set<String>.from(_selected);
    final ns = NotificationService();
    final plantsToDelete =
        allPlants.where((p) => ids.contains(p.id)).toList();

    // Cancel every scheduled notification for every selected plant —
    // parallelised so deleting 20 plants doesn't lock up the channel.
    await Future.wait([
      for (final plant in plantsToDelete) ...[
        ns.cancelWateringReminder(plant.id),
        ns.cancelFeedingReminder(plant.id),
        ns.cancelIpmReminder(plant.id),
        ns.cancelHarvestReminder(plant.id),
      ],
    ]);

    if (!context.mounted) return;

    // Soft-delete each plant and collect snapshots.  Photos stay on disk
    // until either restore (re-references them) or timeout (commits the
    // physical deletion).
    final snapshots = <DeletedPlantSnapshot>[];
    for (final plant in plantsToDelete) {
      final snap = repo.softDeletePlant(plant.id);
      if (snap != null) snapshots.add(snap);
    }
    final deletedCount = snapshots.length;
    _exitSelection();

    if (!context.mounted || deletedCount == 0) return;

    // Single Undo overlay covering all selected plants.
    UndoOverlay.show(
      context,
      icon: Icons.delete_forever_rounded,
      color: AppColors.danger,
      title:
          '$deletedCount ${deletedCount == 1 ? 'plant' : 'plants'} deleted',
      subtitle:
          'Tap Undo to restore, or wait to confirm permanent deletion.',
      undoLabel: 'Undo',
      onUndo: () {
        for (final snap in snapshots) {
          repo.restoreDeletedPlant(snap);
        }
      },
      onTimeout: () {
        // User let the window expire — finalise the delete by removing
        // the on-disk photos referenced by the deleted plants' notes.
        for (final snap in snapshots) {
          repo.commitDeletedPlant(snap);
        }
      },
    );
  }

  Future<void> _confirmArchive(
      BuildContext context, GrowRepository repo, List<Plant> allPlants) async {
    final count = _selected.length;
    final confirmed = await ConfirmSheet.show(
      context,
      icon: Icons.archive_rounded,
      iconColor: AppColors.danger,
      title: 'Archive $count ${count == 1 ? 'Plant' : 'Plants'}?',
      body: 'Selected plants will be marked as removed. '
          'Their notes and harvest data are kept.',
      confirmLabel: 'Archive',
    );

    if (confirmed && context.mounted) {
      final ids = Set<String>.from(_selected);
      int archived = 0;
      for (final plant
          in allPlants.where((p) => ids.contains(p.id))) {
        repo.updatePlant(plant.copyWith(
          status: PlantStatus.removed,
          isArchived: true,
          archivedAt: DateTime.now(),
          archiveReason: 'Batch archived',
        ));
        archived++;
      }
      _exitSelection();
      AppToast.show(
        context,
        'Archived $archived ${archived == 1 ? 'plant' : 'plants'}',
        type: ToastType.error,
      );
    }
  }

  // ── Build ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();
    final plants = repo.plants.where(widget.filter).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Exit selection',
                  onPressed: _exitSelection,
                )
              : null,
          title: _selectionMode
              ? Text(
                  '${_selected.length} selected',
                  style: AppTypography.headlineMedium(context)
                      .copyWith(color: AppColors.primary),
                )
              : Text(widget.title),
          actions: _selectionMode
              ? [
                  // Select all / deselect all toggle
                  TextButton(
                    onPressed: () => _selectAll(plants),
                    child: Text(
                      _selected.length == plants.length
                          ? 'Deselect all'
                          : 'Select all',
                      style: AppTypography.labelLarge(context)
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ]
              : null,
        ),
        body: plants.isEmpty
            ? EmptyState(
                art: EmptyArt.plant,
                title: 'No Plants Here',
                subtitle:
                    'Plants matching "${widget.title}"\nwill appear here.',
              )
            : ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  AppSpacing.pagePadding,
                  AppSpacing.pagePadding,
                  // Extra bottom padding when the action bar is visible
                  // The bulk action bar is a 3-row stack (Move row +
                  // Export PDF row + Archive/Delete row) plus safe-area
                  // padding, so the last plant tile needs ~210 px of
                  // room to clear it.
                  _selectionMode ? 210 : AppSpacing.pagePadding,
                ),
                itemCount: plants.length,
                itemBuilder: (_, index) {
                  final plant = plants[index];
                  final isSelected = _selected.contains(plant.id);
                  final statusColor =
                      AppColors.statusColor(plant.statusLabel);

                  return GestureDetector(
                    onLongPress: _selectionMode
                        ? null
                        : () => _enterSelection(plant.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : context.colSurface1,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : statusColor.withValues(alpha: 0.25),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        leading: _selectionMode
                            ? AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : context.colTextMuted,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.black)
                                    : null,
                              )
                            : null,
                        title: Text(
                          plant.name,
                          style: AppTypography.labelLarge(context),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plant.strain.isNotEmpty
                                  ? '${plant.strain} · ${plant.statusLabel}'
                                  : plant.statusLabel,
                              style: AppTypography.bodySmall(context)
                                  .copyWith(color: statusColor),
                            ),
                            if (plant.phenotypeTag != null) ...[
                              const SizedBox(height: 3),
                              _PhenoChip(tag: plant.phenotypeTag!),
                            ],
                          ],
                        ),
                        trailing: _selectionMode
                            ? null
                            : Icon(
                                Icons.chevron_right,
                                color: context.colTextMuted,
                              ),
                        onTap: _selectionMode
                            ? () => _toggleItem(plant.id)
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlantDetailScreen(
                                      plant: plant,
                                      siblings: plants,
                                    ),
                                  ),
                                ),
                      ),
                    ),
                  );
                },
              ),

        // ── Batch action bar ─────────────────
        bottomSheet: _selectionMode && _selected.isNotEmpty
            ? _BatchActionBar(
                selectedCount: _selected.length,
                onMove: () => _showMoveSheet(context, repo, plants),
                onArchive: () => _confirmArchive(context, repo, plants),
                onDelete: () => _confirmDelete(context, repo, plants),
                onExport: () => _exportSelected(context, repo, plants),
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Batch action bar
// ─────────────────────────────────────────────────────────────────────────────

class _BatchActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onMove;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _BatchActionBar({
    required this.selectedCount,
    required this.onMove,
    required this.onArchive,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.colSurface2,
        border: Border(top: BorderSide(color: context.colBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top row: Move (full width) ───────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Move to Space'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              onPressed: onMove,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // ── Middle row: Export PDF (full width) ───
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Export PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.harvested,
                side: const BorderSide(color: AppColors.harvested),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              onPressed: onExport,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // ── Bottom row: Archive | Delete ─────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.archive_rounded, size: 16),
                  label: const Text('Archive'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: onArchive,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    elevation: 0,
                  ),
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phenotype tag chip — shown inline in list tiles
// ─────────────────────────────────────────────────────────────────────────────

class _PhenoChip extends StatelessWidget {
  final String tag;
  const _PhenoChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.training.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.training.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.biotech_rounded,
              size: 10, color: AppColors.training),
          const SizedBox(width: 3),
          Text(
            tag,
            style: AppTypography.labelSmall(context).copyWith(
              color: AppColors.training,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
