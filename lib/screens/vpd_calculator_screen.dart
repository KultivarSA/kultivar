import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/temp_format.dart';

/// Stage-specific VPD target bands (kPa).
const Map<GrowStage, _VpdBand> _stageBands = {
  GrowStage.germination:  _VpdBand(0.4, 0.8,  'Seedling / Germination'),
  GrowStage.seedling:     _VpdBand(0.4, 0.8,  'Seedling / Germination'),
  GrowStage.vegetative:   _VpdBand(0.8, 1.2,  'Vegetative'),
  GrowStage.stretch:      _VpdBand(1.0, 1.6,  'Stretch / Early Flower'),
  GrowStage.earlyFlower:  _VpdBand(1.0, 1.6,  'Stretch / Early Flower'),
  GrowStage.lateFlower:   _VpdBand(1.2, 1.6,  'Late Flower / Flush'),
  GrowStage.flush:        _VpdBand(1.2, 1.6,  'Late Flower / Flush'),
};

class _VpdBand {
  final double low;
  final double high;
  final String label;
  const _VpdBand(this.low, this.high, this.label);
}

/// Calculates VPD in kPa from air temperature (°C) and relative humidity.
double _calcVpd(double tempC, double humidity) {
  final svp = 0.6108 * exp(17.27 * tempC / (tempC + 237.3));
  return svp * (1 - humidity / 100);
}

/// Colour-codes a VPD value given target band [low]–[high].
Color _calcVpdColor(double vpd, double low, double high) {
  if (vpd < low * 0.75)  return const Color(0xFF2979FF); // deep blue — very low
  if (vpd < low)         return const Color(0xFF64B5F6); // light blue — low
  if (vpd <= high)       return AppColors.optimal;        // green — ideal
  if (vpd <= high * 1.2) return AppColors.warning;        // amber — slightly high
  return AppColors.danger;                                 // red — too high
}

// ─────────────────────────────────────────────────────────────────────────────

class VpdCalculatorScreen extends StatefulWidget {
  /// Optional: pre-seed the sliders with current space readings.
  final double? initialTempC;
  final double? initialHumidity;

  const VpdCalculatorScreen({
    super.key,
    this.initialTempC,
    this.initialHumidity,
  });

  @override
  State<VpdCalculatorScreen> createState() => _VpdCalculatorScreenState();
}

class _VpdCalculatorScreenState extends State<VpdCalculatorScreen> {
  late double _tempC;
  late double _humidity;
  GrowStage? _stage;

  @override
  void initState() {
    super.initState();
    _tempC    = widget.initialTempC  ?? 24.0;
    _humidity = widget.initialHumidity ?? 55.0;
  }

  _VpdBand get _currentBand =>
      _stage != null ? _stageBands[_stage]! : const _VpdBand(0.4, 1.6, 'General');

  double get _vpd => _calcVpd(_tempC, _humidity);

  String get _vpdLabel {
    final v = _vpd;
    final b = _currentBand;
    if (v < b.low)  return 'Too Low';
    if (v <= b.high) return 'In Range';
    return 'Too High';
  }

