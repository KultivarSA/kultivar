import 'dart:math';

import 'package:flutter/material.dart';

import '../models/grow_space.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/temp_format.dart';

class EnvironmentThresholdEditor extends StatefulWidget {
  final GrowSpace space;
  final void Function(GrowSpace updated) onSaved;

  const EnvironmentThresholdEditor({
    super.key,
    required this.space,
    required this.onSaved,
  });

  @override
  State<EnvironmentThresholdEditor> createState() =>
      _EnvironmentThresholdEditorState();
}

class _EnvironmentThresholdEditorState
    extends State<EnvironmentThresholdEditor> {
  late double _tempMin;
  late double _tempMax;
  late double _humMin;
  late double _humMax;

  @override
  void initState() {
    super.initState();
    _tempMin = widget.space.tempMin;
    _tempMax = widget.space.tempMax;
    _humMin = widget.space.humidityMin;
    _humMax = widget.space.humidityMax;
  }

  /// True when the slider values differ from the last-saved space values.
  bool get _isDirty =>
      _tempMin != widget.space.tempMin ||
      _tempMax != widget.space.tempMax ||
      _humMin != widget.space.humidityMin ||
      _humMax != widget.space.humidityMax;

  double _computeVpd(double temp, double humidity) {
    final svp = 0.6108 * exp(17.27 * temp / (temp + 237.3));
    return svp * (1 - humidity / 100);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.colBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Optimal Ranges',
                  style: AppTypography.headlineSmall(context)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge fades in/out as the user drags the sliders.
                  AnimatedOpacity(
                    opacity: _isDirty ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Unsaved',
                        style: AppTypography.labelSmall(context)
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.onSaved(widget.space.copyWith(
                        tempMin: _tempMin,
                        tempMax: _tempMax,
                        humidityMin: _humMin,
                        humidityMax: _humMax,
                      ));
                    },
                    child: Text('Save',
                        style: AppTypography.labelLarge(context)
                            .copyWith(color: AppColors.primary)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Temperature — slider operates in the user's display unit;
          // _tempMin/_tempMax are always stored as Celsius internally.
          _rangeRow(
            icon: Icons.thermostat,
            label: 'Temperature',
            unit: tempUnitSuffix,
            color: Colors.orange,
            min: fromStorageTemp(_tempMin),
            max: fromStorageTemp(_tempMax),
            absoluteMin: fromStorageTemp(0),
            absoluteMax: fromStorageTemp(45),
            onMinChanged: (v) => setState(() => _tempMin = toStorageTemp(v)),
            onMaxChanged: (v) => setState(() => _tempMax = toStorageTemp(v)),
          ),
          const SizedBox(height: AppSpacing.md),

          // Humidity
          _rangeRow(
            icon: Icons.water_drop,
            label: 'Humidity',
            unit: '%',
            color: Colors.blue,
            min: _humMin,
            max: _humMax,
            absoluteMin: 0,
            absoluteMax: 100,
            onMinChanged: (v) => setState(() => _humMin = v),
            onMaxChanged: (v) => setState(() => _humMax = v),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Computed VPD range ───────────────
          Builder(builder: (context) {
            final vpdLow = _computeVpd(_tempMin, _humMax);
            final vpdHigh = _computeVpd(_tempMax, _humMin);
            final inRange = vpdLow >= 0.4 && vpdHigh <= 1.6;
            final vpdColor = inRange ? AppColors.optimal : AppColors.warning;
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: vpdColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: vpdColor.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.air_rounded, color: vpdColor, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text('Est. VPD range', style: AppTypography.bodySmall(context)),
                const Spacer(),
                Text(
                  '${vpdLow.toStringAsFixed(2)}–'
                  '${vpdHigh.toStringAsFixed(2)} kPa',
                  style: AppTypography.labelLarge(context)
                      .copyWith(color: vpdColor),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: vpdColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    inRange ? 'Good' : 'Check',
                    style: AppTypography.labelSmall(context)
                        .copyWith(color: vpdColor),
                  ),
                ),
              ]),
            );
          }),

          const SizedBox(height: AppSpacing.md),

          // ── Presets ──────────────────────────
          Divider(color: context.colBorder),
          const SizedBox(height: AppSpacing.sm),
          Text('Quick Presets',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              return ActionChip(
                avatar: Icon(p.icon, color: p.color, size: 14),
                label: Text(p.label,
                    style: AppTypography.labelSmall(context)
                        .copyWith(color: p.color)),
                onPressed: () => setState(() {
                  _tempMin = p.tempMin;
                  _tempMax = p.tempMax;
                  _humMin = p.humMin;
                  _humMax = p.humMax;
                }),
                backgroundColor: p.color.withValues(alpha: 0.1),
                side: BorderSide(color: p.color.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _rangeRow({
    required IconData icon,
    required String label,
    required String unit,
    required Color color,
    required double min,
    required double max,
    required double absoluteMin,
    required double absoluteMax,
    required void Function(double) onMinChanged,
    required void Function(double) onMaxChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTypography.labelLarge(context)),
          const Spacer(),
          Text(
            '${min.toStringAsFixed(0)}$unit — '
            '${max.toStringAsFixed(0)}$unit',
            style: AppTypography.bodyMedium(context).copyWith(color: color),
          ),
        ]),
        const SizedBox(height: AppSpacing.xs),
        RangeSlider(
          values: RangeValues(min, max),
          min: absoluteMin,
          max: absoluteMax,
          divisions: (absoluteMax - absoluteMin).toInt(),
          activeColor: color,
          inactiveColor: context.colSurface3,
          onChanged: (v) {
            onMinChanged(v.start);
            onMaxChanged(v.end);
          },
        ),
      ],
    );
  }

  static const _presets = [
    _Preset('Seedling', 20, 25, 65, 75, AppColors.completed, Icons.eco_rounded),
    _Preset('Veg', 20, 28, 50, 70, AppColors.growing, Icons.grass_rounded),
    _Preset('Flower', 18, 26, 40, 50, AppColors.curing,
        Icons.local_florist_rounded),
    _Preset('Late Flower', 18, 24, 30, 40, AppColors.harvested,
        Icons.wb_sunny_rounded),
    _Preset('Drying', 18, 24, 45, 55, AppColors.drying, Icons.air_rounded),
    _Preset('Curing', 15, 21, 55, 65, AppColors.secondary,
        Icons.inventory_2_rounded),
  ];
}

class _Preset {
  final String label;
  final double tempMin, tempMax, humMin, humMax;
  final Color color;
  final IconData icon;

  const _Preset(this.label, this.tempMin, this.tempMax, this.humMin,
      this.humMax, this.color, this.icon);
}
