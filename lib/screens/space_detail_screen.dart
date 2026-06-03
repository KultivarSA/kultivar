import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/environment_log.dart';
import '../models/grow_space.dart';
import '../models/plant.dart';
import '../repository/grow_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../utils/temp_format.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/batch_care_sheet.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/environment_chart.dart';
import '../widgets/environment_threshold_editor.dart';
import '../widgets/undo_overlay.dart';
import 'nutrient_calculator_screen.dart';
import 'plant_detail_screen.dart';
import 'space_environment_analytics_screen.dart';
import 'space_timeline_screen.dart';
import 'vpd_calculator_screen.dart';

enum _SpaceAction { edit, delete }

class SpaceDetailScreen extends StatefulWidget {
  final GrowSpace space;

  const SpaceDetailScreen({
    super.key,
    required this.space,
  });

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  // ── PPFD / DLI calculator state ───────────────
  final _ppfdCtrl = TextEditingController();
  final _photoCtrl = TextEditingController(text: '18');
  double? _dli;

  // ── History display ───────────────────────────
  static const _historyPageSize = 25;
  bool _showAllLogs = false;

  @override
  void dispose() {
    _ppfdCtrl.dispose();
    _photoCtrl.dispose();
    super.dispose();
  }

  void _computeDli() {
    final ppfd = double.tryParse(_ppfdCtrl.text);
    final hours = double.tryParse(_photoCtrl.text);
    setState(() {
      _dli = (ppfd != null && hours != null && hours > 0)
          ? ppfd * hours * 0.0036
          : null;
    });
  }

  Color _dliColor(double dli) {
    if (dli < 20) return AppColors.warning;
    if (dli <= 65) return AppColors.growing;
    return AppColors.danger;
  }

  String _dliLabel(double dli) {
    if (dli < 12) return 'Too Low';
    if (dli < 20) return 'Seedling';
    if (dli < 40) return 'Vegetative';
    if (dli <= 65) return 'Flowering';
    return 'Too High';
  }

