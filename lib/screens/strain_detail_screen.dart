import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/strain_library.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../models/strain.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/terpene_colors.dart';
import '../utils/date_format.dart';
import '../widgets/community_benchmark_card.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/strain_preview_sheet.dart';
import 'plant_detail_screen.dart';
import 'strain_compare_screen.dart';

class StrainDetailScreen extends StatelessWidget {
  final Strain strain;

  const StrainDetailScreen({
    super.key,
    required this.strain,
  });

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
    final repo = context.watch<GrowRepository>();

    // Always read the freshest version from the repo in case it was just edited.
    final current = repo.strains.firstWhere(
      (s) => s.id == strain.id,
      orElse: () => strain,
    );

    final typeColor = _typeColor(current.type);

    // ── All plants linked to this strain ─────────
    final allPlants =
        repo.plants.where((p) => p.strainId == current.id).toList();

    // Active (non-archived) plants — still growing / drying / curing etc.
    final activePlants =
        allPlants.where((p) => !p.isArchived).toList();

    // Build plantId → HarvestLog lookup.
    final logByPlantId = <String, HarvestLog>{
      for (final log in repo.harvestLogs) log.plantId: log,
    };

    // Harvest records: plants that have a log with at least dryWeight.
    final harvestRecords = allPlants
        .map((p) => (plant: p, log: logByPlantId[p.id]))
        .where((r) => r.log != null && r.log!.dryWeight != null)
        .toList()
      ..sort((a, b) => b.log!.harvestedDate.compareTo(a.log!.harvestedDate));

    // ── Computed stats ────────────────────────────
    final dryWeights =
        harvestRecords.map((r) => r.log!.dryWeight!).toList();

    final avgDryWeight = dryWeights.isNotEmpty
        ? dryWeights.reduce((a, b) => a + b) / dryWeights.length
        : null;

    final bestDryWeight =
        dryWeights.isNotEmpty ? dryWeights.reduce(max) : null;

    // Avg grow duration: startDate → harvestedDate.
    final durations = harvestRecords
        .where((r) => r.plant.harvestedDate != null)
        .map((r) =>
            r.plant.harvestedDate!.difference(r.plant.startDate).inDays)
        .toList();
    final avgDays = durations.isNotEmpty
        ? durations.reduce((a, b) => a + b) / durations.length
        : null;

    // Avg quality rating.
    final ratedLogs = harvestRecords
        .where((r) => r.log!.qualityRating != null)
        .toList();
    final avgRating = ratedLogs.isNotEmpty
        ? ratedLogs
                .map((r) => r.log!.qualityRating!)
                .reduce((a, b) => a + b) /
            ratedLogs.length
        : null;

    // Yield % (wet→dry) average.
    final yieldPcts = harvestRecords
        .where((r) => r.log!.wetWeight != null && r.log!.wetWeight! > 0)
        .map((r) => (r.log!.dryWeight! / r.log!.wetWeight!) * 100)
        .toList();
    final avgYieldPct = yieldPcts.isNotEmpty
        ? yieldPcts.reduce((a, b) => a + b) / yieldPcts.length
        : null;

