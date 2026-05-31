import 'dart:async';

import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/plant.dart';
import '../../repository/grow_repository.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Per-plant care reminder configuration: watering / feeding / IPM
/// toggles and the cadence slider for each.
///
/// On every change, the matching `NotificationService.schedule*` call
/// re-pins the OS-level reminder using the **stage-adjusted effective
/// interval** (`Plant.effective*IntervalDays()`) — so a flower-stage
/// plant with the F10 auto-adjust toggle on gets the lengthened cadence
/// fired at the OS level, not just shown in the UI.  A 0 effective
/// interval (e.g. IPM during flush) cancels the reminder entirely.
///
/// Extracted from `plant_detail_screen.dart` (Q1a).
class CareScheduleCard extends StatefulWidget {
  final Plant plant;
  final GrowRepository repo;

  const CareScheduleCard({
    super.key,
    required this.plant,
    required this.repo,
  });

  @override
  State<CareScheduleCard> createState() => _CareScheduleCardState();
}

class _CareScheduleCardState extends State<CareScheduleCard> {
  late bool _wateringEnabled;
  late int _wateringInterval;
  late bool _feedingEnabled;
  late int _feedingInterval;
  late bool _ipmEnabled;
  late int _ipmInterval;

  @override
  void initState() {
    super.initState();
    _wateringEnabled = widget.plant.wateringReminderEnabled;
    _wateringInterval = widget.plant.wateringIntervalDays;
    _feedingEnabled = widget.plant.feedingReminderEnabled;
    _feedingInterval = widget.plant.feedingIntervalDays;
    _ipmEnabled = widget.plant.ipmReminderEnabled;
    _ipmInterval = widget.plant.ipmIntervalDays;
  }

  @override
  void didUpdateWidget(CareScheduleCard old) {
    super.didUpdateWidget(old);
    if (old.plant != widget.plant) {
      _wateringEnabled = widget.plant.wateringReminderEnabled;
      _wateringInterval = widget.plant.wateringIntervalDays;
      _feedingEnabled = widget.plant.feedingReminderEnabled;
      _feedingInterval = widget.plant.feedingIntervalDays;
      _ipmEnabled = widget.plant.ipmReminderEnabled;
      _ipmInterval = widget.plant.ipmIntervalDays;
    }
  }

  void _saveAndScheduleWatering({required bool enabled, required int interval}) {
    final updated = widget.plant.copyWith(
      wateringReminderEnabled: enabled,
      wateringIntervalDays: interval,
    );
    widget.repo.updatePlant(updated);
    // F10 — schedule with the stage-adjusted effective interval so the
    // OS-level notification fires on the same cadence the UI shows.
    // The "skip" sentinel (0) cancels the reminder entirely.
    final effective = updated.effectiveWateringIntervalDays();
    if (enabled && effective > 0 && KultivarApp.notifWateringEnabled.value) {
      unawaited(NotificationService().scheduleWateringReminder(
        plantId: widget.plant.id,
        plantName: widget.plant.name,
        intervalDays: effective,
      ));
    } else {
      unawaited(NotificationService().cancelWateringReminder(widget.plant.id));
    }
  }

  void _saveAndScheduleFeeding({required bool enabled, required int interval}) {
    final updated = widget.plant.copyWith(
      feedingReminderEnabled: enabled,
      feedingIntervalDays: interval,
    );
    widget.repo.updatePlant(updated);
    final effective = updated.effectiveFeedingIntervalDays();
    if (enabled && effective > 0 && KultivarApp.notifFeedingEnabled.value) {
      unawaited(NotificationService().scheduleFeedingReminder(
        plantId: widget.plant.id,
        plantName: widget.plant.name,
        intervalDays: effective,
      ));
    } else {
      unawaited(NotificationService().cancelFeedingReminder(widget.plant.id));
    }
  }

