import 'package:flutter/material.dart';

import '../data/strain_library.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/terpene_colors.dart';

/// Quick-peek bottom sheet for a [BuiltInStrain] entry.
///
/// Shows the strain's grow profile and phase targets without navigating
/// to a new screen.  A "Save to Library" button is shown when the strain
/// has not yet been saved.
class StrainPreviewSheet extends StatelessWidget {
  final BuiltInStrain strain;
  final bool isSaved;
  final VoidCallback? onSave;

  const StrainPreviewSheet({
    super.key,
    required this.strain,
    required this.isSaved,
    this.onSave,
  });

  static Future<void> show(
    BuildContext context,
    BuiltInStrain strain, {
    required bool isSaved,
    VoidCallback? onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StrainPreviewSheet(
        strain: strain,
        isSaved: isSaved,
        onSave: onSave,
      ),
    );
  }

  // ── Colour helpers ──────────────────────────────────────────────────────────

  Color _typeColor(BuildContext context, String type) {
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
    final typeColor = _typeColor(context, strain.type);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.6, 0.9],
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: context.colSurface2,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl)),
        ),
        child: Column(
          children: [
            // ── Drag handle ───────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colBorderFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(Icons.science_rounded,
                        color: typeColor, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strain.name,
                            style: AppTypography.headlineMedium(context)),
                        if (strain.lineage != null)
                          Text(strain.lineage!,
                              style: AppTypography.bodySmall(context)
                                  .copyWith(
                                      color: context.colTextSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Type + auto badges
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _badge(context, strain.type, typeColor),
                      if (strain.isAutoflower) ...[
                        const SizedBox(height: 3),
                        _badge(context, 'Auto', AppColors.drying),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Scrollable body ───────────────────
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                children: [
                  // Quick stats chips
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      // Always render the flowering window in days so
                      // the catalogue / preview / compare screens use
                      // the same unit.  Weeks → days at *7 when the
                      // catalogue only carried a week range.
                      if (strain.flowerWeeksMin != null &&
                          strain.flowerWeeksMax != null)
                        _statChip(
                          context,
                          Icons.wb_sunny_outlined,
                          '${strain.flowerWeeksMin! * 7}–${strain.flowerWeeksMax! * 7}d',
                          'Flower',
                        )
                      else
                        _statChip(
                          context,
                          Icons.wb_sunny_outlined,
                          '~${strain.flowerDays}d',
                          strain.isAutoflower ? 'Seed→Harvest' : 'Flower',
                        ),
                      if (strain.heightCmMin != null &&
                          strain.heightCmMax != null)
                        _statChip(
                          context,
                          Icons.height_rounded,
                          '${strain.heightCmMin}–${strain.heightCmMax} cm',
                          'Height',
                        ),
                      if (strain.yieldGPerM2Min != null &&
                          strain.yieldGPerM2Max != null)
                        _statChip(
                          context,
                          Icons.scale_rounded,
                          '${strain.yieldGPerM2Min}–${strain.yieldGPerM2Max} g/m²',
                          'Yield',
                        ),
                      if (strain.thcPctMin != null &&
                          strain.thcPctMax != null)
                        _statChip(
                          context,
                          Icons.science_rounded,
                          '${strain.thcPctMin!.toStringAsFixed(0)}–${strain.thcPctMax!.toStringAsFixed(0)}%',
                          'THC',
                          color: AppColors.secondary,
                        ),
                      if (strain.feedingIntensity != null)
                        _statChip(
                          context,
                          Icons.water_drop_rounded,
                          strain.feedingIntensity![0].toUpperCase() +
                              strain.feedingIntensity!.substring(1),
                          'Feeding',
                          color: strain.feedingIntensity == 'heavy'
                              ? AppColors.danger
                              : strain.feedingIntensity == 'light'
                                  ? AppColors.growing
                                  : AppColors.secondary,
                        ),
                      if (strain.stretchFactor != null)
                        _statChip(
                          context,
                          Icons.unfold_more_rounded,
                          '${strain.stretchFactor!.toStringAsFixed(1)}×',
                          'Stretch',
                        ),
                    ],
                  ),

                  // Terpenes
                  if (strain.terpenes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Terpenes',
                        style: AppTypography.labelSmall(context)
                            .copyWith(
                                color: context.colTextMuted,
                                fontSize: 10)),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: strain.terpenes
                          .map((t) => _terpenePill(context, t))
                          .toList(),
                    ),
                  ],

                  // Training
                  if (strain.training.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Recommended Training',
                        style: AppTypography.labelSmall(context)
                            .copyWith(
                                color: context.colTextMuted,
                                fontSize: 10)),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: strain.training
                          .map((t) => _trainingPill(context, t))
                          .toList(),
                    ),
                  ],

                  // Phase targets
                  if (strain.vegTargets != null ||
                      strain.earlyFlowerTargets != null ||
                      strain.lateFlowerTargets != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _phaseTargetsTable(context, strain),
                  ],

                  // EC / pH
                  if (strain.phMin != null || strain.ecVegMin != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Feeding Targets',
                        style: AppTypography.labelSmall(context)
                            .copyWith(
                                color: context.colTextMuted,
                                fontSize: 10)),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (strain.phMin != null && strain.phMax != null)
                          _statChip(
                            context,
                            Icons.science_outlined,
                            '${strain.phMin!.toStringAsFixed(1)}–${strain.phMax!.toStringAsFixed(1)}',
                            'pH',
                          ),
                        if (strain.ecVegMin != null &&
                            strain.ecVegMax != null)
                          _statChip(
                            context,
                            Icons.bolt_rounded,
                            '${strain.ecVegMin!.toStringAsFixed(1)}–${strain.ecVegMax!.toStringAsFixed(1)} mS',
                            'EC Veg',
                          ),
                        if (strain.ecFlowerMin != null &&
                            strain.ecFlowerMax != null)
                          _statChip(
                            context,
                            Icons.bolt_rounded,
                            '${strain.ecFlowerMin!.toStringAsFixed(1)}–${strain.ecFlowerMax!.toStringAsFixed(1)} mS',
                            'EC Flower',
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),

            // ── Footer action ─────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  0,
                  AppSpacing.pagePadding,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: isSaved
                      ? Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color:
                                AppColors.growing.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd),
                            border: Border.all(
                                color: AppColors.growing
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded,
                                  color: AppColors.growing, size: 16),
                              const SizedBox(width: AppSpacing.xs),
                              Text('Saved to Library',
                                  style:
                                      AppTypography.labelLarge(context)
                                          .copyWith(
                                              color: AppColors.growing)),
                            ],
                          ),
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd),
                            ),
                          ),
                          onPressed: () {
                            onSave?.call();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text('Save to Library',
                              style: AppTypography.labelLarge(context)
                                  .copyWith(
                                      color: Colors.black, fontSize: 15)),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _badge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(label,
          style: AppTypography.labelSmall(context)
              .copyWith(color: color, fontSize: 10)),
    );
  }

  Widget _statChip(
    BuildContext context,
    IconData icon,
    String value,
    String label, {
    Color? color,
  }) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: AppSpacing.xxs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: c, fontSize: 11)),
              Text(label,
                  style: AppTypography.labelSmall(context).copyWith(
                      color: context.colTextMuted, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _terpenePill(BuildContext context, String terpene) {
    // P2.5 — palette lives in lib/theme/terpene_colors.dart.
    final color =
        kTerpeneColors[terpene.toLowerCase()] ?? AppColors.secondary;
    final label = terpene[0].toUpperCase() + terpene.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: AppTypography.labelSmall(context)
              .copyWith(color: color, fontSize: 10)),
    );
  }

  Widget _trainingPill(BuildContext context, String technique) {
    const labels = {
      'lst': 'LST',
      'topping': 'Topping',
      'fimming': 'FIMming',
      'fim': 'FIM',
      'scrog': 'ScrOG',
      'sog': 'SoG',
      'mainline': 'Mainline',
      'lollipopping': 'Lollipopping',
      'defoliation': 'Defoliation',
    };
    final label = labels[technique] ?? technique;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: AppTypography.labelSmall(context)
              .copyWith(color: AppColors.primary, fontSize: 10)),
    );
  }

  Widget _phaseTargetsTable(BuildContext context, BuiltInStrain s) {
    final phases = [
      (label: 'Veg', t: s.vegTargets, color: AppColors.growing),
      (label: 'E. Flower', t: s.earlyFlowerTargets, color: AppColors.secondary),
      (label: 'L. Flower', t: s.lateFlowerTargets, color: AppColors.harvested),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colSurface3,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.colBorder),
      ),
      child: Column(
        children: [
          // Header
          Row(children: [
            const SizedBox(width: 60),
            ...phases.map((p) => Expanded(
                  child: Center(
                    child: Text(p.label,
                        style: AppTypography.labelSmall(context).copyWith(
                            color: p.t != null
                                ? p.color
                                : context.colTextMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                )),
          ]),
          const SizedBox(height: AppSpacing.xxs),
          // VPD
          _phaseRow(context, '⊙ VPD',
              phases.map((p) => p.t?.vpdLabel ?? '—').toList(),
              phases.map((p) => p.t != null ? p.color : context.colTextMuted).toList()),
          // Temp
          _phaseRow(context, '🌡 Temp',
              phases.map((p) => p.t?.tempLabel ?? '—').toList(),
              phases.map((p) => p.t != null ? p.color : context.colTextMuted).toList()),
          // RH
          _phaseRow(context, '💧 RH',
              phases.map((p) => p.t?.rhLabel ?? '—').toList(),
              phases.map((p) => p.t != null ? p.color : context.colTextMuted).toList()),
        ],
      ),
    );
  }

  Widget _phaseRow(BuildContext context, String label, List<String> values,
      List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: AppTypography.labelSmall(context)
                    .copyWith(color: context.colTextMuted, fontSize: 9)),
          ),
          ...List.generate(
            values.length,
            (i) => Expanded(
              child: Center(
                child: Text(values[i],
                    style: AppTypography.labelSmall(context)
                        .copyWith(color: colors[i], fontSize: 9),
                    textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
