import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NutrientCalculatorScreen
//
// Stage-aware feeding guide + mix calculator.
//
// Sections:
//   1. Stage + medium selector (pre-filled when launched from plant context)
//   2. EC target — animated range bar + live status from current-EC input
//   3. pH target — same pattern, medium-aware
//   4. NPK profile — visual N:P:K bar showing ratio for current stage
//   5. Mix calculator — tank volume → ml of each 3-part component
//
// Usage:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => NutrientCalculatorScreen(
//       initialStage: plant.growStage,
//       initialMedium: plant.medium)));
// ─────────────────────────────────────────────────────────────────────────────

// ── Data tables ───────────────────────────────────────────────────────────────

class _EcRange {
  final double min;
  final double max;
  const _EcRange(this.min, this.max);
}

const _ecTargets = <GrowStage, _EcRange>{
  GrowStage.germination: _EcRange(0.2, 0.6),
  GrowStage.seedling:    _EcRange(0.4, 0.8),
  GrowStage.vegetative:  _EcRange(0.8, 1.4),
  GrowStage.stretch:     _EcRange(1.2, 1.8),
  GrowStage.earlyFlower: _EcRange(1.4, 2.0),
  GrowStage.lateFlower:  _EcRange(1.2, 1.8),
  GrowStage.flush:       _EcRange(0.0, 0.4),
};

class _PhRange {
  final double min;
  final double max;
  const _PhRange(this.min, this.max);
}

// Soil vs coco/hydro pH windows
const _phSoil = _PhRange(6.2, 7.0);
const _phCoco = _PhRange(5.5, 6.5);

// NPK ratio per stage — relative units (will be normalised for display)
class _Npk {
  final int n;
  final int p;
  final int k;
  const _Npk(this.n, this.p, this.k);
  int get total => n + p + k;
}

const _npkTargets = <GrowStage, _Npk>{
  GrowStage.germination: _Npk(1, 1, 1),
  GrowStage.seedling:    _Npk(2, 1, 1),
  GrowStage.vegetative:  _Npk(3, 1, 2),
  GrowStage.stretch:     _Npk(2, 2, 2),
  GrowStage.earlyFlower: _Npk(1, 3, 3),
  GrowStage.lateFlower:  _Npk(0, 3, 4),
  GrowStage.flush:       _Npk(0, 0, 0),
};

// 3-part mix ratios — ml per litre at base strength for each stage.
// Grow = N-rich, Bloom = PK booster, Micro = trace elements.
class _MixRatio {
  final double grow;
  final double bloom;
  final double micro;
  const _MixRatio(this.grow, this.bloom, this.micro);
}

const _mixRatios = <GrowStage, _MixRatio>{
  GrowStage.germination: _MixRatio(0.5, 0.0, 0.5),
  GrowStage.seedling:    _MixRatio(1.0, 0.0, 0.5),
  GrowStage.vegetative:  _MixRatio(3.0, 0.5, 1.0),
  GrowStage.stretch:     _MixRatio(2.0, 1.5, 1.0),
  GrowStage.earlyFlower: _MixRatio(1.0, 3.0, 1.0),
  GrowStage.lateFlower:  _MixRatio(0.0, 3.5, 1.0),
  GrowStage.flush:       _MixRatio(0.0, 0.0, 0.0),
};

// Stage tip — displayed below the NPK card.
const _stageTips = <GrowStage, String>{
  GrowStage.germination:
      'Keep nutrients minimal — seedlings are fragile. Plain pH-adjusted water or '
      'a very diluted seedling solution is usually enough.',
  GrowStage.seedling:
      'Introduce nutrients gradually. Watch for tip burn; if present, '
      'halve your EC until the plant adjusts.',
  GrowStage.vegetative:
      'High nitrogen drives canopy growth. Keep runoff pH above 6.0 in soil '
      'to avoid nutrient lockout.',
  GrowStage.stretch:
      'Transition period — begin phasing out nitrogen and ramping up '
      'phosphorus to support bud-site development.',
  GrowStage.earlyFlower:
      'Sites are forming — focus on phosphorus for root uptake and early '
      'bud development. Avoid excess N, which delays flowering.',
  GrowStage.lateFlower:
      'Potassium drives resin and terpene production. Drop nitrogen '
      'completely. Watch for purple/red stems — may indicate K deficiency.',
  GrowStage.flush:
      'Flush with plain pH-adjusted water to clear residual salts and improve '
      'final flavour. EC should drop toward 0 in runoff over the flush period.',
};