  void _saveAndScheduleIpm({required bool enabled, required int interval}) {
    final updated = widget.plant.copyWith(
      ipmReminderEnabled: enabled,
      ipmIntervalDays: interval,
    );
    widget.repo.updatePlant(updated);
    final effective = updated.effectiveIpmIntervalDays();
    if (enabled && effective > 0 && KultivarApp.notifIpmEnabled.value) {
      unawaited(NotificationService().scheduleIpmReminder(
        plantId: widget.plant.id,
        plantName: widget.plant.name,
        intervalDays: effective,
      ));
    } else {
      unawaited(NotificationService().cancelIpmReminder(widget.plant.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.colBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.water.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: AppColors.water, size: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Care Schedule',
                    style: AppTypography.labelLarge(context)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: context.colBorderFaint),

          // ── Watering ─────────────────────────────
          _CareRow(
            label: 'Watering Reminder',
            color: AppColors.water,
            icon: Icons.water_drop_rounded,
            enabled: _wateringEnabled,
            interval: _wateringInterval,
            min: 1,
            max: 7,
            divisions: 6,
            onToggle: (v) {
              setState(() => _wateringEnabled = v);
              _saveAndScheduleWatering(
                  enabled: v, interval: _wateringInterval);
            },
            onIntervalChanged: (v) => setState(() => _wateringInterval = v),
            onIntervalCommitted: (v) => _saveAndScheduleWatering(
                enabled: _wateringEnabled, interval: v),
          ),
          Divider(height: 1, color: context.colBorderFaint),

          // ── Feeding ───────────────────────────────
          _CareRow(
            label: 'Feeding Reminder',
            color: AppColors.secondary,
            icon: Icons.restaurant_rounded,
            enabled: _feedingEnabled,
            interval: _feedingInterval,
            min: 1,
            max: 14,
            divisions: 13,
            onToggle: (v) {
              setState(() => _feedingEnabled = v);
              _saveAndScheduleFeeding(
                  enabled: v, interval: _feedingInterval);
            },
            onIntervalChanged: (v) => setState(() => _feedingInterval = v),
            onIntervalCommitted: (v) => _saveAndScheduleFeeding(
                enabled: _feedingEnabled, interval: v),
          ),
          Divider(height: 1, color: context.colBorderFaint),

          // ── IPM ──────────────────────────────────
          _CareRow(
            label: 'IPM Reminder',
            color: AppColors.ipmColor,
            icon: Icons.bug_report_rounded,
            enabled: _ipmEnabled,
            interval: _ipmInterval,
            min: 1,
            max: 21,
            divisions: 20,
            onToggle: (v) {
              setState(() => _ipmEnabled = v);
              _saveAndScheduleIpm(enabled: v, interval: _ipmInterval);
            },
            onIntervalChanged: (v) => setState(() => _ipmInterval = v),
            onIntervalCommitted: (v) => _saveAndScheduleIpm(
                enabled: _ipmEnabled, interval: v),
          ),

          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}

/// Internal one-row template for the three care-schedule entries.
/// Pulled out to remove the three near-duplicate row blocks from the
/// parent build method.
class _CareRow extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool enabled;
  final int interval;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<int> onIntervalCommitted;

  const _CareRow({
    required this.label,
    required this.color,
    required this.icon,
    required this.enabled,
    required this.interval,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onToggle,
    required this.onIntervalChanged,
    required this.onIntervalCommitted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(label,
                    style: AppTypography.bodyMedium(context)
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
              Switch(
                value: enabled,
                activeThumbColor: color,
                activeTrackColor: color.withValues(alpha: 0.4),
                onChanged: onToggle,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  'Every $interval ${interval == 1 ? 'day' : 'days'}',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: color),
                ),
                const Spacer(),
                Text('${min.toInt()}d',
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colTextMuted)),
                Expanded(
                  flex: 4,
                  child: Slider(
                    value: interval.toDouble(),
                    min: min,
                    max: max,
                    divisions: divisions,
                    activeColor: color,
                    onChanged: (v) => onIntervalChanged(v.round()),
                    onChangeEnd: (v) => onIntervalCommitted(v.round()),
                  ),
                ),
                Text('${max.toInt()}d',
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colTextMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
