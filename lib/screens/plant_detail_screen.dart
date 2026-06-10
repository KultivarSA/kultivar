import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/strain_library.dart';
import '../main.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../models/strain.dart';
import '../repository/grow_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../utils/image_cache_size.dart';
import '../utils/photo_path_resolver.dart';
import '../utils/plant_timeline_builder.dart';
import '../utils/pot_label.dart';
import '../utils/stage_duration_analytics.dart';
import '../widgets/app_sheet.dart';
import '../widgets/bulk_clone_sheet.dart';
import '../widgets/burping_reminder_card.dart';
import '../widgets/community_benchmark_card.dart';
import '../widgets/completion_celebration_overlay.dart';
import '../widgets/cull_plant_dialog.dart';
import '../widgets/cull_undo_overlay.dart';
import '../widgets/grow_stage_stepper.dart';
import '../widgets/harvest_celebration_overlay.dart';
import '../widgets/health_score_card.dart';
import '../widgets/lazy_section.dart';
import '../widgets/move_plant_dialog.dart';
import '../widgets/note_template_sheet.dart';
import '../widgets/outdoor_weather_card.dart';
// Q1a — private widgets relocated to lib/widgets/plant_detail/.
import '../widgets/plant_detail/care_schedule_card.dart';
import '../widgets/plant_detail/note_category_filter_bar.dart';
import '../widgets/plant_detail/nutrient_guide_button.dart';
import '../widgets/plant_detail/plant_expense_section.dart';
import '../widgets/plant_detail/rootbound_banner.dart';
// Q7 — extracted bottom-sheet flows for the three editor surfaces.
import '../widgets/plant_detail/sheets/add_note_sheet.dart';
import '../widgets/plant_detail/sheets/edit_note_sheet.dart';
import '../widgets/plant_detail/sheets/edit_plant_sheet.dart';
import '../widgets/plant_environment_card.dart';
import '../widgets/plant_height_chart.dart';
import '../widgets/plant_lifecycle_stepper.dart';
import '../widgets/plant_nutrient_chart.dart';
import '../widgets/plant_timeline.dart';
import '../widgets/plant_yield_insights.dart';
import '../widgets/skeleton.dart';
import '../widgets/training_section.dart';
import '../widgets/undo_overlay.dart';
import '../widgets/voice_note_attachment.dart';
import '../workflows/plant_workflow_service.dart';
import 'grow_session_report_screen.dart';
import 'photo_timeline_screen.dart';
import 'strain_compare_screen.dart';

class PlantDetailScreen extends StatefulWidget {
  final Plant plant;

  /// Optional ordered list of sibling plants (e.g. all plants in the same
  /// space). When provided, prev/next navigation appears at the top of the
  /// screen so the user can swipe through plants without going back first.
  final List<Plant>? siblings;

  const PlantDetailScreen({
    super.key,
    required this.plant,
    this.siblings,
  });

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  PlantWorkflowService? _workflow;

  // Index into widget.siblings — only meaningful when siblings is non-null.
  int _currentIndex = 0;

  // null = show all categories
  NoteCategory? _noteFilter;