// ─────────────────────────────────────────────────────────────────────────────

class NutrientCalculatorScreen extends StatefulWidget {
  /// Pre-fill the stage selector when launched from a plant context.
  final GrowStage? initialStage;

  /// Pre-fill medium ('soil' | 'coco' | 'hydro' | 'living_soil').
  /// Coco, hydro, and living_soil all use the coco/hydro pH window.
  final String? initialMedium;

  const NutrientCalculatorScreen({
    super.key,
    this.initialStage,
    this.initialMedium,
  });

  @override
  State<NutrientCalculatorScreen> createState() =>
      _NutrientCalculatorScreenState();
}

class _NutrientCalculatorScreenState
    extends State<NutrientCalculatorScreen> {
  late GrowStage _stage;
  late bool _isSoil; // true = soil pH, false = coco/hydro pH

  final _ecCtrl   = TextEditingController();
  final _phCtrl   = TextEditingController();
  final _tankCtrl = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _stage  = widget.initialStage ?? GrowStage.vegetative;
    _isSoil = _mediumIsSoil(widget.initialMedium);
  }

  @override
  void dispose() {
    _ecCtrl.dispose();
    _phCtrl.dispose();
    _tankCtrl.dispose();
    super.dispose();
  }

  static bool _mediumIsSoil(String? medium) {
    if (medium == null) return true;
    return medium == 'soil' || medium == 'living_soil';
  }

  _EcRange get _ec => _ecTargets[_stage]!;
  _PhRange get _ph => _isSoil ? _phSoil : _phCoco;
  _Npk     get _npk => _npkTargets[_stage]!;
  _MixRatio get _mix => _mixRatios[_stage]!;

  // ── Status helpers ────────────────────────────────────────────────────────

  _RangeStatus _ecStatus() {
    final v = double.tryParse(_ecCtrl.text);
    if (v == null) return _RangeStatus.unknown;
    if (v < _ec.min) return _RangeStatus.low;
    if (v > _ec.max) return _RangeStatus.high;
    return _RangeStatus.ideal;
  }

  _RangeStatus _phStatus() {
    final v = double.tryParse(_phCtrl.text);
    if (v == null) return _RangeStatus.unknown;
    if (v < _ph.min) return _RangeStatus.low;
    if (v > _ph.max) return _RangeStatus.high;
    return _RangeStatus.ideal;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.science_rounded,
              color: AppColors.growing, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nutrient Calculator',
                style: AppTypography.headlineMedium(context)),
            Text('EC · pH · NPK · Mix',
                style: AppTypography.bodySmall(context)),
          ]),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.md,
          AppSpacing.pagePadding,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stage selector ───────────────────────────────────────────
            _sectionLabel('Grow Stage'),
            const SizedBox(height: AppSpacing.xs),
            _StageSelector(
              selected: _stage,
              onChanged: (s) => setState(() => _stage = s),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Medium selector ──────────────────────────────────────────
            _sectionLabel('Medium'),
            const SizedBox(height: AppSpacing.xs),
            Row(children: [
              _mediumChip('Soil / Living Soil', true),
              const SizedBox(width: AppSpacing.sm),
              _mediumChip('Coco / Hydro', false),
            ]),

            const SizedBox(height: AppSpacing.lg),

            // ── EC target ────────────────────────────────────────────────
            _EcCard(
              range: _ec,
              stage: _stage,
              controller: _ecCtrl,
              status: _ecStatus(),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── pH target ────────────────────────────────────────────────
            _PhCard(
              range: _ph,
              isSoil: _isSoil,
              controller: _phCtrl,
              status: _phStatus(),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── NPK profile ──────────────────────────────────────────────
            _NpkCard(npk: _npk, stage: _stage),

            const SizedBox(height: AppSpacing.xs),

            // Stage tip
            if (_stageTips[_stage] != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        color: AppColors.info, size: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _stageTips[_stage]!,
                        style: AppTypography.bodySmall(context).copyWith(
                          color: context.colTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.md),

            // ── Mix calculator ───────────────────────────────────────────
            _MixCalculatorCard(
              mix: _mix,
              stage: _stage,
              tankCtrl: _tankCtrl,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTypography.bodySmall(context)
            .copyWith(color: context.colTextMuted, fontWeight: FontWeight.w600),
      );

  Widget _mediumChip(String label, bool isSoil) {
    final sel = _isSoil == isSoil;
    const color = AppColors.growing;
    return GestureDetector(
      onTap: () => setState(() => _isSoil = isSoil),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.12) : context.colSurface2,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: sel ? color.withValues(alpha: 0.7) : context.colBorder,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall(context).copyWith(
            color: sel ? color : context.colTextSecondary,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage selector — horizontal scroll of stage chips with a progress track
// ─────────────────────────────────────────────────────────────────────────────

class _StageSelector extends StatelessWidget {
  final GrowStage selected;
  final ValueChanged<GrowStage> onChanged;

  const _StageSelector({required this.selected, required this.onChanged});

  static const _stages = GrowStage.values;

  static Color _stageColor(GrowStage s) {
    switch (s) {
      case GrowStage.germination:
      case GrowStage.seedling:
        return AppColors.growing;
      case GrowStage.vegetative:
        return AppColors.primary;
      case GrowStage.stretch:
      case GrowStage.earlyFlower:
        return AppColors.drying;
      case GrowStage.lateFlower:
        return AppColors.harvested;
      case GrowStage.flush:
        return AppColors.water;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _stages.map((s) {
          final sel = selected == s;
          final color = _stageColor(s);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel
                      ? color.withValues(alpha: 0.15)
                      : context.colSurface2,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: sel
                        ? color.withValues(alpha: 0.7)
                        : context.colBorder,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  s.shortLabel,
                  style: AppTypography.labelSmall(context).copyWith(
                    color: sel ? color : context.colTextSecondary,
                    fontWeight:
                        sel ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Range status enum
// ─────────────────────────────────────────────────────────────────────────────

enum _RangeStatus { unknown, low, ideal, high }

extension _RangeStatusExt on _RangeStatus {
  Color color(BuildContext context) {
    switch (this) {
      case _RangeStatus.unknown: return context.colTextMuted;
      case _RangeStatus.low:     return AppColors.water;
      case _RangeStatus.ideal:   return AppColors.optimal;
      case _RangeStatus.high:    return AppColors.danger;
    }
  }

  String label(String metric) {
    switch (this) {
      case _RangeStatus.unknown: return 'Enter your $metric';
      case _RangeStatus.low:     return 'Too low';
      case _RangeStatus.ideal:   return 'Ideal';
      case _RangeStatus.high:    return 'Too high';
    }
  }

  IconData get icon {
    switch (this) {
      case _RangeStatus.unknown: return Icons.edit_outlined;
      case _RangeStatus.low:     return Icons.arrow_downward_rounded;
      case _RangeStatus.ideal:   return Icons.check_circle_rounded;
      case _RangeStatus.high:    return Icons.arrow_upward_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared range bar widget
// ─────────────────────────────────────────────────────────────────────────────

class _RangeBar extends StatelessWidget {
  final double min;
  final double max;
  final double absMin;
  final double absMax;
  final double? currentValue;
  final Color color;

  const _RangeBar({
    required this.min,
    required this.max,
    required this.absMin,
    required this.absMax,
    required this.currentValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final span = absMax - absMin;
    final targetLeft  = (min - absMin) / span;
    final targetRight = (max - absMin) / span;

    double? markerPos;
    if (currentValue != null) {
      markerPos = ((currentValue! - absMin) / span).clamp(0.0, 1.0);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return SizedBox(
        height: 28,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Full track
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: context.colSurface3,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),
            // Target zone
            Positioned(
              left: w * targetLeft,
              width: w * (targetRight - targetLeft),
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),
            // Current value marker
            if (markerPos != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: (w * markerPos - 8).clamp(0.0, w - 16),
                top: 4,
                bottom: 4,
                child: Container(
                  width: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EC card
// ─────────────────────────────────────────────────────────────────────────────

class _EcCard extends StatelessWidget {
  final _EcRange range;
  final GrowStage stage;
  final TextEditingController controller;
  final _RangeStatus status;
  final ValueChanged<String> onChanged;

  const _EcCard({
    required this.range,
    required this.stage,
    required this.controller,
    required this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primary;
    return _Card(
      color: color,
      icon: Icons.bolt_rounded,
      title: 'EC Target',
      subtitle: '${range.min.toStringAsFixed(1)} – '
          '${range.max.toStringAsFixed(1)} mS/cm',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RangeBar(
            min: range.min,
            max: range.max,
            absMin: 0,
            absMax: 3.0,
            currentValue: double.tryParse(controller.text),
            color: color,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0.0',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 10)),
              Text('3.0 mS/cm',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: context.colTextPrimary),
                decoration: InputDecoration(
                  labelText: 'My current EC',
                  suffixText: 'mS/cm',
                  hintText: range.min.toStringAsFixed(1),
                  isDense: true,
                  prefixIcon: const Icon(Icons.bolt_rounded, size: 16),
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusBadge(status: status, metric: 'EC'),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// pH card
// ─────────────────────────────────────────────────────────────────────────────

class _PhCard extends StatelessWidget {
  final _PhRange range;
  final bool isSoil;
  final TextEditingController controller;
  final _RangeStatus status;
  final ValueChanged<String> onChanged;

  const _PhCard({
    required this.range,
    required this.isSoil,
    required this.controller,
    required this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.water;
    return _Card(
      color: color,
      icon: Icons.water_drop_rounded,
      title: 'pH Target',
      subtitle: '${range.min.toStringAsFixed(1)} – '
          '${range.max.toStringAsFixed(1)} '
          '(${isSoil ? 'soil' : 'coco / hydro'})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RangeBar(
            min: range.min,
            max: range.max,
            absMin: 4.0,
            absMax: 8.5,
            currentValue: double.tryParse(controller.text),
            color: color,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('4.0',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 10)),
              Text('8.5',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: context.colTextPrimary),
                decoration: InputDecoration(
                  labelText: 'My current pH',
                  hintText: range.min.toStringAsFixed(1),
                  isDense: true,
                  prefixIcon:
                      const Icon(Icons.water_drop_rounded, size: 16),
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusBadge(status: status, metric: 'pH'),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NPK profile card
// ─────────────────────────────────────────────────────────────────────────────

class _NpkCard extends StatelessWidget {
  final _Npk npk;
  final GrowStage stage;

  const _NpkCard({required this.npk, required this.stage});

  @override
  Widget build(BuildContext context) {
    final isFlush = stage == GrowStage.flush;
    return _Card(
      color: AppColors.growing,
      icon: Icons.bar_chart_rounded,
      title: 'NPK Profile',
      subtitle: isFlush
          ? 'Flush — plain water only'
          : 'N : P : K = ${npk.n} : ${npk.p} : ${npk.k}',
      child: isFlush
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                'No nutrients — flush with plain pH-adjusted water only.',
                style: AppTypography.bodySmall(context)
                    .copyWith(color: context.colTextSecondary),
              ),
            )
          : Column(
              children: [
                _NpkBar(
                  label: 'N — Nitrogen',
                  value: npk.n,
                  total: math.max(npk.total, 1),
                  color: AppColors.growing,
                ),
                const SizedBox(height: AppSpacing.xs),
                _NpkBar(
                  label: 'P — Phosphorus',
                  value: npk.p,
                  total: math.max(npk.total, 1),
                  color: AppColors.drying,
                ),
                const SizedBox(height: AppSpacing.xs),
                _NpkBar(
                  label: 'K — Potassium',
                  value: npk.k,
                  total: math.max(npk.total, 1),
                  color: AppColors.secondary,
                ),
              ],
            ),
    );
  }
}

class _NpkBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _NpkBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = value / total;
    final pct = (fraction * 100).round();
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: AppTypography.bodySmall(context)
                  .copyWith(fontSize: 11)),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: context.colSurface3,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                widthFactor: fraction,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 32,
          child: Text(
            value == 0 ? '—' : '$pct%',
            style: AppTypography.labelSmall(context).copyWith(
              color: value == 0 ? context.colTextMuted : color,
              fontSize: 11,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mix calculator card
// ─────────────────────────────────────────────────────────────────────────────

class _MixCalculatorCard extends StatelessWidget {
  final _MixRatio mix;
  final GrowStage stage;
  final TextEditingController tankCtrl;
  final ValueChanged<String> onChanged;

  const _MixCalculatorCard({
    required this.mix,
    required this.stage,
    required this.tankCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFlush = stage == GrowStage.flush;
    final litres = double.tryParse(tankCtrl.text) ?? 0;

    final growMl  = mix.grow  * litres;
    final bloomMl = mix.bloom * litres;
    final microMl = mix.micro * litres;

    return _Card(
      color: AppColors.accent,
      icon: Icons.calculate_rounded,
      title: 'Mix Calculator',
      subtitle: '3-part system · per-litre base doses',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tank volume input
          TextField(
            controller: tankCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: context.colTextPrimary),
            decoration: const InputDecoration(
              labelText: 'Tank / reservoir volume',
              suffixText: 'litres',
              isDense: true,
              prefixIcon: Icon(Icons.water_rounded, size: 16),
            ),
            onChanged: onChanged,
          ),

          const SizedBox(height: AppSpacing.md),

          if (isFlush)
            Text(
              'Flush stage — no nutrients. Use plain water only.',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted),
            )
          else if (litres <= 0)
            Text(
              'Enter your tank volume above.',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted),
            )
          else ...[
            // Results table
            _MixRow(
              label: 'Grow (A)',
              sublabel: 'N-rich base',
              mlPerLitre: mix.grow,
              totalMl: growMl,
              color: AppColors.growing,
            ),
            const SizedBox(height: AppSpacing.xs),
            _MixRow(
              label: 'Bloom (B)',
              sublabel: 'PK booster',
              mlPerLitre: mix.bloom,
              totalMl: bloomMl,
              color: AppColors.drying,
            ),
            const SizedBox(height: AppSpacing.xs),
            _MixRow(
              label: 'Micro (C)',
              sublabel: 'Trace elements',
              mlPerLitre: mix.micro,
              totalMl: microMl,
              color: AppColors.secondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.colSurface2,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: context.colBorder),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: context.colTextMuted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Doses above are for a generic 3-part system at '
                    'standard strength. Halve for seedlings or sensitive '
                    'plants. Always pH-adjust after mixing.',
                    style: AppTypography.bodySmall(context).copyWith(
                      color: context.colTextMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _MixRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final double mlPerLitre;
  final double totalMl;
  final Color color;

  const _MixRow({
    required this.label,
    required this.sublabel,
    required this.mlPerLitre,
    required this.totalMl,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = mlPerLitre > 0;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: hasValue
            ? color.withValues(alpha: 0.07)
            : context.colSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: hasValue
              ? color.withValues(alpha: 0.3)
              : context.colBorder,
        ),
      ),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasValue ? color : context.colTextMuted,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTypography.labelLarge(context)
                      .copyWith(fontSize: 13)),
              Text(sublabel,
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 11)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              hasValue
                  ? '${totalMl.toStringAsFixed(1)} ml'
                  : '—',
              style: AppTypography.labelLarge(context).copyWith(
                color: hasValue ? color : context.colTextMuted,
                fontSize: 15,
              ),
            ),
            Text(
              hasValue
                  ? '${mlPerLitre.toStringAsFixed(1)} ml/L'
                  : 'not used',
              style: AppTypography.bodySmall(context).copyWith(
                color: context.colTextMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge (Ideal / Too low / Too high)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final _RangeStatus status;
  final String metric;

  const _StatusBadge({required this.status, required this.metric});

  @override
  Widget build(BuildContext context) {
    final color = status.color(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: color, size: 13),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            status.label(metric),
            style: AppTypography.labelSmall(context).copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card shell
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _Card({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
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
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: AppTypography.labelLarge(context)
                      .copyWith(fontSize: 13)),
              Text(subtitle,
                  style: AppTypography.bodySmall(context).copyWith(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
            ]),
          ]),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
