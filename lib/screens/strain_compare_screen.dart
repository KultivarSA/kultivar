import 'package:flutter/material.dart';

import '../data/strain_library.dart';
import '../models/strain.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ── Helper: convert a BuiltInStrain into a transient Strain for display ───────

Strain strainFromBuiltIn(BuiltInStrain b) => Strain(
      id: 'catalog:${b.name.toLowerCase()}',
      name: b.name,
      genetics: b.lineage ?? '',
      type: b.type,
      isAutoflower: b.isAutoflower,
      breeder: b.breeder,
      expectedFlowerDays: b.flowerDays,
      flowerWeeksMin: b.flowerWeeksMin,
      flowerWeeksMax: b.flowerWeeksMax,
      stretchFactor: b.stretchFactor,
      heightCmMin: b.heightCmMin,
      heightCmMax: b.heightCmMax,
      yieldGPerM2Min: b.yieldGPerM2Min,
      yieldGPerM2Max: b.yieldGPerM2Max,
      vegTargets: b.vegTargets,
      earlyFlowerTargets: b.earlyFlowerTargets,
      lateFlowerTargets: b.lateFlowerTargets,
      feedingIntensity: b.feedingIntensity,
      phMin: b.phMin,
      phMax: b.phMax,
      ecVegMin: b.ecVegMin,
      ecVegMax: b.ecVegMax,
      ecFlowerMin: b.ecFlowerMin,
      ecFlowerMax: b.ecFlowerMax,
      recommendedTraining: b.training,
      thcPctMin: b.thcPctMin,
      thcPctMax: b.thcPctMax,
      cbdPctMin: b.cbdPctMin,
      cbdPctMax: b.cbdPctMax,
      terpenes: b.terpenes,
      cureWeeksMin: b.cureWeeksMin,
      cureWeeksMax: b.cureWeeksMax,
      createdAt: DateTime.now(),
    );

// ── Screen ────────────────────────────────────────────────────────────────────

/// Side-by-side comparison of two strains.
///
/// Both strains are passed as [Strain] objects; use [strainFromBuiltIn] to
/// convert catalog entries before pushing this screen.
class StrainCompareScreen extends StatelessWidget {
  final Strain strainA;
  final Strain strainB;