    // Aggregated quality notes (unique non-empty values).
    final aromas = harvestRecords
        .map((r) => r.log!.aromaNote)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final flavors = harvestRecords
        .map((r) => r.log!.flavorNotes)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final effects = harvestRecords
        .map((r) => r.log!.effectNotes)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final hasQualityNotes =
        aromas.isNotEmpty || flavors.isNotEmpty || effects.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name,
            style: AppTypography.headlineMedium(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.compare_arrows_rounded,
                color: context.colTextSecondary, size: 20),
            tooltip: 'Compare with…',
            onPressed: () => _openCompare(context, current),
          ),
          IconButton(
            icon: Icon(Icons.edit_rounded,
                color: context.colTextSecondary, size: 20),
            tooltip: 'Edit Strain',
            onPressed: () => _showEditDialog(context, repo, current),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded,
                color: AppColors.danger, size: 20),
            tooltip: 'Delete Strain',
            onPressed: () => _confirmDelete(context, repo, current),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Identity card ─────────────────
            _identityCard(context, current, typeColor, avgRating),

            const SizedBox(height: AppSpacing.md),

            // ── Grow profile ──────────────────
            if (current.hasRichData) ...[
              _growProfileCard(context, current),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Phase environment targets ──────
            if (current.vegTargets != null ||
                current.earlyFlowerTargets != null ||
                current.lateFlowerTargets != null) ...[
              _phaseTargetsCard(context, current),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Similar strains ───────────────
            _similarStrainsStrip(context, current),

            // ── Community benchmarks ──────────
            // Shows what the wider community achieves for this strain.
            // Renders nothing when there is no community data or no network.
            CommunityStrainCard(
              strainName:   current.name,
              userAvgGrams: avgDryWeight,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Stats row ─────────────────────
            if (harvestRecords.isNotEmpty) ...[
              _statsRow(
                context,
                totalHarvests: harvestRecords.length,
                avgDryWeight: avgDryWeight,
                bestDryWeight: bestDryWeight,
                avgDays: avgDays,
                avgYieldPct: avgYieldPct,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Quality notes ─────────────────
            if (hasQualityNotes) ...[
              _qualityNotesCard(context, aromas, flavors, effects),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Harvest history ───────────────
            if (harvestRecords.isNotEmpty) ...[
              _sectionHeader(context, Icons.agriculture_rounded,
                  'Harvest History', '${harvestRecords.length}'),
              const SizedBox(height: AppSpacing.sm),
              ...harvestRecords.map(
                (r) => _harvestRow(context, r.plant, r.log!),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Active plants ─────────────────
            _sectionHeader(
              context,
              Icons.eco_rounded,
              'Active Plants',
              activePlants.isEmpty ? null : '${activePlants.length}',
            ),
            const SizedBox(height: AppSpacing.sm),
            if (activePlants.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'No active plants for this strain.',
                  style: AppTypography.bodyMedium(context)
                      .copyWith(color: context.colTextMuted),
                ),
              )
            else
              ...activePlants.map((p) => _plantRow(context, p)),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ── Compare ─────────────────────────────────────

  Future<void> _openCompare(BuildContext context, Strain current) async {
    final picked = await StrainPickerSheet.show(
      context,
      excludeName: current.name,
    );
    if (picked == null || !context.mounted) return;
    // Use full catalog data for the current strain when available,
    // otherwise fall back to the My Library Strain object.
    final catalogA = kStrainLibrary
        .where((s) =>
            s.name.toLowerCase() == current.name.toLowerCase())
        .firstOrNull;
    final strainA = catalogA != null
        ? strainFromBuiltIn(catalogA)
        : current;
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

  // ── Similar strains strip ────────────────────────────────────────────────

  Widget _similarStrainsStrip(BuildContext context, Strain current) {
    // Score every catalog entry relative to the current strain.
    final catalogCurrent = kStrainLibrary
        .where((s) =>
            s.name.toLowerCase() == current.name.toLowerCase())
        .firstOrNull;

    final scored = kStrainLibrary
        .where((s) =>
            s.name.toLowerCase() != current.name.toLowerCase())
        .map((s) => (
              strain: s,
              score: _similarityScore(current, s, catalogCurrent)
            ))
        .where((e) => e.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final similar = scored.take(6).map((e) => e.strain).toList();
    if (similar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: AppColors.secondary),
              const SizedBox(width: AppSpacing.xs),
              Text('Similar Strains',
                  style: AppTypography.headlineSmall(context)),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: similar.length,
            itemBuilder: (_, i) {
              final s = similar[i];
              final color = _typeColor(s.type);
              return GestureDetector(
                onTap: () => StrainPreviewSheet.show(context, s,
                    isSaved: false),
                child: Container(
                  width: 140,
                  margin: EdgeInsets.only(
                      right: i < similar.length - 1 ? 8 : 0),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colSurface1,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    border:
                        Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.science_rounded,
                            color: color, size: 14),
                        const SizedBox(width: AppSpacing.xxs),
                        _smallBadge(context, s.type, color),
                        if (s.isAutoflower) ...[
                          const SizedBox(width: 3),
                          _smallBadge(context, 'A', AppColors.drying),
                        ],
                      ]),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        s.name,
                        style: AppTypography.labelSmall(context)
                            .copyWith(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (s.thcPctMax != null)
                        Text(
                          'THC up to ${s.thcPctMax!.toStringAsFixed(0)}%',
                          style: AppTypography.labelSmall(context)
                              .copyWith(
                                  color: AppColors.secondary,
                                  fontSize: 9),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _smallBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(label,
          style: AppTypography.labelSmall(context)
              .copyWith(color: color, fontSize: 8)),
    );
  }

  int _similarityScore(
      Strain current, BuiltInStrain candidate, BuiltInStrain? catalogCurrent) {
    int score = 0;
    if (candidate.type == current.type) score += 3;
    if (candidate.isAutoflower == current.isAutoflower) score += 2;

    // Shared terpenes from saved strain, fallback to catalog entry.
    final sourceTerpenes = current.terpenes.isNotEmpty
        ? current.terpenes
        : (catalogCurrent?.terpenes ?? const []);
    for (final t in sourceTerpenes) {
      if (candidate.terpenes.contains(t)) score += 1;
    }

    // Similar THC ceiling.
    final currentThc =
        current.thcPctMax ?? catalogCurrent?.thcPctMax;
    if (currentThc != null && candidate.thcPctMax != null) {
      if ((currentThc - candidate.thcPctMax!).abs() <= 4) score += 2;
    }

    return score;
  }

  // ── Identity card ──────────────────────────────

  Widget _identityCard(
    BuildContext context,
    Strain current,
    Color typeColor,
    double? avgRating,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: typeColor.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            typeColor.withValues(alpha: 0.06),
            context.colSurface1,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(current.type,
                    style: AppTypography.labelLarge(context)
                        .copyWith(color: typeColor)),
              ),
              const Spacer(),
              if (avgRating != null) _starRating(context, avgRating),
            ],
          ),
          if (current.genetics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(current.genetics,
                style: AppTypography.bodyMedium(context)
                    .copyWith(color: context.colTextSecondary)),
          ],
          ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (current.flowerTimeLabel != 'Unknown')
                  _pill(context, Icons.wb_sunny_outlined,
                      current.flowerTimeLabel, context.colTextMuted),
                if (current.isAutoflower)
                  _pill(context, Icons.bolt_rounded, 'Auto',
                      AppColors.drying),
                if (current.thcLabel != null)
                  _pill(context, Icons.science_rounded,
                      'THC ${current.thcLabel}', AppColors.secondary),
                if (current.cbdLabel != null)
                  _pill(context, Icons.favorite_rounded,
                      'CBD ${current.cbdLabel}', AppColors.growing),
                if (current.breeder != null)
                  _pill(context, Icons.store_rounded,
                      current.breeder!, context.colTextMuted),
                if (current.expectedYieldPercent != null)
                  _pill(context, Icons.percent_rounded,
                      '${current.expectedYieldPercent!.toStringAsFixed(0)}% yield',
                      context.colTextMuted),
              ],
            ),
          ],
          if (current.notes != null && current.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(color: context.colBorder),
            const SizedBox(height: AppSpacing.xs),
            Text(current.notes!,
                style: AppTypography.bodySmall(context)
                    .copyWith(color: context.colTextSecondary)),
          ],
        ],
      ),
    );
  }

  // ── Grow profile card ──────────────────────────

  Widget _growProfileCard(BuildContext context, Strain s) {
    final hasNumbers = s.heightCmMin != null ||
        s.yieldGPerM2Min != null ||
        s.cureWeeksMin != null ||
        s.feedingIntensity != null;

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
          // Header
          Row(children: [
            const Icon(Icons.bar_chart_rounded,
                size: 16, color: AppColors.secondary),
            const SizedBox(width: AppSpacing.xs),
            Text('Grow Profile',
                style: AppTypography.headlineSmall(context)),
          ]),
          const SizedBox(height: AppSpacing.sm),

          // Number stats row
          if (hasNumbers) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (s.heightCmMin != null && s.heightCmMax != null)
                  _growStat(context, Icons.height_rounded,
                      '${s.heightCmMin}–${s.heightCmMax} cm', 'Height'),
                if (s.yieldGPerM2Min != null && s.yieldGPerM2Max != null)
                  _growStat(context, Icons.scale_rounded,
                      '${s.yieldGPerM2Min}–${s.yieldGPerM2Max} g/m²', 'Yield'),
                if (s.stretchFactor != null)
                  _growStat(context, Icons.unfold_more_rounded,
                      '${s.stretchFactor!.toStringAsFixed(1)}× stretch', 'Flip'),
                if (s.cureWeeksMin != null && s.cureWeeksMax != null)
                  _growStat(context, Icons.timer_outlined,
                      '${s.cureWeeksMin}–${s.cureWeeksMax} wks', 'Cure'),
                if (s.feedingIntensity != null)
                  _growStat(
                    context,
                    Icons.water_drop_rounded,
                    s.feedingIntensity![0].toUpperCase() +
                        s.feedingIntensity!.substring(1),
                    'Feeding',
                    color: s.feedingIntensity == 'heavy'
                        ? AppColors.danger
                        : s.feedingIntensity == 'light'
                            ? AppColors.growing
                            : AppColors.secondary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // EC / pH row
          if (s.phMin != null || s.ecVegMin != null) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (s.phMin != null && s.phMax != null)
                  _growStat(context, Icons.science_outlined,
                      '${s.phMin!.toStringAsFixed(1)}–${s.phMax!.toStringAsFixed(1)}',
                      'pH'),
                if (s.ecVegMin != null && s.ecVegMax != null)
                  _growStat(context, Icons.bolt_rounded,
                      '${s.ecVegMin!.toStringAsFixed(1)}–${s.ecVegMax!.toStringAsFixed(1)} mS',
                      'EC Veg'),
                if (s.ecFlowerMin != null && s.ecFlowerMax != null)
                  _growStat(context, Icons.bolt_rounded,
                      '${s.ecFlowerMin!.toStringAsFixed(1)}–${s.ecFlowerMax!.toStringAsFixed(1)} mS',
                      'EC Flower'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Terpenes
          if (s.terpenes.isNotEmpty) ...[
            Text('Terpenes',
                style: AppTypography.labelSmall(context)
                    .copyWith(color: context.colTextMuted, fontSize: 10)),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: s.terpenes
                  .map((t) => _terpenePill(context, t))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Training
          if (s.recommendedTraining.isNotEmpty) ...[
            Text('Recommended Training',
                style: AppTypography.labelSmall(context)
                    .copyWith(color: context.colTextMuted, fontSize: 10)),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: s.recommendedTraining
                  .map((t) => _trainingPill(context, t))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _growStat(
    BuildContext context,
    IconData icon,
    String value,
    String label, {
    Color? color,
  }) {
    final c = color ?? AppColors.primary;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: AppSpacing.xxs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: c, fontSize: 11)),
              Text(label,
                  style: AppTypography.labelSmall(context)
                      .copyWith(
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
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius:
            BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: AppTypography.labelSmall(context)
              .copyWith(color: color, fontSize: 10)),
    );
  }

  Widget _trainingPill(BuildContext context, String technique) {
    final labels = {
      'lst': 'LST',
      'topping': 'Topping',
      'fimming': 'FIMming',
      'scrog': 'ScrOG',
      'sog': 'SoG',
      'mainline': 'Mainline',
      'lollipopping': 'Lollipopping',
      'defoliation': 'Defoliation',
    };
    final label = labels[technique] ?? technique;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius:
            BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: AppTypography.labelSmall(context)
              .copyWith(color: AppColors.primary, fontSize: 10)),
    );
  }

  // ── Phase targets card ─────────────────────────

  Widget _phaseTargetsCard(BuildContext context, Strain s) {
    final phases = [
      (label: 'Veg', targets: s.vegTargets, color: AppColors.growing),
      (
        label: 'E. Flower',
        targets: s.earlyFlowerTargets,
        color: AppColors.secondary
      ),
      (
        label: 'L. Flower',
        targets: s.lateFlowerTargets,
        color: AppColors.harvested
      ),
    ];

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
            const Icon(Icons.thermostat_rounded,
                size: 16, color: AppColors.harvested),
            const SizedBox(width: AppSpacing.xs),
            Text('Phase Targets',
                style: AppTypography.headlineSmall(context)),
            const Spacer(),
            Text('VPD · Temp · RH',
                style: AppTypography.labelSmall(context)
                    .copyWith(color: context.colTextMuted, fontSize: 9)),
          ]),
          const SizedBox(height: AppSpacing.sm),

          // Header row
          Row(children: [
            const SizedBox(width: 72),
            ...phases.map(
              (p) => Expanded(
                child: Center(
                  child: Text(p.label,
                      style: AppTypography.labelSmall(context).copyWith(
                          color: p.targets != null
                              ? p.color
                              : context.colTextMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.xxs),
          Divider(color: context.colBorder, height: 1),
          const SizedBox(height: AppSpacing.xxs),

          // VPD row
          _phaseRow(
            context,
            icon: Icons.air_rounded,
            label: 'VPD',
            values: phases
                .map((p) => p.targets?.vpdLabel ?? '—')
                .toList(),
            colors:
                phases.map((p) => p.targets != null ? p.color : context.colTextMuted).toList(),
          ),

          // Temp day row
          _phaseRow(
            context,
            icon: Icons.thermostat_rounded,
            label: 'Temp',
            values: phases
                .map((p) => p.targets?.tempLabel ?? '—')
                .toList(),
            colors:
                phases.map((p) => p.targets != null ? p.color : context.colTextMuted).toList(),
          ),

          // RH row
          _phaseRow(
            context,
            icon: Icons.water_rounded,
            label: 'RH',
            values: phases
                .map((p) => p.targets?.rhLabel ?? '—')
                .toList(),
            colors:
                phases.map((p) => p.targets != null ? p.color : context.colTextMuted).toList(),
          ),
        ],
      ),
    );
  }

  Widget _phaseRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<String> values,
    required List<Color> colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Row(
              children: [
                Icon(icon, size: 11, color: context.colTextMuted),
                const SizedBox(width: AppSpacing.xxs),
                Text(label,
                    style: AppTypography.labelSmall(context)
                        .copyWith(
                            color: context.colTextMuted, fontSize: 10)),
              ],
            ),
          ),
          ...List.generate(
            values.length,
            (i) => Expanded(
              child: Center(
                child: Text(
                  values[i],
                  style: AppTypography.labelSmall(context).copyWith(
                      color: colors[i], fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _starRating(BuildContext context, double rating) {
    final full = rating.floor();
    final half = (rating - full) >= 0.5;
    final stars = List<Widget>.generate(5, (i) {
      final IconData icon;
      if (i < full) {
        icon = Icons.star_rounded;
      } else if (i == full && half) {
        icon = Icons.star_half_rounded;
      } else {
        icon = Icons.star_outline_rounded;
      }
      return Icon(icon, size: 16, color: AppColors.harvested);
    });
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...stars,
        const SizedBox(width: AppSpacing.xxs),
        Text(
          rating.toStringAsFixed(1),
          style: AppTypography.labelSmall(context),
        ),
      ],
    );
  }

  // ── Stats row ──────────────────────────────────

  Widget _statsRow(
    BuildContext context, {
    required int totalHarvests,
    required double? avgDryWeight,
    required double? bestDryWeight,
    required double? avgDays,
    required double? avgYieldPct,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            label: 'Harvests',
            value: '$totalHarvests',
            color: AppColors.primary,
            icon: Icons.agriculture_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _statCard(
            context,
            label: 'Avg Yield',
            value: avgDryWeight != null
                ? '${avgDryWeight.toStringAsFixed(1)}g'
                : '—',
            color: AppColors.growing,
            icon: Icons.scale_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _statCard(
            context,
            label: 'Best Yield',
            value: bestDryWeight != null
                ? '${bestDryWeight.toStringAsFixed(1)}g'
                : '—',
            color: AppColors.harvested,
            icon: Icons.emoji_events_rounded,
          ),
        ),
        if (avgDays != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _statCard(
              context,
              label: 'Avg Days',
              value: '${avgDays.round()}d',
              color: AppColors.secondary,
              icon: Icons.timer_outlined,
            ),
          ),
        ],
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppSpacing.xxs),
          Text(value,
              style: AppTypography.headlineSmall(context)
                  .copyWith(color: color, fontSize: 15)),
          Text(label,
              style: AppTypography.labelSmall(context)
                  .copyWith(color: context.colTextMuted, fontSize: 9)),
        ],
      ),
    );
  }

  // ── Quality notes card ─────────────────────────

  Widget _qualityNotesCard(
    BuildContext context,
    List<String> aromas,
    List<String> flavors,
    List<String> effects,
  ) {
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
          Row(
            children: [
              const Icon(Icons.spa_rounded,
                  size: 16, color: AppColors.growing),
              const SizedBox(width: AppSpacing.xs),
              Text('Grower Notes',
                  style: AppTypography.headlineSmall(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (aromas.isNotEmpty)
            _noteRow(context, '🌸 Aroma', aromas.join('  ·  ')),
          if (flavors.isNotEmpty)
            _noteRow(context, '🍋 Flavour', flavors.join('  ·  ')),
          if (effects.isNotEmpty)
            _noteRow(context, '✨ Effects', effects.join('  ·  ')),
        ],
      ),
    );
  }

  Widget _noteRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: AppTypography.labelSmall(context)
                    .copyWith(color: context.colTextMuted, fontSize: 10)),
          ),
          Expanded(
            child: Text(value,
                style: AppTypography.bodySmall(context)
                    .copyWith(color: context.colTextSecondary)),
          ),
        ],
      ),
    );
  }

  // ── Harvest row ────────────────────────────────

  Widget _harvestRow(
      BuildContext context, Plant plant, HarvestLog log) {
    final rating = log.qualityRating;
    final yieldPct =
        log.wetWeight != null && log.wetWeight! > 0
            ? (log.dryWeight! / log.wetWeight!) * 100
            : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.colBorder),
      ),
      child: Row(
        children: [
          // Date column
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  fmtShortDate(log.harvestedDate)
                      .split(' ')
                      .first, // "Apr"
                  style: AppTypography.labelSmall(context)
                      .copyWith(
                          color: context.colTextMuted, fontSize: 9),
                ),
                Text(
                  fmtShortDate(log.harvestedDate)
                      .split(' ')
                      .last, // "28"
                  style: AppTypography.headlineSmall(context)
                      .copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(width: 1, height: 40, color: context.colBorder),
          const SizedBox(width: AppSpacing.sm),
          // Main info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plant.name,
                    style: AppTypography.labelLarge(context)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${log.dryWeight!.toStringAsFixed(1)}g dry',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: AppColors.growing),
                    ),
                    if (yieldPct != null) ...[
                      Text('  ·  ',
                          style:
                              AppTypography.bodySmall(context)),
                      Text(
                        '${yieldPct.toStringAsFixed(1)}%',
                        style: AppTypography.bodySmall(context)
                            .copyWith(color: context.colTextMuted),
                      ),
                    ],
                    if (plant.harvestedDate != null) ...[
                      Text('  ·  ',
                          style:
                              AppTypography.bodySmall(context)),
                      Text(
                        '${plant.harvestedDate!.difference(plant.startDate).inDays}d grow',
                        style: AppTypography.bodySmall(context)
                            .copyWith(color: context.colTextMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Star rating
          if (rating != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (i) => Icon(
                  i < rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 12,
                  color: i < rating
                      ? AppColors.harvested
                      : context.colBorder,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Active plant row ───────────────────────────

  Widget _plantRow(BuildContext context, Plant plant) {
    final statusColor = AppColors.statusColor(plant.statusLabel);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
          ),
        ),
        title: Text(plant.name,
            style: AppTypography.labelLarge(context)),
        subtitle: Text(plant.statusLabel,
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextMuted)),
        trailing: Icon(Icons.chevron_right,
            color: context.colTextMuted, size: 18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlantDetailScreen(plant: plant),
          ),
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────

  Widget _sectionHeader(
    BuildContext context,
    IconData icon,
    String title,
    String? count,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(title, style: AppTypography.headlineSmall(context)),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(count,
                style: AppTypography.labelSmall(context)
                    .copyWith(color: AppColors.primary, fontSize: 10)),
          ),
        ],
      ],
    );
  }

  // ── Small helpers ──────────────────────────────

  Widget _pill(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: AppTypography.labelSmall(context)
                  .copyWith(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  // ── Edit dialog ────────────────────────────────

  void _showEditDialog(
    BuildContext context,
    GrowRepository repo,
    Strain current,
  ) {
    final nameCtrl = TextEditingController(text: current.name);
    final geneticsCtrl = TextEditingController(text: current.genetics);
    final flowerCtrl = TextEditingController(
        text: current.expectedFlowerDays?.toString() ?? '');
    final yieldCtrl = TextEditingController(
        text: current.expectedYieldPercent?.toStringAsFixed(1) ?? '');
    final notesCtrl = TextEditingController(text: current.notes ?? '');
    String selectedType = current.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.pagePadding,
            right: AppSpacing.pagePadding,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Strain',
                    style: AppTypography.headlineLarge(context)),
                const SizedBox(height: AppSpacing.lg),
                _field(context, nameCtrl, 'Strain Name *'),
                const SizedBox(height: AppSpacing.sm),
                _field(context, geneticsCtrl, 'Genetics'),
                const SizedBox(height: AppSpacing.sm),
                Text('Type', style: AppTypography.bodySmall(context)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  children: ['Indica', 'Sativa', 'Hybrid'].map((t) {
                    final sel = selectedType == t;
                    final color = _typeColor(t);
                    return ChoiceChip(
                      label: Text(t),
                      selected: sel,
                      onSelected: (_) =>
                          setSheetState(() => selectedType = t),
                      selectedColor: color,
                      labelStyle: TextStyle(
                          color: sel
                              ? Colors.black
                              : context.colTextSecondary),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.sm),
                _field(context, flowerCtrl, 'Expected Flower Days',
                    keyboard: TextInputType.number),
                const SizedBox(height: AppSpacing.sm),
                _field(context, yieldCtrl, 'Expected Yield %',
                    keyboard: const TextInputType.numberWithOptions(
                        decimal: true)),
                const SizedBox(height: AppSpacing.sm),
                _field(context, notesCtrl, 'Notes', maxLines: 3),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      repo.updateStrain(current.copyWith(
                        name: nameCtrl.text.trim(),
                        genetics: geneticsCtrl.text.trim(),
                        type: selectedType,
                        expectedFlowerDays:
                            int.tryParse(flowerCtrl.text),
                        expectedYieldPercent:
                            double.tryParse(yieldCtrl.text),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      ));
                      Navigator.pop(ctx);
                    },
                    child: Text('Save Changes',
                        style: AppTypography.labelLarge(context)
                            .copyWith(
                                color: Colors.black, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      geneticsCtrl.dispose();
      flowerCtrl.dispose();
      yieldCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  Widget _field(
    BuildContext context,
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: TextStyle(color: context.colTextPrimary),
      decoration: InputDecoration(labelText: label),
    );
  }

  // ── Delete confirmation ────────────────────────

  void _confirmDelete(
    BuildContext context,
    GrowRepository repo,
    Strain current,
  ) async {
    final confirmed = await ConfirmSheet.show(
      context,
      icon: Icons.local_florist_rounded,
      iconColor: AppColors.danger,
      title: 'Delete "${current.name}"?',
      body: 'This removes the strain from the library.\n'
          'Plants using this strain will keep their strain name.',
      confirmLabel: 'Delete Strain',
    );

    if (confirmed && context.mounted) {
      repo.deleteStrain(current.id);
      Navigator.pop(context); // pop detail screen
    }
  }
}