  @override
  void initState() {
    super.initState();
    if (widget.siblings != null) {
      final idx =
          widget.siblings!.indexWhere((p) => p.id == widget.plant.id);
      _currentIndex = idx >= 0 ? idx : 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only create the service once — it is stateless and does not need to be
    // recreated on subsequent didChangeDependencies calls (e.g. theme changes).
    _workflow ??= PlantWorkflowService(
      context.read<GrowRepository>(),
      NotificationService(),
    );
  }

  PlantWorkflowService get workflow => _workflow!;

  // Category colour/icon are provided by NoteCategoryExt in plant_note.dart.
  // Use cat.color and cat.icon directly instead of local helpers.


  /// Delegates to [potLabel] in `lib/utils/pot_label.dart`.  Kept as a
  /// static shim so the existing `_potLabel(...)` call sites inside
  /// this screen state don't need rewriting.
  static String _potLabel(double litres) => potLabel(litres);
  // ── Harvest dialog ────────────────────────────

  void _showHarvestDialog(
    BuildContext context,
    Plant plant,
  ) {
    final ctrl = TextEditingController();
    DateTime harvestDate = DateTime.now();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AppSheet(
          title: 'Harvest Plant',
          subtitle: plant.name,
          icon: Icons.agriculture_rounded,
          iconColor: AppColors.harvested,
          children: [
            // Wet weight — optional.  Some growers only weigh post-dry,
            // so allowing this to stay blank is a real workflow need.
            // The dialog still accepts a number when supplied, and the
            // validator rejects negative / zero values so an
            // accidental "0" entry doesn't slip through as data.
                Text('WET WEIGHT  ·  OPTIONAL',
                    style: AppTypography.labelSmall(context).copyWith(
                        color: context.colTextMuted, letterSpacing: 0.8)),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.colTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Wet weight (g) — leave blank to skip',
                    helperText: 'Skip if you only weigh post-dry',
                    prefixIcon: Icon(Icons.scale_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Harvest date
                Text('HARVEST DATE',
                    style: AppTypography.labelSmall(context).copyWith(
                        color: context.colTextMuted, letterSpacing: 0.8)),
                const SizedBox(height: AppSpacing.xs),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: harvestDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) ss(() => harvestDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: context.colSurface3,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                          color: AppColors.harvested.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          harvestDate.toLocal().toString().split(' ')[0],
                          style: AppTypography.bodyMedium(context)
                              .copyWith(color: AppColors.harvested),
                        ),
                        const Icon(Icons.calendar_today,
                            color: AppColors.harvested, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.agriculture_rounded, size: 18),
                    label: const Text('Harvest Plant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.harvested,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () {
                      // Empty input → save with no wet weight (user
                      // will weigh post-dry).  Non-empty + invalid
                      // (negative, zero, non-numeric) blocks the save
                      // so we don't write nonsense.
                      final raw = ctrl.text.trim();
                      double? v;
                      if (raw.isNotEmpty) {
                        final parsed = double.tryParse(raw);
                        if (parsed == null || parsed <= 0) return;
                        v = parsed;
                      }
                      final growDays =
                          harvestDate.difference(plant.startDate).inDays;
                      workflow.harvestPlant(
                        plant: plant,
                        wetWeight: v,
                        harvestedDate: harvestDate,
                      );
                      Navigator.pop(ctx);
                      HarvestCelebrationOverlay.show(
                        context,
                        plantName: plant.name,
                        strain: plant.strain,
                        wetWeightG: v,
                        growDays: growDays,
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: AppTypography.labelLarge(context)
                            .copyWith(color: context.colTextSecondary)),
                  ),
                ),
          ],
        ),
      ),
    ).then((_) => ctrl.dispose());
  }

  // ── Start drying dialog ───────────────────────

  void _showStartDryingDialog(BuildContext context, Plant plant) {
    DateTime dryingEnd = DateTime.now().add(const Duration(days: 10));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AppSheet(
          title: 'Start Drying',
          subtitle: plant.name,
          icon: Icons.air_rounded,
          iconColor: AppColors.drying,
          children: [
            // Estimated end date
                Text('ESTIMATED DRY DATE',
                    style: AppTypography.labelSmall(context).copyWith(
                        color: context.colTextMuted, letterSpacing: 0.8)),
                const SizedBox(height: AppSpacing.xs),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dryingEnd,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) ss(() => dryingEnd = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: context.colSurface3,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                          color: AppColors.drying.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dryingEnd.toLocal().toString().split(' ')[0],
                          style: AppTypography.bodyMedium(context)
                              .copyWith(color: AppColors.drying),
                        ),
                        const Icon(Icons.calendar_today,
                            color: AppColors.drying, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.air_rounded, size: 18),
                    label: const Text('Start Drying'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.drying,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () {
                      workflow.startDrying(
                          plant: plant, dryingEndDate: dryingEnd);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: AppTypography.labelLarge(context)
                            .copyWith(color: context.colTextSecondary)),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ── Dry weight + drying date dialog ──────────

  void _showDryWeightDialog(
    BuildContext context,
    Plant plant,
  ) {
    final ctrl = TextEditingController();
    DateTime? pickedDryingEnd;
    bool burpingEnabled = plant.burpingRemindersEnabled;
    String burpingSchedule = plant.burpingSchedule;
    TimeOfDay burpingTime =
        plant.burpingTime ?? const TimeOfDay(hour: 9, minute: 0);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AppSheet(
          title: 'Complete Drying',
          subtitle: plant.name,
          icon: Icons.inventory_2_rounded,
          iconColor: AppColors.curing,
          children: [
            // Dry weight
                Text('DRY WEIGHT',
                    style: AppTypography.labelSmall(context).copyWith(
                        color: context.colTextMuted, letterSpacing: 0.8)),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.colTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Dry weight (g)',
                    prefixIcon: Icon(Icons.scale_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Drying end date
                Text('DRYING END DATE (OPTIONAL)',
                    style: AppTypography.labelSmall(context).copyWith(
                        color: context.colTextMuted, letterSpacing: 0.8)),
                const SizedBox(height: AppSpacing.xs),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.now().add(const Duration(days: 10)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) ss(() => pickedDryingEnd = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: context.colSurface3,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                          color: pickedDryingEnd != null
                              ? AppColors.curing.withValues(alpha: 0.4)
                              : context.colBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pickedDryingEnd != null
                              ? pickedDryingEnd!
                                  .toLocal()
                                  .toString()
                                  .split(' ')[0]
                              : 'Set end date (optional)',
                          style: AppTypography.bodyMedium(context).copyWith(
                              color: pickedDryingEnd != null
                                  ? AppColors.curing
                                  : context.colTextMuted),
                        ),
                        Icon(Icons.calendar_today,
                            color: pickedDryingEnd != null
                                ? AppColors.curing
                                : context.colTextMuted,
                            size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Burping reminder card
                BurpingReminderCard(
                  plant: plant.copyWith(
                    burpingRemindersEnabled: burpingEnabled,
                    burpingSchedule: burpingSchedule,
                    burpingTime: burpingTime,
                  ),
                  onChanged: ({
                    required enabled,
                    required schedule,
                    required time,
                  }) {
                    ss(() {
                      burpingEnabled = enabled;
                      burpingSchedule = schedule;
                      burpingTime = time;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                // Action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.inventory_2_rounded, size: 18),
                    label: const Text('Start Curing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.curing,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () {
                      final v = double.tryParse(ctrl.text);
                      if (v == null || v <= 0) return;
                      workflow.completeDrying(
                        plant: plant,
                        dryWeight: v,
                        dryingEndDate: pickedDryingEnd,
                        enableBurpingReminders: burpingEnabled,
                        burpingSchedule: burpingSchedule,
                        burpingTime: burpingTime,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: AppTypography.labelLarge(context)
                            .copyWith(color: context.colTextSecondary)),
                  ),
                ),
          ],
        ),
      ),
    ).then((_) => ctrl.dispose());
  }

  // ── Counter card ──────────────────────────────

  Widget _counter({
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(value,
              style:
                  AppTypography.headlineLarge(context).copyWith(color: color)),
          const SizedBox(height: AppSpacing.xxs),
          Text(label,
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall(context)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall(context).copyWith(
                color: context.colTextMuted,
                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Note detail rows ──────────────────────────

  Widget _noteDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Text('$label: ',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted)),
          Text(value,
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextSecondary)),
        ],
      ),
    );
  }
  // ── Strain comparison ─────────────────────────

  Future<void> _compareStrains(
      BuildContext context, GrowRepository repo, Plant plant) async {
    // Build strainA — prefer full catalog data, then saved library strain,
    // then a minimal stub so the compare screen always has something to show.
    final catalogA = kStrainLibrary
        .where((s) => s.name.toLowerCase() == plant.strain.toLowerCase())
        .firstOrNull;

    final Strain strainA;
    if (catalogA != null) {
      strainA = strainFromBuiltIn(catalogA);
    } else if (plant.strainId != null) {
      final saved = repo.strainById(plant.strainId!);
      strainA = saved ??
          Strain(
            id: 'plant:${plant.id}',
            name: plant.strain,
            genetics: '',
            type: 'Hybrid',
            createdAt: plant.startDate,
          );
    } else {
      strainA = Strain(
        id: 'plant:${plant.id}',
        name: plant.strain,
        genetics: '',
        type: 'Hybrid',
        createdAt: plant.startDate,
      );
    }

    final picked = await StrainPickerSheet.show(
      context,
      excludeName: plant.strain,
    );
    if (picked == null || !context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StrainCompareScreen(
          strainA: strainA,
          strainB: strainFromBuiltIn(picked),
        ),
      ),
    );
  }

  // ── Grow stage change ─────────────────────────

  void _onGrowStageChanged(
    GrowRepository repo,
    Plant plant,
    GrowStage stage,
  ) {
    final isFlipStage =
        stage == GrowStage.stretch || stage == GrowStage.earlyFlower;
    final recordFlip =
        isFlipStage && !plant.isAutoflower && plant.flipDate == null;

    repo.updatePlant(recordFlip
        ? plant.copyWith(growStage: stage, flipDate: DateTime.now())
        : plant.copyWith(growStage: stage));

    repo.addNote(PlantNote(
      id: repo.newId(),
      plantId: plant.id,
      createdAt: DateTime.now(),
      category: NoteCategory.milestone,
      content: recordFlip
          ? 'Growth stage: ${stage.label} — 12/12 flip recorded'
          : 'Growth stage: ${stage.label}',
    ));
  }

  // ── Sibling navigation row ────────────────────

  Widget _siblingNavRow(int total) {
    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < total - 1;

    final prevName = hasPrev
        ? widget.siblings![_currentIndex - 1].name
        : null;
    final nextName = hasNext
        ? widget.siblings![_currentIndex + 1].name
        : null;

    return Container(
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.colBorderFaint),
      ),
      child: Row(
        children: [
          // ← Previous
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppSpacing.radiusMd)),
              onTap: hasPrev
                  ? () => setState(() => _currentIndex--)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.chevron_left,
                        size: 18,
                        color: hasPrev
                            ? AppColors.primary
                            : context.colTextMuted),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        prevName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall(context).copyWith(
                          color: hasPrev
                              ? context.colTextSecondary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Position indicator
          Text(
            '${_currentIndex + 1} / $total',
            style: AppTypography.labelSmall(context)
                .copyWith(color: context.colTextMuted),
          ),

          // Next →
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(AppSpacing.radiusMd)),
              onTap: hasNext
                  ? () => setState(() => _currentIndex++)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        nextName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppTypography.bodySmall(context).copyWith(
                          color: hasNext
                              ? context.colTextSecondary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Icon(Icons.chevron_right,
                        size: 18,
                        color: hasNext
                            ? AppColors.primary
                            : context.colTextMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ── Quick stat chip ───────────────────────────

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(label,
              style: AppTypography.labelSmall(context).copyWith(color: color)),
        ],
      ),
    );
  }