  const StrainCompareScreen({
    super.key,
    required this.strainA,
    required this.strainB,
  });

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Color _typeColor(String type) {
    switch (type) {
      case 'Indica':
        return AppColors.curing;
      case 'Sativa':
        return AppColors.harvested;
      default:
        return AppColors.growing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorA = _typeColor(strainA.type);
    final colorB = _typeColor(strainB.type);

    return Scaffold(
      appBar: AppBar(
        title: Text('Compare Strains',
            style: AppTypography.headlineMedium(context)),
      ),
      body: Column(
        children: [
          // ── Sticky header row ──────────────────────────────────────────────
          _HeaderRow(strainA: strainA, strainB: strainB,
              colorA: colorA, colorB: colorB),

          // ── Scrollable comparison table ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  bottom: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── GENETICS ────────────────────────────────────────────
                  const _SectionHeader(label: 'GENETICS'),
                  _textRow(context, 'Lineage',
                      a: strainA.genetics.isEmpty ? '—' : strainA.genetics,
                      b: strainB.genetics.isEmpty ? '—' : strainB.genetics),
                  _textRow(context, 'Breeder',
                      a: strainA.breeder ?? '—',
                      b: strainB.breeder ?? '—'),
                  _textRow(context, 'Type',
                      a: strainA.type + (strainA.isAutoflower ? ' · Auto' : ''),
                      b: strainB.type + (strainB.isAutoflower ? ' · Auto' : ''),
                      colorA: colorA, colorB: colorB),

                  // ── GROWTH ──────────────────────────────────────────────
                  const _SectionHeader(label: 'GROWTH TIMELINE'),
                  _numericRow(context, 'Flower Time',
                      aLabel: strainA.flowerTimeLabel,
                      bLabel: strainB.flowerTimeLabel,
                      aVal: strainA.flowerWeeksMax?.toDouble() ??
                          strainA.expectedFlowerDays?.toDouble(),
                      bVal: strainB.flowerWeeksMax?.toDouble() ??
                          strainB.expectedFlowerDays?.toDouble(),
                      lowerIsBetter: true),
                  _rangeRow(context, 'Height',
                      aMin: strainA.heightCmMin,
                      aMax: strainA.heightCmMax,
                      bMin: strainB.heightCmMin,
                      bMax: strainB.heightCmMax,
                      unit: 'cm'),
                  _rangeRow(context, 'Yield',
                      aMin: strainA.yieldGPerM2Min,
                      aMax: strainA.yieldGPerM2Max,
                      bMin: strainB.yieldGPerM2Min,
                      bMax: strainB.yieldGPerM2Max,
                      unit: 'g/m²',
                      winnerIsHigher: true),
                  _doubleRow(context, 'Stretch',
                      aVal: strainA.stretchFactor,
                      bVal: strainB.stretchFactor,
                      format: (v) => '${v.toStringAsFixed(1)}×'),
                  _rangeRow(context, 'Cure',
                      aMin: strainA.cureWeeksMin,
                      aMax: strainA.cureWeeksMax,
                      bMin: strainB.cureWeeksMin,
                      bMax: strainB.cureWeeksMax,
                      unit: 'wks',
                      lowerIsBetter: true),

                  // ── POTENCY ─────────────────────────────────────────────
                  const _SectionHeader(label: 'POTENCY'),
                  _rangeRow(context, 'THC',
                      aMin: strainA.thcPctMin?.toInt(),
                      aMax: strainA.thcPctMax?.toInt(),
                      bMin: strainB.thcPctMin?.toInt(),
                      bMax: strainB.thcPctMax?.toInt(),
                      unit: '%',
                      winnerIsHigher: true),
                  _rangeRow(context, 'CBD',
                      aMin: strainA.cbdPctMin?.toInt(),
                      aMax: strainA.cbdPctMax?.toInt(),
                      bMin: strainB.cbdPctMin?.toInt(),
                      bMax: strainB.cbdPctMax?.toInt(),
                      unit: '%'),

                  // ── FEEDING ─────────────────────────────────────────────
                  const _SectionHeader(label: 'FEEDING'),
                  _textRow(context, 'Intensity',
                      a: _feedingLabel(strainA.feedingIntensity),
                      b: _feedingLabel(strainB.feedingIntensity),
                      aWins: _feedingScore(strainA.feedingIntensity) <
                          _feedingScore(strainB.feedingIntensity),
                      bWins: _feedingScore(strainB.feedingIntensity) <
                          _feedingScore(strainA.feedingIntensity)),
                  _rangeRowDouble(context, 'pH',
                      aMin: strainA.phMin,
                      aMax: strainA.phMax,
                      bMin: strainB.phMin,
                      bMax: strainB.phMax,
                      decimals: 1),
                  _rangeRowDouble(context, 'EC Veg',
                      aMin: strainA.ecVegMin,
                      aMax: strainA.ecVegMax,
                      bMin: strainB.ecVegMin,
                      bMax: strainB.ecVegMax,
                      decimals: 1,
                      unit: 'mS'),
                  _rangeRowDouble(context, 'EC Flower',
                      aMin: strainA.ecFlowerMin,
                      aMax: strainA.ecFlowerMax,
                      bMin: strainB.ecFlowerMin,
                      bMax: strainB.ecFlowerMax,
                      decimals: 1,
                      unit: 'mS'),

                  // ── TERPENES ─────────────────────────────────────────────
                  if (strainA.terpenes.isNotEmpty ||
                      strainB.terpenes.isNotEmpty) ...[
                    const _SectionHeader(label: 'TERPENES'),
                    _pillRow(context,
                        aItems: strainA.terpenes,
                        bItems: strainB.terpenes,
                        sharedColor: AppColors.primary),
                  ],

                  // ── TRAINING ─────────────────────────────────────────────
                  if (strainA.recommendedTraining.isNotEmpty ||
                      strainB.recommendedTraining.isNotEmpty) ...[
                    const _SectionHeader(label: 'TRAINING'),
                    _pillRow(context,
                        aItems: strainA.recommendedTraining
                            .map(_trainingLabel)
                            .toList(),
                        bItems: strainB.recommendedTraining
                            .map(_trainingLabel)
                            .toList(),
                        sharedColor: AppColors.secondary),
                  ],

                  // ── PHASE TARGETS ─────────────────────────────────────────
                  if (strainA.vegTargets != null ||
                      strainB.vegTargets != null ||
                      strainA.earlyFlowerTargets != null ||
                      strainB.earlyFlowerTargets != null) ...[
                    const _SectionHeader(label: 'VEG TARGETS'),
                    _textRow(context, 'VPD',
                        a: strainA.vegTargets?.vpdLabel ?? '—',
                        b: strainB.vegTargets?.vpdLabel ?? '—'),
                    _textRow(context, 'Temp',
                        a: strainA.vegTargets?.tempLabel ?? '—',
                        b: strainB.vegTargets?.tempLabel ?? '—'),
                    _textRow(context, 'RH',
                        a: strainA.vegTargets?.rhLabel ?? '—',
                        b: strainB.vegTargets?.rhLabel ?? '—'),
                    const _SectionHeader(label: 'EARLY FLOWER TARGETS'),
                    _textRow(context, 'VPD',
                        a: strainA.earlyFlowerTargets?.vpdLabel ?? '—',
                        b: strainB.earlyFlowerTargets?.vpdLabel ?? '—'),
                    _textRow(context, 'Temp',
                        a: strainA.earlyFlowerTargets?.tempLabel ?? '—',
                        b: strainB.earlyFlowerTargets?.tempLabel ?? '—'),
                    _textRow(context, 'RH',
                        a: strainA.earlyFlowerTargets?.rhLabel ?? '—',
                        b: strainB.earlyFlowerTargets?.rhLabel ?? '—'),
                    const _SectionHeader(label: 'LATE FLOWER TARGETS'),
                    _textRow(context, 'VPD',
                        a: strainA.lateFlowerTargets?.vpdLabel ?? '—',
                        b: strainB.lateFlowerTargets?.vpdLabel ?? '—'),
                    _textRow(context, 'Temp',
                        a: strainA.lateFlowerTargets?.tempLabel ?? '—',
                        b: strainB.lateFlowerTargets?.tempLabel ?? '—'),
                    _textRow(context, 'RH',
                        a: strainA.lateFlowerTargets?.rhLabel ?? '—',
                        b: strainB.lateFlowerTargets?.rhLabel ?? '—'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Row builders ─────────────────────────────────────────────────────────────

  Widget _textRow(
    BuildContext context,
    String label, {
    required String a,
    required String b,
    Color? colorA,
    Color? colorB,
    bool aWins = false,
    bool bWins = false,
  }) {
    return _CompareRow(
      label: label,
      cellA: _cell(context, a,
          textColor: colorA, wins: aWins),
      cellB: _cell(context, b,
          textColor: colorB, wins: bWins),
    );
  }

  Widget _numericRow(
    BuildContext context,
    String label, {
    required String aLabel,
    required String bLabel,
    double? aVal,
    double? bVal,
    bool lowerIsBetter = false,
  }) {
    bool aWins = false;
    bool bWins = false;
    if (aVal != null && bVal != null && aVal != bVal) {
      aWins = lowerIsBetter ? aVal < bVal : aVal > bVal;
      bWins = lowerIsBetter ? bVal < aVal : bVal > aVal;
    }
    return _CompareRow(
      label: label,
      cellA: _cell(context, aLabel, wins: aWins),
      cellB: _cell(context, bLabel, wins: bWins),
    );
  }

  Widget _rangeRow(
    BuildContext context,
    String label, {
    required int? aMin,
    required int? aMax,
    required int? bMin,
    required int? bMax,
    required String unit,
    bool winnerIsHigher = false,
    bool lowerIsBetter = false,
  }) {
    final aStr = aMin != null && aMax != null ? '$aMin–$aMax $unit' : '—';
    final bStr = bMin != null && bMax != null ? '$bMin–$bMax $unit' : '—';
    bool aWins = false;
    bool bWins = false;
    if (aMax != null && bMax != null && aMax != bMax) {
      if (winnerIsHigher) {
        aWins = aMax > bMax;
        bWins = bMax > aMax;
      } else if (lowerIsBetter) {
        aWins = aMax < bMax;
        bWins = bMax < aMax;
      }
    }
    return _CompareRow(
      label: label,
      cellA: _cell(context, aStr, wins: aWins),
      cellB: _cell(context, bStr, wins: bWins),
    );
  }

  Widget _rangeRowDouble(
    BuildContext context,
    String label, {
    required double? aMin,
    required double? aMax,
    required double? bMin,
    required double? bMax,
    required int decimals,
    String unit = '',
  }) {
    String fmt(double v) => v.toStringAsFixed(decimals);
    final aStr =
        aMin != null && aMax != null ? '${fmt(aMin)}–${fmt(aMax)}${ unit.isEmpty ? '' : ' $unit'}' : '—';
    final bStr =
        bMin != null && bMax != null ? '${fmt(bMin)}–${fmt(bMax)}${ unit.isEmpty ? '' : ' $unit'}' : '—';
    return _CompareRow(
      label: label,
      cellA: _cell(context, aStr),
      cellB: _cell(context, bStr),
    );
  }

  Widget _doubleRow(
    BuildContext context,
    String label, {
    required double? aVal,
    required double? bVal,
    required String Function(double) format,
  }) {
    final aStr = aVal != null ? format(aVal) : '—';
    final bStr = bVal != null ? format(bVal) : '—';
    return _CompareRow(
      label: label,
      cellA: _cell(context, aStr),
      cellB: _cell(context, bStr),
    );
  }

  Widget _pillRow(
    BuildContext context, {
    required List<String> aItems,
    required List<String> bItems,
    required Color sharedColor,
  }) {
    final sharedItems = aItems
        .toSet()
        .intersection(bItems.toSet());

    Widget pills(List<String> items) {
      if (items.isEmpty) return Text('—', style: AppTypography.bodySmall(context));
      return Wrap(
        spacing: 4,
        runSpacing: 3,
        children: items.map((item) {
          final isShared = sharedItems.contains(item);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isShared ? sharedColor : AppColors.primary)
                  .withValues(alpha: isShared ? 0.2 : 0.1),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(
                color: (isShared ? sharedColor : context.colBorder)
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Text(item,
                style: AppTypography.labelSmall(context).copyWith(
                    color: isShared ? sharedColor : context.colTextSecondary,
                    fontSize: 9)),
          );
        }).toList(),
      );
    }

    return _CompareRow(
      label: '',
      cellA: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: pills(aItems)),
      cellB: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: pills(bItems)),
    );
  }

  Widget _cell(
    BuildContext context,
    String value, {
    Color? textColor,
    bool wins = false,
  }) {
    return Container(
      decoration: wins
          ? BoxDecoration(
              color: AppColors.growing.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (wins) ...[
            const Icon(Icons.star_rounded,
                size: 10, color: AppColors.growing),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodySmall(context).copyWith(
                color: wins
                    ? AppColors.growing
                    : textColor ?? context.colTextPrimary,
                fontWeight:
                    wins ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Feeding helpers ─────────────────────────────────────────────────────────

  String _feedingLabel(String? v) {
    if (v == null) return '—';
    return v[0].toUpperCase() + v.substring(1);
  }

  /// Lower = lighter feeder (winner for growers who want ease of maintenance).
  int _feedingScore(String? v) => switch (v) {
        'light'  => 1,
        'medium' => 2,
        'heavy'  => 3,
        _        => 99,
      };

  String _trainingLabel(String t) => const {
        'lst': 'LST',
        'topping': 'Topping',
        'fimming': 'FIMming',
        'fim': 'FIM',
        'scrog': 'ScrOG',
        'sog': 'SoG',
        'mainline': 'Mainline',
        'lollipopping': 'Lollipopping',
        'defoliation': 'Defoliation',
      }[t] ??
      t;
}

// ── Static sub-widgets ────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  final Strain strainA;
  final Strain strainB;
  final Color colorA;
  final Color colorB;

  const _HeaderRow({
    required this.strainA,
    required this.strainB,
    required this.colorA,
    required this.colorB,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colSurface2,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Label column spacer
          const SizedBox(width: _CompareRow.labelWidth),
          const SizedBox(width: AppSpacing.xs),
          // Strain A
          Expanded(child: _strainHeader(context, strainA, colorA)),
          const SizedBox(width: AppSpacing.xs),
          // Strain B
          Expanded(child: _strainHeader(context, strainB, colorB)),
        ],
      ),
    );
  }

  Widget _strainHeader(BuildContext context, Strain s, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.name,
            style: AppTypography.labelLarge(context)
                .copyWith(color: color, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _badge(context, s.type, color),
              if (s.isAutoflower) ...[
                const SizedBox(width: 3),
                _badge(context, 'Auto', AppColors.drying),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(label,
          style: AppTypography.labelSmall(context)
              .copyWith(color: color, fontSize: 8)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        4,
      ),
      child: Row(
        children: [
          Expanded(child: Divider(color: context.colBorder, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              label,
              style: AppTypography.labelSmall(context).copyWith(
                  color: context.colTextMuted,
                  fontSize: 9,
                  letterSpacing: 0.6),
            ),
          ),
          Expanded(child: Divider(color: context.colBorder, height: 1)),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  static const labelWidth = 72.0;

  final String label;
  final Widget cellA;
  final Widget cellB;

  const _CompareRow({
    required this.label,
    required this.cellA,
    required this.cellB,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: 3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(label,
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 10)),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: cellA),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            color: context.colBorder,
          ),
          Expanded(child: cellB),
        ],
      ),
    );
  }
}

// ── Strain picker sheet ────────────────────────────────────────────────────────
//
// A searchable list of kStrainLibrary entries — shown when the user taps
// "Compare with…" from StrainDetailScreen or StrainPreviewSheet.
//
// Returns the selected BuiltInStrain via Navigator.pop so callers can push
// StrainCompareScreen with the chosen pair.

class StrainPickerSheet extends StatefulWidget {
  /// Optional name to exclude from the list (the strain already selected).
  final String? excludeName;

  const StrainPickerSheet({super.key, this.excludeName});

  static Future<BuiltInStrain?> show(BuildContext context,
      {String? excludeName}) {
    return showModalBottomSheet<BuiltInStrain>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          StrainPickerSheet(excludeName: excludeName),
    );
  }

  @override
  State<StrainPickerSheet> createState() => _StrainPickerSheetState();
}

class _StrainPickerSheetState extends State<StrainPickerSheet> {
  String _search = '';

  List<BuiltInStrain> get _filtered {
    final q = _search.toLowerCase();
    return kStrainLibrary
        .where((s) =>
            s.name.toLowerCase() != (widget.excludeName?.toLowerCase() ?? '') &&
            (q.isEmpty || s.name.toLowerCase().contains(q) ||
                (s.lineage?.toLowerCase().contains(q) ?? false)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Indica':  return AppColors.curing;
      case 'Sativa':  return AppColors.harvested;
      default:        return AppColors.growing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      snap: true,
      snapSizes: const [0.75, 0.95],
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: context.colSurface2,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: context.colBorderFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding, 0, AppSpacing.pagePadding, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Choose strain to compare',
                        style: AppTypography.headlineMedium(context)),
                  ),
                  Semantics(
                    label: 'Close',
                    button: true,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close_rounded,
                          size: 20, color: context.colTextMuted),
                    ),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding, 0, AppSpacing.pagePadding, 8),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                autofocus: true,
                style: TextStyle(color: context.colTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Search ${kStrainLibrary.length} strains…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: context.colSurface3,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final s = list[i];
                  final color = _typeColor(s.type);
                  final thcLabel = s.thcPctMin != null && s.thcPctMax != null
                      ? '${s.thcPctMin!.toStringAsFixed(0)}–${s.thcPctMax!.toStringAsFixed(0)}%'
                      : null;
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Icon(Icons.science_rounded,
                          color: color, size: 18),
                    ),
                    title: Text(s.name,
                        style: AppTypography.labelLarge(context)
                            .copyWith(fontSize: 13)),
                    subtitle: Text(
                      [
                        s.type,
                        if (s.isAutoflower) 'Auto',
                        if (thcLabel != null) 'THC $thcLabel',
                      ].join(' · '),
                      style: AppTypography.bodySmall(context)
                          .copyWith(fontSize: 10),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded,
                        size: 16, color: context.colTextMuted),
                    onTap: () => Navigator.pop(context, s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
