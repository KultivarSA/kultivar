import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class BurpingReminderCard extends StatefulWidget {
  final Plant plant;
  final void Function({
    required bool enabled,
    required String schedule,
    required TimeOfDay time,
  }) onChanged;

  const BurpingReminderCard({
    super.key,
    required this.plant,
    required this.onChanged,
  });

  @override
  State<BurpingReminderCard> createState() => _BurpingReminderCardState();
}

class _BurpingReminderCardState extends State<BurpingReminderCard> {
  late bool _enabled;
  late String _schedule;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _enabled = widget.plant.burpingRemindersEnabled;
    _schedule = widget.plant.burpingSchedule;
    _time = widget.plant.burpingTime ?? const TimeOfDay(hour: 9, minute: 0);
  }

  void _notify() {
    widget.onChanged(enabled: _enabled, schedule: _schedule, time: _time);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!),
    );
    if (picked != null) {
      setState(() => _time = picked);
      _notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: _enabled
              ? AppColors.curing.withValues(alpha: 0.5)
              : context.colBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toggle row ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.notifications,
                    color: AppColors.curing, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Burping Reminders',
                    style: AppTypography.labelLarge(context)),
              ]),
              Switch(
                value: _enabled,
                onChanged: (v) {
                  setState(() => _enabled = v);
                  _notify();
                },
              ),
            ],
          ),

          if (_enabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(color: context.colBorder),
            const SizedBox(height: AppSpacing.sm),

            // ── Schedule picker ───────────────
            Text('Schedule', style: AppTypography.bodySmall(context)),
            const SizedBox(height: AppSpacing.xs),

            ...{
              'week1': 'Week 1 — 1-2x daily (15-30 min)',
              'week2': 'Week 2 — Once daily / every other day',
              'week3': 'Week 3-4 — Every 2-3 days',
              'week4plus': 'Week 4+ — Weekly or as needed',
            }.entries.map((entry) {
              final selected = _schedule == entry.key;
              return GestureDetector(
                onTap: () {
                  setState(() => _schedule = entry.key);
                  _notify();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AppColors.curing : Colors.transparent,
                        border: Border.all(
                          color:
                              selected ? AppColors.curing : context.colTextMuted,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Center(
                              child: Icon(Icons.check,
                                  size: 10, color: Colors.black),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      entry.value,
                      style: AppTypography.bodySmall(context).copyWith(
                        color: selected
                            ? AppColors.curing
                            : context.colTextSecondary,
                      ),
                    ),
                  ]),
                ),
              );
            }),

            const SizedBox(height: AppSpacing.sm),

            // ── Time picker ───────────────────
            Text('Preferred Time', style: AppTypography.bodySmall(context)),
            const SizedBox(height: AppSpacing.xs),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.colSurface3,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(children: [
                  const Icon(Icons.access_time,
                      color: AppColors.curing, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text(_time.format(context),
                      style: AppTypography.bodyLarge(context)),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