// ── Photo journal tile ────────────────────────

  Widget _photoJournalTile(
    BuildContext context,
    Plant plant,
    List<PlantNote> notes,
    int photoCount,
  ) {
    // Notes that carry at least one photo, sorted oldest → newest.
    final photoNotes = notes
        .where((n) => n.photoUrls.isNotEmpty)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoTimelineScreen(
            plant: plant,
            notes: notes,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.colBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.photo_library_rounded,
                      color: context.colTextSecondary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Photo Journal',
                      style: AppTypography.labelLarge(context)),
                  const Spacer(),
                  Text(
                    photoCount == 0
                        ? 'No photos yet'
                        : '$photoCount '
                            '${photoCount == 1 ? 'photo' : 'photos'}',
                    style: AppTypography.bodySmall(context),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.chevron_right,
                      color: context.colTextMuted, size: 16),
                ],
              ),
            ),

            // ── Thumbnail strip ──────────────────
            //
            // Bug fix (real-device finding on S22): the strip was
            // 88 px tall -- enough for 60 (image) + 2 + ~14 (date
            // label at fontSize:9) at the default text scale.  But
            // Samsung's "Large fonts" accessibility setting (and
            // many users' default One UI text size > 1.0) scales
            // the label up, pushing total content past 88 and
            // triggering a horizontal overflow stripe under the
            // images.  Bump to 102 to absorb up to a 1.4x text
            // scale, and cap the date label at one line.
            if (photoNotes.isNotEmpty) ...[
              Divider(height: 1, color: context.colBorder),
              SizedBox(
                height: 102,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  itemCount: photoNotes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (ctx, idx) {
                    final note = photoNotes[idx];
                    final path =
                        PhotoPathResolver.resolve(note.photoUrls.first);
                    return _photoThumb(ctx, path, note.createdAt);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Single photo thumbnail ─────────────────────

  Widget _photoThumb(BuildContext context, String path, DateTime date) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Image.file(
            File(path),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            // P1.4 — cap decode at 60 × DPR so a 4032 × 3024 source
            // doesn't get held in memory just to fill a 60 px tile.
            cacheWidth: imageCacheWidth(context, 60),
            // A9 — screen-reader label.  Plant photos lack alt-text
            // metadata in the model, so we synthesise from the note's
            // date: TalkBack/VoiceOver announces "Plant photo from
            // 04/06" instead of the default "image".
            semanticLabel: 'Plant photo from ${fmtShortDate(date)}',
            // A6 — shimmer skeleton during async decode.
            // `frameBuilder` fires synchronously: `frame == null`
            // means decode hasn't produced its first frame yet.
            frameBuilder: (_, child, frame, __) {
              if (frame != null) return child;
              return const SkeletonImage(width: 60, height: 60);
            },
            errorBuilder: (_, __, ___) => Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: context.colSurface3,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(Icons.broken_image_rounded,
                  size: 22, color: context.colTextMuted),
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Bug fix: clamp to 1 line + ellipsis so a large textScaler
        // can't force the date label to wrap onto a second line
        // (which was a secondary contributor to the strip overflow).
        Text(
          fmtShortDate(date),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall(context).copyWith(
            fontSize: 9,
            color: context.colTextMuted,
          ),
        ),
      ],
    );
  }

// ── Note delete with undo ─────────────────────

  void _deleteNoteWithUndo(
    BuildContext context,
    GrowRepository repo,
    PlantNote note,
  ) {
    // Capture the full note before deletion so we can restore it.
    repo.deleteNote(note.id);
    UndoOverlay.show(
      context,
      icon: Icons.edit_note_rounded,
      color: AppColors.warning,
      title: 'Note Deleted',
      subtitle: 'The note has been permanently\nremoved from this plant.',
      onUndo: () => repo.readdNote(note),
    );
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();

    // When siblings are provided, derive the live plant from the current index
    // so prev/next navigation always shows up-to-date repo data.
    final baseId = widget.siblings != null
        ? widget.siblings![_currentIndex].id
        : widget.plant.id;
    final baseFallback =
        widget.siblings?[_currentIndex] ?? widget.plant;

    final currentPlant = repo.plants.firstWhere(
      (p) => p.id == baseId,
      orElse: () => baseFallback,
    );

    final notes = repo.notesForPlant(currentPlant.id);
    final filteredNotes = _noteFilter == null
        ? notes
        : notes.where((n) => n.category == _noteFilter).toList();

    DateTime? latest(NoteCategory cat) => notes
        .where((n) => n.category == cat)
        .map((n) => n.createdAt)
        .fold<DateTime?>(
            null, (best, d) => best == null || d.isAfter(best) ? d : best);

    final lastWatered = latest(NoteCategory.watering);
    final lastFed = latest(NoteCategory.feeding);
    final lastTrained = latest(NoteCategory.training);
    final latestHeightNote = notes
        .where((n) => n.heightCm != null)
        .fold<PlantNote?>(
            null,
            (best, n) =>
                best == null || n.createdAt.isAfter(best.createdAt) ? n : best);
    final daysInFlower = currentPlant.flipDate != null
        ? DateTime.now().difference(currentPlant.flipDate!).inDays
        : null;

    final photoCount =
        notes.fold<int>(0, (sum, n) => sum + n.photoUrls.length);
    final strainModel = repo.strainById(currentPlant.strainId);

    final spaceEnvLogs = repo.environmentLogs
        .where((l) => l.growSpaceId == currentPlant.growSpaceId)
        .toList();

    final timelineEvents = buildPlantTimeline(
      plant: currentPlant,
      notes: notes,
    );

    final statusColor = AppColors.statusColor(currentPlant.status.name);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentPlant.name,
            style: AppTypography.headlineMedium(context)),
        actions: [
          // ✅ Edit plant
          IconButton(
            icon: Icon(Icons.edit_rounded,
                color: context.colTextSecondary, size: 20),
            tooltip: 'Edit Plant',
            onPressed: () => EditPlantSheet.show(
              context,
              repo: repo,
              plant: currentPlant,
            ),
          ),
          // Add note
          if (!currentPlant.isArchived)
            IconButton(
              icon: const Icon(Icons.note_add, color: AppColors.growing),
              tooltip: 'Add Note',
              onPressed: () => AddNoteSheet.show(
                context,
                repo: repo,
                plant: currentPlant,
              ),
            ),
          // F4 — Take clones (only meaningful while the plant is alive
          // and still in a vegetative or early-flower phase where cuttings
          // are viable).  We surface the action for any non-archived plant
          // and let the user decide; a stricter gate would be premature.
          if (!currentPlant.isArchived &&
              currentPlant.status == PlantStatus.growing)
            IconButton(
              icon: const Icon(Icons.content_cut_rounded,
                  color: AppColors.training),
              tooltip: 'Take Clones',
              onPressed: () =>
                  BulkCloneSheet.show(context, mother: currentPlant),
            ),
          // Grow report — archived plants only
          if (currentPlant.isArchived)
            IconButton(
              icon: const Icon(Icons.emoji_events_rounded,
                  color: AppColors.harvested),
              tooltip: 'Grow Report',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GrowSessionReportScreen(plant: currentPlant),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sibling navigation ──────────────
            if (widget.siblings != null && widget.siblings!.length > 1) ...[
              _siblingNavRow(widget.siblings!.length),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ── Header ─────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentPlant.name,
                          style: AppTypography.displayMedium(context)),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        strainModel?.name ?? currentPlant.strain,
                        style: AppTypography.bodyLarge(context).copyWith(
                          fontWeight: strainModel != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: strainModel != null
                              ? AppColors.primary
                              : context.colTextSecondary,
                        ),
                      ),
                      if (strainModel != null) ...[
                        Text(
                          '${strainModel.type} · '
                          '${strainModel.flowerTimeLabel}',
                          style: AppTypography.bodySmall(context),
                        ),
                      ],
                      // Compare strains chip
                      if (currentPlant.strain.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Ink(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
                            border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.3)),
                          ),
                          child: InkWell(
                            onTap: () =>
                                _compareStrains(context, repo, currentPlant),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.compare_arrows_rounded,
                                      size: 11, color: AppColors.primary),
                                  const SizedBox(width: AppSpacing.xxs),
                                  Text(
                                    'Compare strains',
                                    style: AppTypography.labelSmall(context)
                                        .copyWith(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Phenotype tag chip
                      if (currentPlant.phenotypeTag != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Ink(
                          decoration: BoxDecoration(
                            color:
                                AppColors.training.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
                            border: Border.all(
                                color: AppColors.training
                                    .withValues(alpha: 0.4)),
                          ),
                          child: InkWell(
                            onTap: () => EditPlantSheet.show(
                                context,
                                repo: repo,
                                plant: currentPlant),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.biotech_rounded,
                                      size: 11, color: AppColors.training),
                                  const SizedBox(width: AppSpacing.xxs),
                                  Text(
                                    currentPlant.phenotypeTag!,
                                    style: AppTypography.labelSmall(context)
                                        .copyWith(
                                      color: AppColors.training,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Clone / seed badge
                      const SizedBox(height: AppSpacing.xxs),
                      Tooltip(
                        message: currentPlant.isClone
                            ? 'Propagated from a cutting — shares the mother plant\'s genetics.'
                            : 'Started from seed — has its own genetic expression.',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: currentPlant.isClone
                                ? AppColors.secondary.withValues(alpha: 0.15)
                                : AppColors.growing.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                            border: Border.all(
                                color: currentPlant.isClone
                                    ? AppColors.secondary.withValues(alpha: 0.4)
                                    : AppColors.growing.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            currentPlant.isClone ? '🌿 Clone' : '🌱 From Seed',
                            style: AppTypography.labelSmall(context).copyWith(
                                color: currentPlant.isClone
                                    ? AppColors.secondary
                                    : AppColors.growing),
                          ),
                        ),
                      ),
                      // Lineage: Cloned from
                      if (currentPlant.isClone &&
                          currentPlant.motherPlantId != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Builder(builder: (context) {
                          final motherPlant = repo.plants.where(
                              (p) => p.id == currentPlant.motherPlantId).firstOrNull;
                          if (motherPlant == null) return const SizedBox.shrink();
                          return Ink(
                            decoration: BoxDecoration(
                              color: AppColors.secondary
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull),
                              border: Border.all(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.3)),
                            ),
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlantDetailScreen(plant: motherPlant),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.account_tree_rounded,
                                        size: 11,
                                        color: AppColors.secondary),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Text(
                                      'From: ${motherPlant.name}',
                                      style: AppTypography.labelSmall(context)
                                          .copyWith(
                                        color: AppColors.secondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.open_in_new_rounded,
                                        size: 10,
                                        color: AppColors.secondary),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                      // Show clone count if this plant is a mother
                      Builder(builder: (context) {
                        final cloneCount = repo.plants
                            .where((p) =>
                                p.motherPlantId == currentPlant.id &&
                                p.id != currentPlant.id)
                            .length;
                        if (cloneCount == 0) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.xxs),
                            Tooltip(
                              message:
                                  'This plant is a mother — $cloneCount '
                                  '${cloneCount == 1 ? 'cutting has' : 'cuttings have'} been taken '
                                  'and tracked as separate plants.',
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.growing
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusFull),
                                  border: Border.all(
                                      color: AppColors.growing
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.content_copy_rounded,
                                        size: 11,
                                        color: AppColors.growing),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Text(
                                      '$cloneCount clone${cloneCount == 1 ? '' : 's'} taken',
                                      style: AppTypography.labelSmall(context)
                                          .copyWith(
                                        color: AppColors.growing,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    currentPlant.statusLabel.toUpperCase(),
                    style: AppTypography.labelLarge(context)
                        .copyWith(color: statusColor),
                  ),
                ),
              ],
            ),

            // Target harvest countdown
            if (currentPlant.daysUntilTargetHarvest != null &&
                currentPlant.status == PlantStatus.growing) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.harvested.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                      color: AppColors.harvested.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer,
                        color: AppColors.harvested, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      currentPlant.daysUntilTargetHarvest! > 0
                          ? '${currentPlant.daysUntilTargetHarvest} days to target harvest'
                          : 'Target harvest date reached',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: AppColors.harvested),
                    ),
                  ],
                ),
              ),
            ],

            if (currentPlant.status == PlantStatus.removed) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'This plant was removed.',
                  style: AppTypography.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.w600, color: AppColors.danger),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            PlantLifecycleStepper(plant: currentPlant),
            if (currentPlant.status == PlantStatus.growing) ...[
              if (daysInFlower != null ||
                  lastWatered != null ||
                  lastFed != null ||
                  lastTrained != null ||
                  latestHeightNote != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (daysInFlower != null)
                      _statChip(Icons.wb_sunny_rounded,
                          'Day $daysInFlower of flower', AppColors.drying),
                    if (lastWatered != null)
                      _statChip(
                          Icons.water_drop_rounded,
                          'Watered ${DateTime.now().difference(lastWatered).inDays}d ago',
                          AppColors.water),
                    if (lastFed != null)
                      _statChip(
                          Icons.restaurant_rounded,
                          'Fed ${DateTime.now().difference(lastFed).inDays}d ago',
                          AppColors.curing),
                    if (lastTrained != null)
                      _statChip(
                          Icons.content_cut_rounded,
                          'Trained ${DateTime.now().difference(lastTrained).inDays}d ago',
                          AppColors.training),
                    if (latestHeightNote != null)
                      _statChip(
                          Icons.straighten_rounded,
                          '${latestHeightNote.heightCm!.toStringAsFixed(1)} cm tall',
                          AppColors.secondary),
                    if (currentPlant.potSizeLitres != null)
                      _statChip(
                          Icons.yard_rounded,
                          _potLabel(currentPlant.potSizeLitres!),
                          AppColors.growing),
                  ],
                ),
              ],
              // ── Expense summary ──────────────────────────────────────
              PlantExpenseSection(plant: currentPlant),
              const SizedBox(height: AppSpacing.sm),

              // ── Outdoor weather (only for outdoor plants) ─────────────
              if (currentPlant.lightType == 'outdoor') ...[
                OutdoorWeatherCard(plant: currentPlant),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Rootbound warning
              if (currentPlant.potSizeLitres != null) ...[
                const SizedBox(height: AppSpacing.sm),
                RootboundBanner(
                  plant: currentPlant,
                  notes: notes,
                  onLogTransplant: () => AddNoteSheet.show(
                    context,
                    repo: repo,
                    plant: currentPlant,
                    prefillCategory: NoteCategory.transplant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              GrowStageStepper(
                plant: currentPlant,
                onStageChanged: (stage) => _onGrowStageChanged(
                  repo,
                  currentPlant,
                  stage,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              CareScheduleCard(
                plant: currentPlant,
                repo: repo,
              ),
              const SizedBox(height: AppSpacing.md),
              TrainingSection(
                plant: currentPlant,
                allNotes: notes,
              ),
            ],

            // ── Photo journal ─────────────────────────────────────────
            //
            // Task #177 — deliberately OUTSIDE the growing-only block
            // above.  The journal used to vanish the moment a plant was
            // harvested, which is exactly when reviewing the grow's
            // photo history becomes most valuable (compare runs, decide
            // what to repeat).  Rendering unconditionally keeps it
            // available through drying / curing / completed / removed,
            // and -- because the Harvest Archive opens this same screen
            // for archived plants -- in the archive too.
            const SizedBox(height: AppSpacing.sm),
            _photoJournalTile(context, currentPlant, notes, photoCount),
            const SizedBox(height: AppSpacing.md),

            // ── F12 — deferred heavy sections ────────────────────────
            //
            // Everything below uses `LazySection`: collapsed by default,
            // child built on first expand, kept alive after that.  This
            // moves the per-build cost from ~always to opt-in, which
            // matters a lot here:
            //   * `CommunityBenchmarkCard` fires network requests.
            //   * `PlantEnvironmentCard` / `PlantNutrientChart` /
            //     `PlantHeightChart` build fl_chart layouts that walk
            //     every note + env-log point.
            //   * `HealthScoreCard` aggregates across multiple lists.
            //   * `PlantYieldInsights` runs projection maths.
            // Power growers can still get all of it — just one tap each.
            LazySection(
              icon: Icons.insights_rounded,
              iconColor: AppColors.harvested,
              title: 'Yield insights',
              subtitle: 'Projection + dry-weight maths',
              builder: (_) => PlantYieldInsights(plant: currentPlant),
            ),
            LazySection(
              icon: Icons.people_alt_rounded,
              iconColor: AppColors.secondary,
              title: 'Community benchmark',
              subtitle: 'Compare to anonymous community yields',
              builder: (_) => CommunityBenchmarkCard(
                plant: currentPlant,
                harvestLog: repo.harvestLogs
                    .where((l) => l.plantId == currentPlant.id)
                    .firstOrNull,
                notes: notes,
              ),
            ),
            LazySection(
              icon: Icons.health_and_safety_rounded,
              iconColor: AppColors.growing,
              title: 'Health score',
              subtitle: 'Issues, environment & care frequency',
              builder: (_) => HealthScoreCard(
                plant: currentPlant,
                spaceEnvironmentLogs: spaceEnvLogs,
                plantNotes: notes,
              ),
            ),
            LazySection(
              icon: Icons.thermostat_rounded,
              iconColor: AppColors.drying,
              title: 'Environment',
              subtitle: 'Temp / humidity / VPD over time',
              builder: (_) => PlantEnvironmentCard(
                plant: currentPlant,
                logs: spaceEnvLogs,
                space: repo.growSpaces
                    .where((s) => s.id == currentPlant.growSpaceId)
                    .firstOrNull,
                historicalDurations: computeHistoricalAverages(
                  repo.plants
                      .where((p) => p.id != currentPlant.id)
                      .toList(),
                ),
              ),
            ),
            LazySection(
              icon: Icons.science_rounded,
              iconColor: AppColors.curing,
              title: 'Nutrient & pH trends',
              subtitle: 'EC / pH / N-P-K from feeding logs',
              builder: (_) => PlantNutrientChart(notes: notes),
            ),
            LazySection(
              icon: Icons.straighten_rounded,
              iconColor: AppColors.training,
              title: 'Height tracker',
              subtitle: 'Growth curve from measurement notes',
              builder: (_) => PlantHeightChart(
                plant: currentPlant,
                notes: notes,
                strainModel: strainModel,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            NutrientGuideButton(
              growStage: currentPlant.growStage,
              medium: currentPlant.medium,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Day counters
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _counter(
                  label: 'Days\nGrowing',
                  value: currentPlant.daysGrowing.toString(),
                  color: AppColors.growing,
                ),
                if (currentPlant.status == PlantStatus.drying) ...[
                  _counter(
                    label: 'Days\nDrying',
                    value: currentPlant.daysDrying.toString(),
                    color: AppColors.drying,
                  ),
                  Builder(builder: (_) {
                    final now = DateTime.now();
                    final end = currentPlant.dryingEndDate;
                    final overdue = end != null && end.isBefore(now);
                    final days = overdue
                        ? now.difference(end).inDays
                        : currentPlant.dryingDaysRemaining;
                    return _counter(
                      label: overdue ? 'Overdue' : 'Left',
                      value: overdue ? '${days}d' : '$days',
                      color:
                          overdue ? AppColors.danger : AppColors.harvested,
                      subtitle: end != null
                          ? '${overdue ? 'since' : 'until'} ${fmtShortDate(end)}'
                          : null,
                    );
                  }),
                ],
                if (currentPlant.status == PlantStatus.curing) ...[
                  _counter(
                    label: 'Days\nCuring',
                    value: currentPlant.daysCuring.toString(),
                    color: AppColors.curing,
                  ),
                  Builder(builder: (_) {
                    final now = DateTime.now();
                    final end = currentPlant.curingEndDate;
                    final overdue = end != null && end.isBefore(now);
                    final days = overdue
                        ? now.difference(end).inDays
                        : currentPlant.curingDaysRemaining;
                    return _counter(
                      label: overdue ? 'Overdue' : 'Left',
                      value: overdue ? '${days}d' : '$days',
                      color: overdue ? AppColors.danger : AppColors.secondary,
                      subtitle: end != null
                          ? '${overdue ? 'since' : 'until'} ${fmtShortDate(end)}'
                          : null,
                    );
                  }),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            if (currentPlant.status == PlantStatus.harvested) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  '→ Next: Start Drying',
                  style: AppTypography.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.w600, color: AppColors.harvested),
                ),
              ),
            ],

            // Actions
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (currentPlant.status == PlantStatus.growing)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.agriculture, size: 16),
                    label: const Text('Harvest'),
                    onPressed: () =>
                        _showHarvestDialog(context, currentPlant),
                  ),
                if (currentPlant.status == PlantStatus.harvested)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.air, size: 16),
                    label: const Text('Start Drying'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.drying,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () =>
                        _showStartDryingDialog(context, currentPlant),
                  ),
                if (currentPlant.status == PlantStatus.drying)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.storage, size: 16),
                    label: const Text('Complete Drying'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.curing),
                    onPressed: () =>
                        _showDryWeightDialog(context, currentPlant),
                  ),
                if (currentPlant.status == PlantStatus.curing &&
                    !currentPlant.isArchived)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Complete Cure'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.growing,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      workflow.completeCure(currentPlant);
                      // Re-fetch from the repository: completeCure has
                      // already updated status, curingEndDate and timestamps
                      // in-place.  Passing the pre-cure snapshot would give
                      // the report screen a stale PlantStatus.curing object.
                      final updated = context
                          .read<GrowRepository>()
                          .plants
                          .firstWhere(
                            (p) => p.id == currentPlant.id,
                            orElse: () => currentPlant,
                          );
                      // Reassure the user that the plant isn't lost — it
                      // has moved to the Archive tab. Shown over the
                      // current screen before drilling into the report.
                      CompletionCelebrationOverlay.show(
                        context,
                        plantName: updated.name,
                        strain: updated.strain,
                        totalDays: DateTime.now()
                            .difference(updated.startDate)
                            .inDays,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              GrowSessionReportScreen(plant: updated),
                        ),
                      );
                    },
                  ),
                if (currentPlant.status == PlantStatus.completed) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.completed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                          color: AppColors.completed.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified,
                            color: AppColors.completed, size: 14),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Lifecycle Complete',
                            style: AppTypography.labelLarge(context)
                                .copyWith(color: AppColors.completed)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.emoji_events_rounded, size: 16),
                    label: const Text('View Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.harvested,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GrowSessionReportScreen(plant: currentPlant),
                      ),
                    ),
                  ),
                ],
                if (currentPlant.status == PlantStatus.removed)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.emoji_events_rounded, size: 16),
                    label: const Text('View Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colSurface2,
                      foregroundColor: context.colTextSecondary,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GrowSessionReportScreen(plant: currentPlant),
                      ),
                    ),
                  ),
                if (currentPlant.status != PlantStatus.completed &&
                    currentPlant.status != PlantStatus.removed) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Move'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colSurface2,
                      foregroundColor: context.colTextSecondary,
                    ),
                    onPressed: () =>
                        MovePlantDialog.show(context, plant: currentPlant),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.warning, size: 16),
                    label: const Text('Cull'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final plantSnapshot = currentPlant;
                      final repo = context.read<GrowRepository>();
                      final noteId = await CullPlantDialog.show(
                        context,
                        plant: plantSnapshot,
                      );
                      if (noteId != null && context.mounted) {
                        CullUndoOverlay.show(
                          context,
                          plantName: plantSnapshot.name,
                          onUndo: () =>
                              repo.undoArchivePlant(plantSnapshot, noteId),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),

            // Burping card when curing
            if (currentPlant.status == PlantStatus.curing &&
                !currentPlant.isArchived) ...[
              const SizedBox(height: AppSpacing.lg),
              BurpingReminderCard(
                plant: currentPlant,
                onChanged: ({
                  required enabled,
                  required schedule,
                  required time,
                }) {
                  repo.updatePlant(
                    currentPlant.copyWith(
                      burpingRemindersEnabled: enabled,
                      burpingSchedule: schedule,
                      burpingTime: time,
                    ),
                  );
                  // Always cancel first, then reschedule if enabled.
                  // This handles toggle-off, schedule change, and time change.
                  if (enabled && KultivarApp.notifBurpingEnabled.value) {
                    unawaited(NotificationService().scheduleBurpingReminders(
                      plantId: currentPlant.id,
                      plantName: currentPlant.name,
                      schedule: schedule,
                      preferredTime: time,
                    ));
                  } else {
                    unawaited(NotificationService()
                        .cancelBurpingReminders(currentPlant.id));
                  }
                },
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // Timeline — header now mirrors the Notes section
            // pattern below: leading Material glyph + headlineSmall
            // text, both in textSecondary.  `timeline_rounded` is the
            // literal Material icon for a chronological event series,
            // which is exactly what the PlantTimeline widget renders
            // — clearer signal than the previous "📅" emoji which
            // suggested a date picker.
            Row(
              children: [
                Icon(Icons.timeline_rounded,
                    color: context.colTextSecondary, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Text('Plant Timeline',
                    style: AppTypography.headlineSmall(context)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            PlantTimeline(
              events: timelineEvents,
              startDate: currentPlant.startDate,
            ),

            const SizedBox(height: AppSpacing.xl),

            // Notes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded,
                        color: context.colTextSecondary, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _noteFilter == null
                          ? 'Notes (${notes.length})'
                          : 'Notes (${filteredNotes.length}/${notes.length})',
                      style: AppTypography.headlineSmall(context),
                    ),
                  ],
                ),
                Row(children: [
                  TextButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: context.colSurface2,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppSpacing.radiusXl)),
                      ),
                      builder: (_) => NoteTemplateSheet(
                        onSelected: (template) {
                          AddNoteSheet.show(
                            context,
                            repo: repo,
                            plant: currentPlant,
                            prefillContent: template.content,
                            prefillCategory: NoteCategory.values.firstWhere(
                              (c) => c.name == template.category,
                              orElse: () => NoteCategory.observation,
                            ),
                          );
                        },
                      ),
                    ),
                    icon: Icon(Icons.content_paste,
                        size: 13, color: context.colTextMuted),
                    label: Text('Templates',
                        style: AppTypography.labelLarge(context)
                            .copyWith(color: context.colTextMuted)),
                  ),
                  TextButton.icon(
                    onPressed: () => AddNoteSheet.show(
                      context,
                      repo: repo,
                      plant: currentPlant,
                    ),
                    icon: const Icon(Icons.add,
                        size: 15, color: AppColors.primary),
                    label: Text('Add',
                        style: AppTypography.labelLarge(context)
                            .copyWith(color: AppColors.primary)),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Note category filter chips ────────
            if (notes.isNotEmpty) ...[
              NoteCategoryFilterBar(
                notes: notes,
                selected: _noteFilter,
                onSelected: (cat) =>
                    setState(() => _noteFilter = _noteFilter == cat ? null : cat),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            if (notes.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.colSurface1,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: context.colBorder),
                ),
                child: Row(children: [
                  Icon(Icons.note, color: context.colTextMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Text('No notes — tap Add to start',
                      style: AppTypography.bodyMedium(context)
                          .copyWith(fontStyle: FontStyle.italic)),
                ]),
              )
            else if (filteredNotes.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.colSurface1,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: context.colBorder),
                ),
                child: Row(children: [
                  Icon(Icons.filter_list_off_rounded,
                      color: context.colTextMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'No ${_noteFilter?.categoryLabel ?? ''} notes yet',
                    style: AppTypography.bodyMedium(context)
                        .copyWith(fontStyle: FontStyle.italic),
                  ),
                ]),
              )
            else
              ...filteredNotes.map((note) {
                final color = note.category.color;
                final icon = note.category.icon;
                return Dismissible(
                  key: ValueKey(note.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child:
                        const Icon(Icons.delete_outline, color: AppColors.danger),
                  ),
                  onDismissed: (_) => _deleteNoteWithUndo(context, repo, note),
                  child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colSurface1,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Icon(icon, color: color, size: 13),
                            const SizedBox(width: 5),
                            Text(note.categoryLabel,
                                style: AppTypography.labelSmall(context)
                                    .copyWith(color: color)),
                            if (note.issueName != null) ...[
                              const SizedBox(width: AppSpacing.xxs),
                              Text('· ${note.issueName}',
                                  style: AppTypography.labelSmall(context)
                                      .copyWith(color: color)),
                            ],
                          ]),
                          Row(children: [
                            Text(
                              formatDateTime(note.createdAt),
                              style: AppTypography.bodySmall(context),
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            // ✅ Resolve button for issue notes
                            if (note.category == NoteCategory.issue &&
                                !note.isResolved)
                              GestureDetector(
                                onTap: () => repo.resolveNote(note.id),
                                child: Tooltip(
                                  message: 'Mark as resolved',
                                  child: Container(
                                    margin: const EdgeInsets.only(right: AppSpacing.xxs),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.growing
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusFull),
                                      border: Border.all(
                                          color: AppColors.growing
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check,
                                            color: AppColors.growing, size: 11),
                                        const SizedBox(width: 3),
                                        Text('Resolve',
                                            style: AppTypography.labelSmall(
                                                    context)
                                                .copyWith(
                                                    fontSize: 10,
                                                    color: AppColors.growing)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (note.category == NoteCategory.issue &&
                                note.isResolved)
                              Container(
                                margin: const EdgeInsets.only(right: AppSpacing.xxs),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.colTextMuted
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusFull),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: context.colTextMuted, size: 11),
                                    const SizedBox(width: 3),
                                    Text('Resolved',
                                        style: AppTypography.labelSmall(context)
                                            .copyWith(fontSize: 10)),
                                  ],
                                ),
                              ),
                            GestureDetector(
                              onTap: () =>
                                  EditNoteSheet.show(
                                    context,
                                    repo: repo,
                                    note: note,
                                  ),
                              child: Icon(Icons.edit_outlined,
                                  size: 13, color: context.colTextMuted),
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            GestureDetector(
                              onTap: () =>
                                  _deleteNoteWithUndo(context, repo, note),
                              child: Icon(Icons.close,
                                  size: 13, color: context.colTextMuted),
                            ),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(note.content,
                          style: AppTypography.bodyLarge(context)),

                      // Structured detail rows
                      if (note.feedingDetails != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _noteDetailRow(
                            'Product', note.feedingDetails!.productName),
                        _noteDetailRow(
                            'Volume',
                            note.feedingDetails!.waterVolumeLitres != null
                                ? '${note.feedingDetails!.waterVolumeLitres}L'
                                : null),
                        _noteDetailRow(
                            'pH',
                            note.feedingDetails!.phIn != null
                                ? '${note.feedingDetails!.phIn}'
                                : null),
                        _noteDetailRow(
                            'EC',
                            note.feedingDetails!.ecIn != null
                                ? '${note.feedingDetails!.ecIn}'
                                : null),
                        if (note.feedingDetails!.nitrogen != null ||
                            note.feedingDetails!.phosphorus != null ||
                            note.feedingDetails!.potassium != null)
                          _noteDetailRow(
                              'NPK',
                              'N${note.feedingDetails!.nitrogen ?? 0} '
                                  'P${note.feedingDetails!.phosphorus ?? 0} '
                                  'K${note.feedingDetails!.potassium ?? 0}'),
                        _noteDetailRow(
                            'Amendments', note.feedingDetails!.amendments),
                      ],

                      if (note.wateringDetails != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _noteDetailRow(
                            'Volume',
                            note.wateringDetails!.volumeLitres != null
                                ? '${note.wateringDetails!.volumeLitres}L'
                                : null),
                        _noteDetailRow(
                            'pH In',
                            note.wateringDetails!.phIn != null
                                ? '${note.wateringDetails!.phIn}'
                                : null),
                        _noteDetailRow(
                            'Runoff pH',
                            note.wateringDetails!.runoffPh != null
                                ? '${note.wateringDetails!.runoffPh}'
                                : null),
                      ],

                      if (note.ipmDetails != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _noteDetailRow('Product', note.ipmDetails!.product),
                        _noteDetailRow('Target', note.ipmDetails!.targetPest),
                        _noteDetailRow('Method', note.ipmDetails!.method),
                        _noteDetailRow(
                            'Dilution',
                            note.ipmDetails!.dilutionRatio != null
                                ? '${note.ipmDetails!.dilutionRatio}x'
                                : null),
                      ],

                      // Photo thumbnails
                      if (note.photoUrls.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        SizedBox(
                          height: 72,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: note.photoUrls.length,
                            itemBuilder: (_, i) {
                              // photoUrls stores bare filenames; resolve to
                              // the full absolute path before any File access.
                              final resolved = PhotoPathResolver.resolve(
                                  note.photoUrls[i]);
                              return GestureDetector(
                                onTap: () =>
                                    _viewPhoto(context, resolved, note: note),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: AppSpacing.xs),
                                    width: 72,
                                    height: 72,
                                    child: Image.file(
                                      File(resolved),
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      // P1.4 — cap decode to the
                                      // display budget (72 × DPR).
                                      cacheWidth:
                                          imageCacheWidth(context, 72),
                                      // A9 — screen-reader label.
                                      semanticLabel:
                                          'Plant photo attached to ${note.categoryLabel.toLowerCase()} note',
                                      // A6 — shimmer during async decode.
                                      frameBuilder:
                                          (_, child, frame, __) {
                                        if (frame != null) return child;
                                        return const SkeletonImage(
                                            width: 72, height: 72);
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        color: context.colSurface2,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: context.colTextMuted,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // F7 — voice-note playback rows.  One player per
                      // clip; each manages its own AudioPlayer instance.
                      if (note.audioUrls.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        for (final filename in note.audioUrls)
                          VoiceNotePlayer(filename: filename),
                      ],

                      // F8 — tag chips.  Compact, no delete handles
                      // (edit-only via the edit dialog).
                      if (note.tags.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final t in note.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusFull),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text('#$t',
                                    style: AppTypography.labelSmall(context)
                                        .copyWith(
                                            color: AppColors.primary,
                                            fontSize: 10)),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  ), // closes Container (child of Dismissible)
                ); // closes Dismissible
              }),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  void _viewPhoto(BuildContext context, String path, {PlantNote? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: note != null
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: note.category.color.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: note.category.color.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(note.category.icon,
                                color: note.category.color, size: 12),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              note.category.name[0].toUpperCase() +
                                  note.category.name.substring(1),
                              style: TextStyle(
                                  color: note.category.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: InteractiveViewer(
                  // A9 — full-screen viewer; describe the photo for
                  // screen readers since this is the primary content
                  // of the dialog.
                  child: Image.file(
                    File(path),
                    semanticLabel: note != null
                        ? 'Plant photo attached to ${note.categoryLabel.toLowerCase()} note from ${fmtShortDate(note.createdAt)}'
                        : 'Plant photo',
                  ),
                ),
              ),
              // Metadata overlay at bottom
              if (note != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          note.createdAt.toLocal().toString().split(' ')[0],
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                        if (note.content.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            note.content,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
