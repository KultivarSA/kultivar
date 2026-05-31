import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/environment_log.dart';
import '../models/grow_space.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../utils/temp_format.dart' show formatTemp, fromStorageTemp, tempUnitLabel, toStorageTemp;
import '../widgets/app_toast.dart';
import '../widgets/empty_state.dart';
import '../widgets/empty_state_art.dart';
import '../widgets/undo_overlay.dart';

class EnvironmentLogScreen extends StatefulWidget {
  const EnvironmentLogScreen({super.key});

  @override
  State<EnvironmentLogScreen> createState() => _EnvironmentLogScreenState();
}

class _EnvironmentLogScreenState extends State<EnvironmentLogScreen> {
  String? _selectedSpaceId;

  List<EnvironmentLog> _applyFilter(List<EnvironmentLog> sorted) {
    if (_selectedSpaceId == null) return sorted;
    return sorted.where((l) => l.growSpaceId == _selectedSpaceId).toList();
  }

  void _showAddLogDialog(BuildContext context, GrowRepository repo) {
    final tempController = TextEditingController();
    final humidityController = TextEditingController();
    final notesController = TextEditingController();
    String selectedSpaceId =
        repo.growSpaces.isNotEmpty ? repo.growSpaces.first.id : '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding, AppSpacing.sm,
              AppSpacing.pagePadding, AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: context.colBorderFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
                // Header
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.water.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.thermostat_rounded,
                        color: AppColors.water, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Environment Log',
                          style: AppTypography.headlineMedium(ctx)),
                      Text('${repo.growSpaces.length} space${repo.growSpaces.length == 1 ? '' : 's'} available',
                          style: AppTypography.bodySmall(ctx)),
                    ],
                  )),
                ]),
                const SizedBox(height: AppSpacing.lg),
                // Space
                Text('GROW SPACE',
                    style: AppTypography.labelSmall(ctx)
                        .copyWith(color: ctx.colTextMuted, letterSpacing: 0.8)),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: selectedSpaceId,
                  dropdownColor: ctx.colSurface2,
                  items: repo.growSpaces
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name,
                                style:
                                    TextStyle(color: ctx.colTextPrimary)),
                          ))
                      .toList(),
                  onChanged: (v) => ss(() => selectedSpaceId = v!),
                ),
                const SizedBox(height: AppSpacing.md),
                // Temperature
                TextField(
                  controller: tempController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: ctx.colTextPrimary),
                  decoration: InputDecoration(
                    labelText: tempUnitLabel,
                    prefixIcon: const Icon(Icons.thermostat_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Humidity
                TextField(
                  controller: humidityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: ctx.colTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Humidity (%)',
                    prefixIcon: Icon(Icons.water_drop_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Notes
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(color: ctx.colTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Action
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Save Log'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: () {
                    final rawTemp =
                        double.tryParse(tempController.text);
                    final humidity =
                        double.tryParse(humidityController.text);
                    if (rawTemp == null && humidity == null) return;
                    repo.addEnvironmentLog(EnvironmentLog(
                      id: repo.newId(),
                      growSpaceId: selectedSpaceId,
                      recordedAt: DateTime.now(),
                      temperature:
                          rawTemp != null ? toStorageTemp(rawTemp) : null,
                      humidity: humidity,
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                    ));
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: AppTypography.labelLarge(ctx)
                          .copyWith(color: ctx.colTextSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      tempController.dispose();
      humidityController.dispose();
      notesController.dispose();
    });
  }

  void _showEditLogDialog(
    BuildContext context,
    EnvironmentLog log,
    GrowRepository repo,
  ) {
    final tempCtrl = TextEditingController(
      text: log.temperature != null
          ? fromStorageTemp(log.temperature!).toStringAsFixed(1)
          : '',
    );
    final humCtrl = TextEditingController(
      text: log.humidity != null ? log.humidity!.toStringAsFixed(1) : '',
    );
    final notesCtrl = TextEditingController(text: log.notes ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding, AppSpacing.sm,
            AppSpacing.pagePadding, AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: context.colBorderFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              // Header
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.water.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: AppColors.water, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Text('Edit Log Entry',
                    style: AppTypography.headlineMedium(ctx)),
              ]),
              const SizedBox(height: AppSpacing.lg),
              // Temperature
              TextField(
                controller: tempCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: ctx.colTextPrimary),
                decoration: InputDecoration(
                  labelText: tempUnitLabel,
                  prefixIcon: const Icon(Icons.thermostat_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Humidity
              TextField(
                controller: humCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: ctx.colTextPrimary),
                decoration: const InputDecoration(
                  labelText: 'Humidity (%)',
                  prefixIcon: Icon(Icons.water_drop_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Notes
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                style: TextStyle(color: ctx.colTextPrimary),
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Action
              ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                onPressed: () {
                  final rawTemp = double.tryParse(tempCtrl.text);
                  final humidity = double.tryParse(humCtrl.text);
                  final notesText = notesCtrl.text.trim();
                  repo.updateEnvironmentLog(EnvironmentLog(
                    id: log.id,
                    growSpaceId: log.growSpaceId,
                    recordedAt: log.recordedAt,
                    temperature:
                        rawTemp != null ? toStorageTemp(rawTemp) : null,
                    humidity: humidity,
                    notes: notesText.isEmpty ? null : notesText,
                  ));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: AppTypography.labelLarge(ctx)
                        .copyWith(color: ctx.colTextSecondary)),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      tempCtrl.dispose();
      humCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();
    final growSpaces = repo.growSpaces;
    final sorted = List<EnvironmentLog>.from(repo.environmentLogs)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final logs = _applyFilter(sorted);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.thermostat_rounded,
              color: AppColors.water, size: 22),
          const SizedBox(width: AppSpacing.xs),
          Text('Environment Logs',
              style: AppTypography.headlineMedium(context)),
        ]),
      ),
      body: Column(
        children: [
          // ── Space filter ──────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: DropdownButtonFormField<String?>(
              initialValue: _selectedSpaceId,
              dropdownColor: context.colSurface2,
              decoration:
                  const InputDecoration(labelText: 'Filter by Grow Space'),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text('All Spaces',
                      style: TextStyle(color: context.colTextPrimary)),
                ),
                ...growSpaces.map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name,
                        style: TextStyle(color: context.colTextPrimary)),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedSpaceId = v),
            ),
          ),

          // ── Summary bar ───────────────────────
          _buildSummaryBar(context, logs, growSpaces),

          // ── Logs list ─────────────────────────
          Expanded(
            child: logs.isEmpty
                ? const EmptyState(
                    art: EmptyArt.thermo,
                    title: 'No Environment Logs',
                    subtitle: 'Tap + to log your first reading.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pagePadding),
                    itemCount: logs.length,
                    itemBuilder: (_, i) {
                      final log = logs[i];
                      final space = growSpaces.firstWhere(
                        (s) => s.id == log.growSpaceId,
                        orElse: () =>
                            const GrowSpace(id: '', name: 'Unknown', type: ''),
                      );
                      return Dismissible(
                        key: ValueKey(log.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(
                              right: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: AppColors.danger),
                        ),
                        onDismissed: (_) {
                          final deleted = log;
                          repo.deleteEnvironmentLog(deleted.id);
                          UndoOverlay.show(
                            context,
                            icon: Icons.bar_chart_rounded,
                            color: AppColors.water,
                            title: 'Log Entry Deleted',
                            subtitle:
                                'The environment log entry\nhas been removed.',
                            onUndo: () => repo.readdEnvironmentLog(deleted),
                          );
                        },
                        child: _logCard(log, space, repo),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'env_log_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 0,
        onPressed: growSpaces.isEmpty
            ? () => AppToast.show(
                  context,
                  'Create a grow space first',
                  type: ToastType.info,
                )
            : () => _showAddLogDialog(context, repo),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Summary bar ────────────────────────────────────────────────────────────

  /// Stats strip shown above the log list.
  ///
  /// Shows reading count (7d), % in range, last reading age, and — when a
  /// single space is selected — a streak warning if consecutive out-of-range
  /// readings reach 2 or more.
  Widget _buildSummaryBar(
    BuildContext context,
    List<EnvironmentLog> filteredLogs,
    List<GrowSpace> growSpaces,
  ) {
    if (filteredLogs.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final spaceMap = {for (final s in growSpaces) s.id: s};

    // Readings in the last 7 days.
    final recent =
        filteredLogs.where((l) => l.recordedAt.isAfter(sevenDaysAgo)).toList();

    // % optimal (requires both temp + humidity to be present).
    final withBoth = recent
        .where((l) => l.temperature != null && l.humidity != null)
        .toList();
    final optimalCount = withBoth.where((l) {
      final space = spaceMap[l.growSpaceId];
      return space != null && space.isOptimal(l.temperature!, l.humidity!);
    }).length;
    final pctOptimal = withBoth.isEmpty
        ? null
        : (optimalCount / withBoth.length * 100).round();

    // Last reading age.
    final lastAge = now.difference(filteredLogs.first.recordedAt);
    final String ageLabel;
    if (lastAge.inMinutes < 60) {
      ageLabel = '${lastAge.inMinutes}m ago';
    } else if (lastAge.inHours < 24) {
      ageLabel = '${lastAge.inHours}h ago';
    } else {
      ageLabel = '${lastAge.inDays}d ago';
    }

    // Consecutive out-of-range streak — only meaningful for a single space.
    int? streak;
    if (_selectedSpaceId != null) {
      final space = spaceMap[_selectedSpaceId];
      if (space != null) {
        var s = 0;
        for (final log in filteredLogs) {
          if (log.temperature == null || log.humidity == null) continue;
          if (space.isOptimal(log.temperature!, log.humidity!)) break;
          s++;
        }
        if (s >= 2) streak = s;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        0,
        AppSpacing.pagePadding,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.colBorderFaint),
        ),
        child: Row(
          children: [
            _statChip(context, '${recent.length}', 'last 7d',
                Icons.history_rounded, AppColors.primary),
            if (pctOptimal != null) ...[
              _vertDivider(context),
              _statChip(
                context,
                '$pctOptimal%',
                'in range',
                Icons.check_circle_outline_rounded,
                pctOptimal >= 80 ? AppColors.optimal : AppColors.warning,
              ),
            ],
            _vertDivider(context),
            _statChip(context, ageLabel, 'last reading',
                Icons.schedule_rounded, context.colTextMuted),
            if (streak != null) ...[
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: (streak >= 3 ? AppColors.danger : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color:
                        (streak >= 3 ? AppColors.danger : AppColors.warning)
                            .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 12,
                        color: streak >= 3
                            ? AppColors.danger
                            : AppColors.warning),
                    const SizedBox(width: 3),
                    Text(
                      '$streak consecutive',
                      style: AppTypography.labelSmall(context).copyWith(
                        color: streak >= 3
                            ? AppColors.danger
                            : AppColors.warning,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip(BuildContext context, String value, String label,
      IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppTypography.labelSmall(context).copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: AppTypography.labelSmall(context)
                  .copyWith(color: context.colTextMuted, fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }

  Widget _vertDivider(BuildContext context) => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        color: context.colBorderFaint,
      );

  // ── Log card ────────────────────────────────────────────────────────────────

  Widget _logCard(EnvironmentLog log, GrowSpace space, GrowRepository repo) {
    final isOptimal = space.isOptimal(log.temperature, log.humidity);
    final statusColor = isOptimal ? AppColors.optimal : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
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
              Text(space.name, style: AppTypography.labelLarge(context)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showEditLogDialog(context, log, repo),
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: Icon(Icons.edit_outlined,
                          color: context.colTextMuted, size: 16),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      isOptimal ? 'Optimal' : 'Check',
                      style: AppTypography.labelSmall(context)
                          .copyWith(color: statusColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatDateTime(log.recordedAt),
            style: AppTypography.bodySmall(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (log.temperature != null) ...[
                const Icon(Icons.thermostat, color: AppColors.ipmColor, size: 18),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  formatTemp(log.temperature!),
                  style: AppTypography.bodyLarge(context),
                ),
                const SizedBox(width: AppSpacing.lg),
              ],
              if (log.humidity != null) ...[
                const Icon(Icons.water_drop, color: AppColors.water, size: 18),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '${log.humidity!.toStringAsFixed(1)}%',
                  style: AppTypography.bodyLarge(context),
                ),
              ],
              if (log.vpd != null) ...[
                const SizedBox(width: AppSpacing.md),
                Icon(Icons.air_rounded,
                    color: context.colTextMuted, size: 18),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '${log.vpd!.toStringAsFixed(2)} kPa',
                  style: AppTypography.bodyLarge(context),
                ),
              ],
            ],
          ),
          if (log.notes != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(log.notes!, style: AppTypography.bodySmall(context)),
          ],
        ],
      ),
    );
  }
}