  Color get _vpdColor => _calcVpdColor(_vpd, _currentBand.low, _currentBand.high);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('VPD Calculator',
            style: AppTypography.headlineMedium(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stage selector ────────────────
            _stageSelector(context),
            const SizedBox(height: AppSpacing.lg),

            // ── Live VPD display ──────────────
            _vpdDisplay(context),
            const SizedBox(height: AppSpacing.lg),

            // ── Sliders ───────────────────────
            _sliderCard(context),
            const SizedBox(height: AppSpacing.lg),

            // ── Heat map ──────────────────────
            _heatMap(context),
            const SizedBox(height: AppSpacing.lg),

            // ── Reference table ───────────────
            _referenceTable(context),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ── Stage selector ─────────────────────────────

  Widget _stageSelector(BuildContext context) {
    final stages = [
      (null,                  'All Stages'),
      (GrowStage.seedling,    'Seedling'),
      (GrowStage.vegetative,  'Veg'),
      (GrowStage.earlyFlower, 'Flower'),
      (GrowStage.lateFlower,  'Late Flower'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Growth Stage',
            style: AppTypography.labelSmall(context)
                .copyWith(color: context.colTextMuted, letterSpacing: 1.1)),
        const SizedBox(height: AppSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: stages.map((s) {
              final selected = _stage == s.$1;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: GestureDetector(
                  onTap: () => setState(() => _stage = s.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : context.colSurface2,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : context.colBorder,
                      ),
                    ),
                    child: Text(
                      s.$2,
                      style: AppTypography.labelSmall(context).copyWith(
                        color: selected
                            ? Colors.black
                            : context.colTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Big VPD readout ────────────────────────────

  Widget _vpdDisplay(BuildContext context) {
    final vpd   = _vpd;
    final band  = _currentBand;
    final color = _vpdColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          // Current VPD value
          Text(
            '${vpd.toStringAsFixed(2)} kPa',
            style: AppTypography.displayMedium(context)
                .copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _vpdLabel,
            style: AppTypography.headlineSmall(context)
                .copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Stage band target
          Text(
            'Target for ${band.label}: '
            '${band.low.toStringAsFixed(1)}–${band.high.toStringAsFixed(1)} kPa',
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Progress bar within band
          _bandProgressBar(context, vpd, band.low, band.high, color),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(band.low.toStringAsFixed(1),
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 9)),
              Text('${band.high.toStringAsFixed(1)} kPa',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bandProgressBar(BuildContext context, double vpd,
      double low, double high, Color color) {
    // Map vpd to 0.0–1.0 across a display range 0.0–2.0 kPa.
    const displayMax = 2.0;
    final frac = (vpd / displayMax).clamp(0.0, 1.0);
    final lowFrac  = (low / displayMax).clamp(0.0, 1.0);
    final highFrac = (high / displayMax).clamp(0.0, 1.0);

    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      return Stack(
        children: [
          // Track
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: context.colSurface3,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          ),
          // Ideal band highlight
          Positioned(
            left: w * lowFrac,
            width: w * (highFrac - lowFrac),
            top: 0,
            height: 8,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.optimal.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),
          // Current position thumb
          Positioned(
            left: (w * frac - 5).clamp(0.0, w - 10),
            top: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: context.colSurface1, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  // ── Sliders ────────────────────────────────────

  Widget _sliderCard(BuildContext context) {
    final displayTemp = fromStorageTemp(_tempC);
    final minDisplayTemp = fromStorageTemp(15.0);
    final maxDisplayTemp = fromStorageTemp(35.0);

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
          // ── Temperature ─────────────────────
          Row(
            children: [
              const Icon(Icons.thermostat_rounded,
                  size: 16, color: AppColors.ipmColor),
              const SizedBox(width: AppSpacing.xs),
              Text('Temperature',
                  style: AppTypography.labelLarge(context)),
              const Spacer(),
              Text(
                '${displayTemp.toStringAsFixed(1)}$tempUnitSuffix',
                style: AppTypography.headlineSmall(context)
                    .copyWith(color: AppColors.ipmColor),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.ipmColor,
              thumbColor: AppColors.ipmColor,
              inactiveTrackColor:
                  AppColors.ipmColor.withValues(alpha: 0.2),
              overlayColor: AppColors.ipmColor.withValues(alpha: 0.1),
              trackHeight: 3,
            ),
            child: Slider(
              value: displayTemp.clamp(minDisplayTemp, maxDisplayTemp),
              min: minDisplayTemp,
              max: maxDisplayTemp,
              divisions: KultivarApp.useFahrenheitNotifier.value ? 40 : 20,
              onChanged: (v) {
                setState(() => _tempC = toStorageTemp(v));
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${minDisplayTemp.toStringAsFixed(0)}$tempUnitSuffix',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 9)),
              Text('${maxDisplayTemp.toStringAsFixed(0)}$tempUnitSuffix',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 9)),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          Divider(color: context.colBorder),
          const SizedBox(height: AppSpacing.sm),

          // ── Humidity ─────────────────────────
          Row(
            children: [
              const Icon(Icons.water_drop_rounded,
                  size: 16, color: AppColors.water),
              const SizedBox(width: AppSpacing.xs),
              Text('Humidity', style: AppTypography.labelLarge(context)),
              const Spacer(),
              Text(
                '${_humidity.toStringAsFixed(0)}%',
                style: AppTypography.headlineSmall(context)
                    .copyWith(color: AppColors.water),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.water,
              thumbColor: AppColors.water,
              inactiveTrackColor:
                  AppColors.water.withValues(alpha: 0.2),
              overlayColor: AppColors.water.withValues(alpha: 0.1),
              trackHeight: 3,
            ),
            child: Slider(
              value: _humidity,
              min: 20,
              max: 90,
              divisions: 70,
              onChanged: (v) => setState(() => _humidity = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('20%',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 9)),
              Text('90%',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  // ── VPD Heat map ───────────────────────────────
  //
  // Grid: rows = temperature (15→35°C, step 2), cols = humidity (30→80%, step 5).
  // Current slider position gets a white border marker.

  Widget _heatMap(BuildContext context) {
    const temps = [35.0, 33.0, 31.0, 29.0, 27.0, 25.0, 23.0, 21.0, 19.0, 17.0, 15.0];
    const hums  = [30.0, 35.0, 40.0, 45.0, 50.0, 55.0, 60.0, 65.0, 70.0, 75.0, 80.0];
    final band  = _currentBand;

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
          Row(
            children: [
              const Icon(Icons.grid_view_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text('VPD Heat Map',
                  style: AppTypography.headlineSmall(context)),
              const Spacer(),
              // Legend
              ...[
                ('Too Low',    const Color(0xFF64B5F6)),
                ('Ideal',      AppColors.optimal),
                ('Too High',   AppColors.danger),
              ].map((l) => Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: l.$2,
                              borderRadius:
                                  BorderRadius.circular(2),
                            )),
                        const SizedBox(width: 3),
                        Text(l.$1,
                            style: AppTypography.labelSmall(context)
                                .copyWith(
                                    color: context.colTextMuted,
                                    fontSize: 8)),
                      ],
                    ),
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Humidity axis header
          Row(
            children: [
              const SizedBox(width: AppSpacing.xl), // space for temp labels
              ...hums.map((h) => Expanded(
                    child: Center(
                      child: Text(
                        '${h.toInt()}',
                        style: AppTypography.labelSmall(context).copyWith(
                            color: context.colTextMuted, fontSize: 7),
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 2),

          // Grid rows
          ...temps.map((t) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  // Temp label
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${fromStorageTemp(t).toStringAsFixed(0)}°',
                      style: AppTypography.labelSmall(context).copyWith(
                          color: context.colTextMuted, fontSize: 7),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 2),
                  // Cells
                  ...hums.map((h) {
                    final v = _calcVpd(t, h);
                    final col = _calcVpdColor(v, band.low, band.high);
                    // Highlight the nearest cell to current slider values.
                    final nearestTemp = temps.reduce((a, b) =>
                        (a - _tempC).abs() < (b - _tempC).abs() ? a : b);
                    final nearestHum = hums.reduce((a, b) =>
                        (a - _humidity).abs() < (b - _humidity).abs() ? a : b);
                    final isCurrent =
                        t == nearestTemp && h == nearestHum;

                    return Expanded(
                      child: Container(
                        height: 22,
                        margin: const EdgeInsets.only(right: 1),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(2),
                          border: isCurrent
                              ? Border.all(
                                  color: Colors.white,
                                  width: 1.5)
                              : null,
                        ),
                        child: isCurrent
                            ? const Icon(Icons.circle,
                                size: 5, color: Colors.white)
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          const SizedBox(height: AppSpacing.xxs),
          // Humidity axis label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('← Humidity (%)',
                  style: AppTypography.labelSmall(context).copyWith(
                      color: context.colTextMuted, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Reference table ────────────────────────────

  Widget _referenceTable(BuildContext context) {
    const rows = [
      _RefRow('Germination / Seedling',  '20–25°C',  '65–80%',  '0.4–0.8'),
      _RefRow('Vegetative',              '22–28°C',  '50–70%',  '0.8–1.2'),
      _RefRow('Stretch / Early Flower',  '22–28°C',  '40–60%',  '1.0–1.6'),
      _RefRow('Late Flower / Flush',     '20–26°C',  '40–50%',  '1.2–1.6'),
      _RefRow('Drying (post-harvest)',   '18–22°C',  '45–55%',  '—'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.colBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Text('Stage Reference',
                    style: AppTypography.headlineSmall(context)),
              ],
            ),
          ),
          Divider(height: 1, color: context.colBorder),
          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text('Stage',
                      style: AppTypography.labelSmall(context).copyWith(
                          color: context.colTextMuted, fontSize: 10)),
                ),
                SizedBox(
                  width: 60,
                  child: Text('Temp',
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall(context).copyWith(
                          color: context.colTextMuted, fontSize: 10)),
                ),
                SizedBox(
                  width: 56,
                  child: Text('RH',
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall(context).copyWith(
                          color: context.colTextMuted, fontSize: 10)),
                ),
                SizedBox(
                  width: 52,
                  child: Text('VPD kPa',
                      textAlign: TextAlign.right,
                      style: AppTypography.labelSmall(context).copyWith(
                          color: context.colTextMuted, fontSize: 10)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colBorder),
          // Rows
          ...rows.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            return Column(
              children: [
                if (i > 0) Divider(height: 1, color: context.colBorder),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(r.stage,
                            style: AppTypography.bodySmall(context)
                                .copyWith(fontSize: 11)),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          KultivarApp.useFahrenheitNotifier.value
                              ? _convertTempRange(r.tempC)
                              : r.tempC,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall(context)
                              .copyWith(fontSize: 11),
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(r.rh,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall(context)
                                .copyWith(fontSize: 11)),
                      ),
                      SizedBox(
                        width: 52,
                        child: Text(r.vpd,
                            textAlign: TextAlign.right,
                            style: AppTypography.labelLarge(context)
                                .copyWith(
                                    color: AppColors.primary,
                                    fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// Converts a "X–Y°C" string to °F when Fahrenheit is active.
  String _convertTempRange(String rangeC) {
    final parts = rangeC.replaceAll('°C', '').split('–');
    if (parts.length != 2) return rangeC;
    final lo = double.tryParse(parts[0].trim());
    final hi = double.tryParse(parts[1].trim());
    if (lo == null || hi == null) return rangeC;
    final loF = (lo * 9 / 5 + 32).round();
    final hiF = (hi * 9 / 5 + 32).round();
    return '$loF–$hiF°F';
  }
}

// ── Reference row ──────────────────────────────────

class _RefRow {
  final String stage;
  final String tempC;
  final String rh;
  final String vpd;
  const _RefRow(this.stage, this.tempC, this.rh, this.vpd);
}