  Widget _dliRef(String stage, String range) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(stage, style: AppTypography.bodySmall(context)),
          Text(range,
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted)),
        ],
      ),
    );
  }

  Widget _ppfdRow(
      BuildContext context, String stage, String ppfd, String hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(stage, style: AppTypography.bodySmall(context)),
          ),
          Expanded(
            child: Text('$ppfd µmol/m²/s',
                style: AppTypography.bodySmall(context)
                    .copyWith(color: context.colTextPrimary)),
          ),
          Text(hours,
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted)),
        ],
      ),
    );
  }

  // ── Edit grow space ───────────────────────────

  static const _spaceTypes = [
    'Indoor Tent',
    'Flower Room',
    'Veg Room',
    'Greenhouse',
    'Outdoor',
    'Dry Room',
    'Other',
  ];

  void _showEditSpaceSheet(
    BuildContext context,
    GrowRepository repo,
    GrowSpace space,
  ) {
    // Bug fix v9 -- same pattern as _showEnvLogSheet (the actual
    // sheet Marco was crashing on).  The edit-space sheet hits the
    // same _AnimatedState + _MergingListenable race when its sync
    // repo.updateGrowSpace fires while the modal is mid-pop.  Pop
    // with the updated space; persist + dispose + toast in a
    // single Future.delayed(500ms) window.
    final nameCtrl = TextEditingController(text: space.name);
    final notesCtrl = TextEditingController(text: space.notes ?? '');
    final wattageCtrl = TextEditingController(
        text: space.wattage != null
            ? space.wattage!.toStringAsFixed(0)
            : '');
    final areaCtrl = TextEditingController(
        text: space.areaSqM != null
            ? space.areaSqM!.toStringAsFixed(2)
            : '');
    String selectedType = space.type;

    showModalBottomSheet<GrowSpace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AppSheet(
          title: 'Edit Space',
          subtitle: 'Update name, type & hardware',
          icon: Icons.edit_rounded,
          iconColor: AppColors.secondary,
          children: [
              // ── Name ─────────────────────────
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: ctx.colTextPrimary),
                decoration: const InputDecoration(
                  labelText: 'Space Name *',
                  prefixIcon: Icon(Icons.label_rounded, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Type chips ───────────────────
              Text('Type',
                  style: AppTypography.bodySmall(ctx)
                      .copyWith(color: ctx.colTextMuted)),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _spaceTypes.map((t) {
                  final selected = selectedType == t;
                  return ChoiceChip(
                    label: Text(t),
                    selected: selected,
                    selectedColor: AppColors.secondary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.black : ctx.colTextSecondary,
                    ),
                    onSelected: (_) => ss(() => selectedType = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Notes ────────────────────────
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                style: TextStyle(color: ctx.colTextPrimary),
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_rounded, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Hardware ─────────────────────
              Text('Hardware (optional)',
                  style: AppTypography.bodySmall(ctx)
                      .copyWith(color: ctx.colTextMuted)),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: wattageCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: TextStyle(color: ctx.colTextPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Wattage',
                      suffixText: 'W',
                      prefixIcon: Icon(Icons.wb_incandescent_rounded,
                          size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: areaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: TextStyle(color: ctx.colTextPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Area',
                      suffixText: 'm²',
                      prefixIcon:
                          Icon(Icons.square_foot_rounded, size: 18),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.xl),

              // ── Save button ──────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    elevation: 0,
                    textStyle: AppTypography.labelLarge(ctx).copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    // Build explicitly so null values actually clear
                    // optional fields (copyWith uses ?? and can't clear).
                    // Bug fix v9: build the updated GrowSpace and
                    // pop with it.  Persistence + toast happen in
                    // the .then() block after the route is gone.
                    Navigator.pop(
                      ctx,
                      GrowSpace(
                        id: space.id,
                        name: name,
                        type: selectedType,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                        tempMin: space.tempMin,
                        tempMax: space.tempMax,
                        humidityMin: space.humidityMin,
                        humidityMax: space.humidityMax,
                        wattage: double.tryParse(wattageCtrl.text),
                        areaSqM: double.tryParse(areaCtrl.text),
                        wateringEnabled: space.wateringEnabled,
                        wateringIntervalDays: space.wateringIntervalDays,
                        feedingEnabled: space.feedingEnabled,
                        feedingIntervalDays: space.feedingIntervalDays,
                        ipmEnabled: space.ipmEnabled,
                        ipmIntervalDays: space.ipmIntervalDays,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm)),
                  child: Text('Cancel',
                      style: AppTypography.labelLarge(ctx).copyWith(
                        color: ctx.colTextSecondary,
                        fontSize: 15,
                      )),
                ),
              ),
            ],
          ),
        ),
    ).then((updated) {
      // Bug fix v9 -- single delayed batch.  See top of _showEditSpaceSheet.
      Future.delayed(const Duration(milliseconds: 500), () {
        nameCtrl.dispose();
        notesCtrl.dispose();
        wattageCtrl.dispose();
        areaCtrl.dispose();
        if (updated == null) return;
        repo.updateGrowSpace(updated);
        if (!context.mounted) return;
        AppToast.show(context, 'Space updated');
      });
    });
  }

  // ── Add environment log ───────────────────────

  void _showAddLogDialog(
    BuildContext context,
    GrowRepository repo,
  ) {
    // Bug fix v9 (the sheet Marco actually uses -- per-space env
    // log opened from Home -> space card -> "Log Environment").
    // Same _AnimatedState + _MergingListenable race that PR #19
    // fixed on the Analytics thermostat sheet, and PR #18 fixed on
    // the FAB hub.  Pop-with-payload + Future.delayed(500ms) for
    // dispose + persist + toast in a single batched window.
    final tempController = TextEditingController();
    final humidityController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet<EnvironmentLog>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppSheet(
        title: 'Log Environment',
        subtitle: widget.space.name,
        icon: Icons.thermostat_rounded,
        iconColor: AppColors.water,
        children: [
            // ── Temperature ──────────────────
            TextField(
              controller: tempController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: ctx.colTextPrimary),
              decoration: InputDecoration(
                labelText: tempUnitLabel,
                hintText: '22.0',
                suffixText: tempUnitSuffix,
                prefixIcon:
                    const Icon(Icons.thermostat_rounded, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Humidity ─────────────────────
            TextField(
              controller: humidityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: ctx.colTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Humidity (%)',
                hintText: '55.0',
                suffixText: '%',
                prefixIcon: Icon(Icons.water_drop_rounded, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Notes ────────────────────────
            TextField(
              controller: notesController,
              maxLines: 2,
              style: TextStyle(color: ctx.colTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Save button ──────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Reading'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.water,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  elevation: 0,
                  textStyle: AppTypography.labelLarge(ctx).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  final rawTemp = double.tryParse(tempController.text);
                  final humidity =
                      double.tryParse(humidityController.text);
                  if (rawTemp == null && humidity == null) {
                    AppToast.show(
                      ctx,
                      'Enter at least a temperature or humidity value',
                      type: ToastType.info,
                    );
                    return;
                  }
                  // Bug fix v9: build the log + pop with it as the
                  // result.  See top of this function.
                  Navigator.pop(
                    ctx,
                    EnvironmentLog(
                      id: repo.newId(),
                      growSpaceId: widget.space.id,
                      recordedAt: DateTime.now(),
                      temperature: rawTemp != null
                          ? toStorageTemp(rawTemp)
                          : null,
                      humidity: humidity,
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm)),
                child: Text('Cancel',
                    style: AppTypography.labelLarge(ctx).copyWith(
                      color: ctx.colTextSecondary,
                      fontSize: 15,
                    )),
              ),
            ),
        ],
      ),
    ).then((log) {
      // Bug fix v9 -- single delayed window so neither the dispose
      // nor the repo write touches anything while the modal route
      // is still mid-pop-animation.  See top of _showEnvLogSheet.
      Future.delayed(const Duration(milliseconds: 500), () {
        tempController.dispose();
        humidityController.dispose();
        notesController.dispose();
        if (log != null) repo.addEnvironmentLog(log);
      });
    });
  }

  // ── Gauge ─────────────────────────────────────

  Widget _gauge({
    required String label,
    required double? value,
    required String unit,
    required double min,
    required double max,
    required double optimalMin,
    required double optimalMax,
    required Color color,
    required IconData icon,
  }) {
    final hasValue = value != null;
    final fraction =
        hasValue ? ((value - min) / (max - min)).clamp(0.0, 1.0) : 0.0;
    final isOptimal = hasValue && value >= optimalMin && value <= optimalMax;
    final statusColor = hasValue
        ? (isOptimal ? AppColors.optimal : AppColors.warning)
        : context.colTextMuted;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            //
            // Bug fix v5: each gauge sits in half the available row
            // width (~150 dp on S22).  At large text-scale, the
            // "Temperature" + "Optimal" badge combo overflowed
            // horizontally.  Wrap the label in Flexible+ellipsis so
            // it gives way before the status badge does.
            Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.bodySmall(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  hasValue ? (isOptimal ? 'Optimal' : 'Check') : 'No data',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: statusColor),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),

            // Value -- FittedBox + scaleDown so a 3-digit °F reading
            // or large text-scale can't push the displayMedium value
            // past the gauge's narrow column.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                hasValue ? '${value.toStringAsFixed(1)}$unit' : '—',
                style: AppTypography.displayMedium(context)
                    .copyWith(color: color),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: context.colSurface3,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),

            // Range labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$min$unit', style: AppTypography.bodySmall(context)),
                Text(
                  'Ideal ${optimalMin.toStringAsFixed(0)}–'
                  '${optimalMax.toStringAsFixed(0)}$unit',
                  style: AppTypography.bodySmall(context),
                ),
                Text('$max$unit', style: AppTypography.bodySmall(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Log entry ─────────────────────────────────

  Widget _logEntry(EnvironmentLog log, GrowSpace currentSpace) {
    // ✅ Use per-space thresholds for status
    final isOptimal = currentSpace.isOptimal(log.temperature, log.humidity);
    final statusColor = isOptimal ? AppColors.optimal : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDateTime(log.recordedAt),
                style: AppTypography.bodySmall(context),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  isOptimal ? 'Optimal' : 'Check',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            if (log.temperature != null) ...[
              const Icon(Icons.thermostat, color: AppColors.ipmColor, size: 16),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                formatTemp(log.temperature!),
                style: AppTypography.bodyLarge(context),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            if (log.humidity != null) ...[
              const Icon(Icons.water_drop, color: AppColors.water, size: 16),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                '${log.humidity!.toStringAsFixed(1)}%',
                style: AppTypography.bodyLarge(context),
              ),
            ],
          ]),
          if (log.notes != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(log.notes!, style: AppTypography.bodySmall(context)),
          ],
        ],
      ),
    );
  }

  // ── Delete space confirmation ─────────────────

  void _confirmDeleteSpace(
    BuildContext context,
    GrowRepository repo,
    GrowSpace space,
    int activePlantCount,
  ) async {
    final confirmed = await ConfirmSheet.show(
      context,
      icon: Icons.delete_rounded,
      iconColor: AppColors.danger,
      title: 'Delete "${space.name}"?',
      body: 'This action cannot be undone.',
      extraContent: activePlantCount > 0
          ? Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.28)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.danger, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '$activePlantCount active '
                    '${activePlantCount == 1 ? 'plant' : 'plants'} '
                    'will be archived as removed.',
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: AppColors.danger),
                  ),
                ),
              ]),
            )
          : null,
      confirmLabel: 'Delete Space',
    );

    if (confirmed && context.mounted) {
      // Cancel every notification tied to this space BEFORE removing it.
      // Without this:
      //   • space-level watering / feeding / IPM reminders fire days later
      //     for a space the user just deleted,
      //   • the 48 h stale-env alert fires for a space that doesn't exist,
      //   • watering / feeding / IPM / harvest reminders for plants in this
      //     space keep firing because removeGrowSpace archives them but
      //     doesn't touch their notification slots.
      // Parallelised so deleting a space with 10+ plants stays snappy.
      final ns = NotificationService();
      final plantsInSpace = repo.plants
          .where((p) => p.growSpaceId == space.id)
          .toList();
      await Future.wait([
        ns.cancelSpaceWateringReminder(space.id),
        ns.cancelSpaceFeedingReminder(space.id),
        ns.cancelSpaceIpmReminder(space.id),
        ns.cancelStaleEnvAlert(space.id),
        for (final p in plantsInSpace) ...[
          ns.cancelWateringReminder(p.id),
          ns.cancelFeedingReminder(p.id),
          ns.cancelIpmReminder(p.id),
          ns.cancelHarvestReminder(p.id),
        ],
      ]);

      if (!context.mounted) return;
      final archived = repo.removeGrowSpace(space.id);
      Navigator.pop(context); // pop SpaceDetailScreen
      final msg = archived > 0
          ? '"${space.name}" deleted · $archived '
              '${archived == 1 ? 'plant' : 'plants'} archived'
          : '"${space.name}" deleted';
      AppToast.show(context, msg, type: ToastType.error);
    }
  }

  // ── Plant tile ───────────────────────────────

  Widget _plantTile(
      BuildContext context, Plant plant, List<Plant> siblings) {
    final statusColor = AppColors.statusColor(plant.statusLabel);
    final stageLabel = plant.growStage?.shortLabel;
    final days = plant.daysInCurrentStatus;
    final daysLabel = plant.statusDaysLabel;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlantDetailScreen(
            plant: plant,
            siblings: siblings,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            // Status color bar
            Container(
              width: 4,
              height: 40,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Name + stage/strain
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plant.name,
                      style: AppTypography.labelLarge(context)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (stageLabel != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.growing.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
                            border: Border.all(
                              color:
                                  AppColors.growing.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            stageLabel,
                            style:
                                AppTypography.labelSmall(context).copyWith(
                              color: AppColors.growing,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Text(
                        plant.strain.isNotEmpty ? plant.strain : plant.statusLabel,
                        style: AppTypography.bodySmall(context),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Days counter
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  daysLabel,
                  style: AppTypography.labelLarge(context)
                      .copyWith(color: statusColor),
                ),
                Text(
                  '${days}d in phase',
                  style: AppTypography.bodySmall(context)
                      .copyWith(fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right,
                size: 18, color: context.colTextMuted),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();

    // ✅ Always resolve latest space from repo
    final currentSpace = repo.growSpaces.firstWhere(
      (s) => s.id == widget.space.id,
      orElse: () => widget.space,
    );

    final logs = repo.environmentLogs
        .where((l) => l.growSpaceId == currentSpace.id)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    final latest = logs.isNotEmpty ? logs.first : null;
    final vpdColor = latest?.vpd == null
        ? context.colTextMuted
        : (latest!.vpd! >= 0.4 && latest.vpd! <= 1.6)
            ? AppColors.optimal
            : AppColors.warning;

    final plantsInSpace = repo.plants
        .where((p) => p.growSpaceId == currentSpace.id && !p.isArchived)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentSpace.name,
                style: AppTypography.headlineMedium(context)),
            Text(currentSpace.type, style: AppTypography.bodySmall(context)),
          ],
        ),
        actions: [
          // Multi-plant timeline
          if (plantsInSpace.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.timeline_rounded),
              tooltip: 'View plant timeline',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SpaceTimelineScreen(
                    space: currentSpace,
                    plants: plantsInSpace,
                  ),
                ),
              ),
            ),
          // Nutrient calculator shortcut
          IconButton(
            icon: const Icon(Icons.science_rounded),
            tooltip: 'Nutrient Calculator',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NutrientCalculatorScreen(
                  // Pre-fill medium from the most recently updated active plant
                  // in this space, so tank-mix advice is immediately relevant.
                  initialMedium: plantsInSpace
                      .where((p) => p.medium != null)
                      .fold<Plant?>(
                        null,
                        (best, p) =>
                            best == null || p.startDate.isAfter(best.startDate)
                                ? p
                                : best,
                      )
                      ?.medium,
                  initialStage: plantsInSpace
                      .where((p) => p.growStage != null)
                      .fold<Plant?>(
                        null,
                        (best, p) =>
                            best == null || p.startDate.isAfter(best.startDate)
                                ? p
                                : best,
                      )
                      ?.growStage,
                ),
              ),
            ),
          ),
          // Batch care — visible only when this space has active plants.
          if (plantsInSpace.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.water_drop_outlined),
              tooltip: 'Log care for all plants',
              onPressed: () => BatchCareSheet.show(
                context,
                space: currentSpace,
                plants: plantsInSpace,
                allNotes: repo.notes
                    .where((n) =>
                        plantsInSpace.any((p) => p.id == n.plantId))
                    .toList(),
              ),
            ),
          PopupMenuButton<_SpaceAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              if (action == _SpaceAction.edit) {
                _showEditSpaceSheet(context, repo, currentSpace);
              } else if (action == _SpaceAction.delete) {
                _confirmDeleteSpace(
                    context, repo, currentSpace, plantsInSpace.length);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _SpaceAction.edit,
                child: Row(children: [
                  Icon(Icons.edit_rounded,
                      color: AppColors.secondary, size: 20),
                  SizedBox(width: AppSpacing.xs),
                  Text('Edit Space'),
                ]),
              ),
              const PopupMenuItem(
                value: _SpaceAction.delete,
                child: Row(children: [
                  Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                  SizedBox(width: AppSpacing.xs),
                  Text('Delete Space',
                      style: TextStyle(color: AppColors.danger)),
                ]),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'space_detail_log_fab',
        onPressed: () => _showAddLogDialog(context, repo),
        backgroundColor: AppColors.drying,
        foregroundColor: Colors.black,
        elevation: 0,
        icon: const Icon(Icons.add),
        label: Text('Log Environment',
            style: AppTypography.labelLarge(context)
                .copyWith(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.pagePadding,
          AppSpacing.pagePadding,
          120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current conditions ──────────────
            Text('Current Conditions',
                style: AppTypography.headlineSmall(context)),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              latest != null
                  ? 'Last reading: ${fmtShortDateTime(latest.recordedAt)}'
                  : 'No readings logged yet',
              style: AppTypography.bodySmall(context),
            ),
            const SizedBox(height: AppSpacing.md),

            // ✅ Gauges use per-space thresholds
            Column(
              children: [
                Row(children: [
                  _gauge(
                    label: 'Temperature',
                    // Convert stored °C to the user's display unit so the
                    // value, unit suffix, scale and optimal range all match.
                    value: latest?.temperature != null
                        ? fromStorageTemp(latest!.temperature!)
                        : null,
                    unit: tempUnitSuffix,
                    min: fromStorageTemp(0),
                    max: fromStorageTemp(45),
                    optimalMin: fromStorageTemp(currentSpace.tempMin),
                    optimalMax: fromStorageTemp(currentSpace.tempMax),
                    color: AppColors.ipmColor,
                    icon: Icons.thermostat,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _gauge(
                    label: 'Humidity',
                    value: latest?.humidity,
                    unit: '%',
                    min: 0,
                    max: 100,
                    optimalMin: currentSpace.humidityMin,
                    optimalMax: currentSpace.humidityMax,
                    color: AppColors.water,
                    icon: Icons.water_drop,
                  ),
                ]),
                if (latest?.vpd != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VpdCalculatorScreen(
                          initialTempC: latest.temperature,
                          initialHumidity: latest.humidity,
                        ),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: context.colSurface1,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border:
                            Border.all(color: vpdColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.air_rounded,
                                  color: context.colTextMuted, size: 16),
                              const SizedBox(width: AppSpacing.xs),
                              Text('VPD',
                                  style: AppTypography.labelLarge(context)),
                              const SizedBox(width: AppSpacing.xs),
                              Text('(ideal: 0.4–1.6 kPa)',
                                  style: AppTypography.bodySmall(context)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${latest!.vpd!.toStringAsFixed(2)} kPa',
                                style: AppTypography.labelLarge(context)
                                    .copyWith(color: vpdColor),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: vpdColor.withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: Text(
                                  latest.vpdStatus,
                                  style: AppTypography.labelSmall(context)
                                      .copyWith(color: vpdColor),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Icon(Icons.chevron_right,
                                  size: 14, color: context.colTextMuted),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Environment chart ───────────────
            EnvironmentChart(
              logs: logs,
              space: currentSpace,
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Analytics entry point ───────────
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SpaceEnvironmentAnalyticsScreen(
                    space: currentSpace,
                    logs: repo.environmentLogs,
                    plants: repo.plants
                        .where((p) => p.growSpaceId == currentSpace.id)
                        .toList(),
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: context.colSurface1,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3)),
                ),
                // Bug fix v5: the inner Row had icon + title +
                // subtitle + chevron all competing for the card's
                // horizontal width.  Subtitle "phase breakdown · VPD
                // · streaks" tipped it past the edge.  Move title +
                // subtitle into a Column so they stack vertically;
                // wrap that column in Expanded so the chevron
                // always lands flush right.
                child: Row(
                  children: [
                    const Icon(Icons.analytics_rounded,
                        color: AppColors.secondary, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Full Analytics',
                            style: AppTypography.labelLarge(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'phase breakdown · VPD · streaks',
                            style: AppTypography.bodySmall(context).copyWith(
                                color: context.colTextMuted, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 16, color: AppColors.secondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Plants in this space ────────────
            if (plantsInSpace.isNotEmpty) ...[
              _SpaceAggregateSummary(plants: plantsInSpace),
              const SizedBox(height: AppSpacing.md),
              ...plantsInSpace.map((plant) => _plantTile(context, plant, plantsInSpace)),
              const SizedBox(height: AppSpacing.xl),
            ],

            // ── Optimal threshold editor ────────
            EnvironmentThresholdEditor(
              space: currentSpace,
              onSaved: (updated) {
                repo.updateGrowSpace(updated);
                AppToast.show(context, 'Thresholds saved');
              },
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Space care schedule ─────────────
            _SpaceCareScheduleCard(
              space: currentSpace,
              onSaved: (updated) => repo.updateGrowSpace(updated),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── PPFD / DLI calculator ────────────
            Row(
              children: [
                const Icon(Icons.wb_incandescent_rounded,
                    color: AppColors.drying, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Text('Light Calculator',
                    style: AppTypography.headlineSmall(context)),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Calculate Daily Light Integral from PPFD and photoperiod.',
              style: AppTypography.bodySmall(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _ppfdCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.colTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'PPFD',
                    suffixText: 'µmol/m²/s',
                  ),
                  onChanged: (_) => _computeDli(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _photoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.colTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Photoperiod',
                    suffixText: 'h/day',
                  ),
                  onChanged: (_) => _computeDli(),
                ),
              ),
            ]),
            if (_dli != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Builder(builder: (context) {
                final dliColor = _dliColor(_dli!);
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: dliColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: dliColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DLI', style: AppTypography.bodySmall(context)),
                          Text(
                            '${_dli!.toStringAsFixed(1)} mol/m²/day',
                            style: AppTypography.headlineLarge(context)
                                .copyWith(color: dliColor),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: dliColor.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                          border:
                              Border.all(color: dliColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _dliLabel(_dli!),
                          style: AppTypography.labelLarge(context)
                              .copyWith(color: dliColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.colSurface1,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: context.colBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Stage',
                              style: AppTypography.labelSmall(context)
                                  .copyWith(color: context.colTextMuted)),
                        ),
                        Expanded(
                          child: Text('PPFD',
                              style: AppTypography.labelSmall(context)
                                  .copyWith(color: context.colTextMuted)),
                        ),
                        Text('Hours',
                            style: AppTypography.labelSmall(context)
                                .copyWith(color: context.colTextMuted)),
                      ],
                    ),
                    Divider(height: 8, color: context.colBorder),
                    _ppfdRow(context, 'Seedling', '100–300', '18 h/day'),
                    _ppfdRow(context, 'Vegetative', '300–600', '18 h/day'),
                    _ppfdRow(context, 'Flowering', '600–900', '12 h/day'),
                    _ppfdRow(context, 'Late Flower', '800–1000', '12 h/day'),
                    Divider(height: 8, color: context.colBorder),
                    _dliRef('Seedling DLI', '12–20'),
                    _dliRef('Vegetative DLI', '20–40'),
                    _dliRef('Flowering DLI', '40–65'),
                  ],
                ),
              ),
            ],

            // ── Environment history ─────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'History (${logs.length})',
                  style: AppTypography.headlineSmall(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            if (logs.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: context.colSurface1,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: context.colBorder),
                ),
                child: Row(children: [
                  Icon(Icons.thermostat,
                      color: context.colTextMuted, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'No readings yet\n'
                    'Tap Log Environment to start',
                    style: AppTypography.bodyMedium(context)
                        .copyWith(fontStyle: FontStyle.italic),
                  ),
                ]),
              )
            else ...[
              // Show the most-recent _historyPageSize entries by default.
              ...(_showAllLogs ? logs : logs.take(_historyPageSize).toList())
                  .map((l) => Dismissible(
                    key: Key(l.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(
                        right: AppSpacing.lg,
                        bottom: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white),
                    ),
                    onDismissed: (_) {
                      repo.deleteEnvironmentLog(l.id);
                      UndoOverlay.show(
                        context,
                        icon: Icons.bar_chart_rounded,
                        color: AppColors.water,
                        title: 'Log Entry Deleted',
                        subtitle: 'The environment log entry\nhas been removed.',
                        onUndo: () => repo.readdEnvironmentLog(l),
                      );
                    },
                    child: _logEntry(l, currentSpace),
                  )),

              // "Show all / Show less" toggle when log list is long.
              if (logs.length > _historyPageSize)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _showAllLogs = !_showAllLogs),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.colSurface1,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: context.colBorder),
                      ),
                      child: Text(
                        _showAllLogs
                            ? 'Show less'
                            : 'Show all ${logs.length} readings',
                        textAlign: TextAlign.center,
                        style: AppTypography.labelLarge(context)
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
            ],   // closes else ...[
          ],     // closes Column children
        ),
      ),
    );
  }

}

// ── Space care schedule card ───────────────────────────────────────────────

class _SpaceCareScheduleCard extends StatefulWidget {
  final GrowSpace space;
  final void Function(GrowSpace updated) onSaved;

  const _SpaceCareScheduleCard({
    required this.space,
    required this.onSaved,
  });

  @override
  State<_SpaceCareScheduleCard> createState() => _SpaceCareScheduleCardState();
}

class _SpaceCareScheduleCardState extends State<_SpaceCareScheduleCard> {
  late bool _wateringEnabled;
  late int _wateringInterval;
  late bool _feedingEnabled;
  late int _feedingInterval;
  late bool _ipmEnabled;
  late int _ipmInterval;

  @override
  void initState() {
    super.initState();
    _syncFromSpace(widget.space);
  }

  @override
  void didUpdateWidget(_SpaceCareScheduleCard old) {
    super.didUpdateWidget(old);
    if (old.space != widget.space) {
      _syncFromSpace(widget.space);
    }
  }

  void _syncFromSpace(GrowSpace s) {
    _wateringEnabled = s.wateringEnabled;
    _wateringInterval = s.wateringIntervalDays;
    _feedingEnabled = s.feedingEnabled;
    _feedingInterval = s.feedingIntervalDays;
    _ipmEnabled = s.ipmEnabled;
    _ipmInterval = s.ipmIntervalDays;
  }

  Future<void> _save() async {
    final updated = widget.space.copyWith(
      wateringEnabled: _wateringEnabled,
      wateringIntervalDays: _wateringInterval,
      feedingEnabled: _feedingEnabled,
      feedingIntervalDays: _feedingInterval,
      ipmEnabled: _ipmEnabled,
      ipmIntervalDays: _ipmInterval,
    );
    widget.onSaved(updated);
    final notif = NotificationService();
    if (_wateringEnabled) {
      await notif.scheduleSpaceWateringReminder(
        spaceId: widget.space.id,
        spaceName: widget.space.name,
        intervalDays: _wateringInterval,
      );
    } else {
      await notif.cancelSpaceWateringReminder(widget.space.id);
    }
    if (_feedingEnabled) {
      await notif.scheduleSpaceFeedingReminder(
        spaceId: widget.space.id,
        spaceName: widget.space.name,
        intervalDays: _feedingInterval,
      );
    } else {
      await notif.cancelSpaceFeedingReminder(widget.space.id);
    }
    if (_ipmEnabled) {
      await notif.scheduleSpaceIpmReminder(
        spaceId: widget.space.id,
        spaceName: widget.space.name,
        intervalDays: _ipmInterval,
      );
    } else {
      await notif.cancelSpaceIpmReminder(widget.space.id);
    }
    if (mounted) {
      AppToast.show(context, 'Care schedule saved');
    }
  }

  Widget _careRow({
    required String label,
    required String unit,
    required IconData icon,
    required Color color,
    required bool enabled,
    required int interval,
    required int min,
    required int max,
    required ValueChanged<bool> onToggle,
    required ValueChanged<int> onIntervalChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle row
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.labelLarge(context)),
                  if (enabled)
                    Text(
                      'Every $interval ${interval == 1 ? 'day' : 'days'}',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextMuted, fontSize: 11),
                    ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              activeThumbColor: color,
              onChanged: onToggle,
            ),
          ],
        ),
        // Interval slider — only visible when enabled
        if (enabled) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const SizedBox(width: 44),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: color,
                    thumbColor: color,
                    inactiveTrackColor: color.withValues(alpha: 0.2),
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: interval.toDouble(),
                    min: min.toDouble(),
                    max: max.toDouble(),
                    divisions: max - min,
                    label: '$interval$unit',
                    onChanged: (v) => onIntervalChanged(v.round()),
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$interval$unit',
                  textAlign: TextAlign.right,
                  style: AppTypography.labelLarge(context)
                      .copyWith(color: color, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.colBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.event_repeat_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text('Care Schedule',
                  style: AppTypography.headlineSmall(context)),
              const Spacer(),
              Text(
                'Space-wide',
                style: AppTypography.bodySmall(context)
                    .copyWith(color: context.colTextMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'One schedule for all plants in this space.',
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextMuted),
          ),
          const SizedBox(height: AppSpacing.md),

          // Watering
          _careRow(
            label: 'Watering',
            unit: 'd',
            icon: Icons.water_drop_rounded,
            color: AppColors.water,
            enabled: _wateringEnabled,
            interval: _wateringInterval,
            min: 1,
            max: 14,
            onToggle: (v) => setState(() => _wateringEnabled = v),
            onIntervalChanged: (v) => setState(() => _wateringInterval = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: context.colBorder),
          const SizedBox(height: AppSpacing.sm),

          // Feeding
          _careRow(
            label: 'Feeding',
            unit: 'd',
            icon: Icons.eco_rounded,
            color: AppColors.secondary,
            enabled: _feedingEnabled,
            interval: _feedingInterval,
            min: 1,
            max: 21,
            onToggle: (v) => setState(() => _feedingEnabled = v),
            onIntervalChanged: (v) => setState(() => _feedingInterval = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: context.colBorder),
          const SizedBox(height: AppSpacing.sm),

          // IPM
          _careRow(
            label: 'IPM / Pest Inspection',
            unit: 'd',
            icon: Icons.bug_report_rounded,
            color: AppColors.ipmColor,
            enabled: _ipmEnabled,
            interval: _ipmInterval,
            min: 3,
            max: 30,
            onToggle: (v) => setState(() => _ipmEnabled = v),
            onIntervalChanged: (v) => setState(() => _ipmInterval = v),
          ),

          const SizedBox(height: AppSpacing.md),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Save Schedule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                textStyle: AppTypography.labelLarge(context)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Aggregate summary card ─────────────────────────────────────────────────

class _SpaceAggregateSummary extends StatelessWidget {
  final List<Plant> plants;

  const _SpaceAggregateSummary({required this.plants});

  @override
  Widget build(BuildContext context) {
    // Stage distribution for growing plants
    final stageCounts = <GrowStage, int>{};
    int harvesting = 0;
    int drying = 0;
    int curing = 0;

    for (final p in plants) {
      switch (p.status) {
        case PlantStatus.growing:
          if (p.growStage != null) {
            stageCounts[p.growStage!] = (stageCounts[p.growStage!] ?? 0) + 1;
          }
        case PlantStatus.harvested:
          harvesting++;
        case PlantStatus.drying:
          drying++;
        case PlantStatus.curing:
          curing++;
        default:
          break;
      }
    }

    final wateringCount =
        plants.where((p) => p.wateringReminderEnabled).length;
    final feedingCount =
        plants.where((p) => p.feedingReminderEnabled).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.colBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              'Plants (${plants.length})',
              style: AppTypography.headlineSmall(context),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),

          // Stage / status distribution pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...stageCounts.entries.map((e) => _stagePill(
                    context,
                    '${e.value}× ${e.key.shortLabel}',
                    AppColors.growing,
                  )),
              if (harvesting > 0)
                _stagePill(context, '$harvesting× Harvested',
                    AppColors.harvested),
              if (drying > 0)
                _stagePill(context, '$drying× Drying', AppColors.drying),
              if (curing > 0)
                _stagePill(context, '$curing× Curing', AppColors.curing),
              if (stageCounts.isEmpty &&
                  harvesting == 0 &&
                  drying == 0 &&
                  curing == 0)
                _stagePill(context, '${plants.length} active', AppColors.primary),
            ],
          ),

          // Care reminder summary
          if (wateringCount > 0 || feedingCount > 0) ...[
            Divider(height: AppSpacing.lg, color: context.colBorder),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                if (wateringCount > 0)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.water_drop_rounded,
                        color: AppColors.water, size: 14),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      '$wateringCount watering reminder${wateringCount > 1 ? 's' : ''} active',
                      style: AppTypography.bodySmall(context),
                    ),
                  ]),
                if (feedingCount > 0)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.eco_rounded,
                        color: AppColors.secondary, size: 14),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      '$feedingCount feeding reminder${feedingCount > 1 ? 's' : ''} active',
                      style: AppTypography.bodySmall(context),
                    ),
                  ]),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stagePill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(context).copyWith(color: color),
      ),
    );
  }
}
