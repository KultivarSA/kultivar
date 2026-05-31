import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grow_space.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/empty_state_art.dart';

class CrossGrowComparisonScreen extends StatefulWidget {
  const CrossGrowComparisonScreen({super.key});

  @override
  State<CrossGrowComparisonScreen> createState() =>
      _CrossGrowComparisonScreenState();
}

class _CrossGrowComparisonScreenState extends State<CrossGrowComparisonScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _spaceA;
  String? _spaceB;

  // Persist the last pair across tab switches and back-navigation.
  static String? _lastSpaceA;
  static String? _lastSpaceB;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _spaceA = _lastSpaceA;
    _spaceB = _lastSpaceB;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Space metrics ─────────────────────────────

  _SpaceMetrics _metricsForSpace(
    String spaceId,
    List<Plant> allPlants,
    List<HarvestLog> harvestLogs,
  ) {
    // Build a O(1) lookup so harvest-log edits are reflected here.
    final logByPlantId = <String, HarvestLog>{};
    for (final log in harvestLogs) {
      logByPlantId[log.plantId] = log;
    }

    final plants = allPlants.where((p) => p.growSpaceId == spaceId).toList();
    // Use harvest-log weights as source of truth; fall back to plant fields
    // for records created before the HarvestLog edit feature existed.
    final completed = plants.where((p) {
      if (!p.isArchived || p.status != PlantStatus.completed) return false;
      final log = logByPlantId[p.id];
      final dry = log?.dryWeight ?? p.dryWeight;
      return dry != null && dry > 0;
    }).toList();
    final removed = plants.where((p) => p.status == PlantStatus.removed).length;

    // Primary yield metric: dry weight in grams.
    final dryWeights = completed.map((p) {
      final log = logByPlantId[p.id];
      return (log?.dryWeight ?? p.dryWeight)!;
    }).toList();
    final avgYield = dryWeights.isNotEmpty
        ? dryWeights.reduce((a, b) => a + b) / dryWeights.length
        : null;
    final bestYield =
        dryWeights.isNotEmpty ? dryWeights.reduce((a, b) => a > b ? a : b) : null;
    final totalDryWeight = dryWeights.fold(0.0, (sum, w) => sum + w);
    final failureRate =
        plants.isNotEmpty ? (removed / plants.length) * 100 : 0.0;

    return _SpaceMetrics(
      totalPlants: plants.length,
      completedHarvests: completed.length,
      avgYield: avgYield,
      bestYield: bestYield,
      totalDryWeight: totalDryWeight,
      removedCount: removed,
      failureRate: failureRate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Compare', style: AppTypography.headlineMedium(context)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.colTextMuted,
          tabs: const [
            Tab(text: 'Space vs Space'),
            Tab(text: 'Grow vs Grow'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildSpaceComparison(repo),
          _buildGrowComparison(repo),
        ],
      ),
    );
  }

  // ── Space vs Space ────────────────────────────

  Widget _buildSpaceComparison(GrowRepository repo) {
    final spaces = repo.growSpaces;

    // Clear any persisted IDs whose spaces have since been deleted,
    // so the dropdown never receives a value that isn't in its items.
    final spaceIds = spaces.map((s) => s.id).toSet();
    if (_spaceA != null && !spaceIds.contains(_spaceA)) {
      _spaceA = null;
      _lastSpaceA = null;
    }
    if (_spaceB != null && !spaceIds.contains(_spaceB)) {
      _spaceB = null;
      _lastSpaceB = null;
    }

    if (spaces.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'You need at least 2 grow spaces to compare.',
            style: AppTypography.bodyMedium(context),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        // Space A picker — excludes whatever Space B has selected.
        _pickerRow(
          label: 'Space A',
          color: AppColors.primary,
          value: _spaceA,
          spaces: spaces.where((s) => s.id != _spaceB).toList(),
          onChanged: (v) => setState(() {
            _spaceA = v;
            _lastSpaceA = v;
          }),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Space B picker — excludes whatever Space A has selected.
        _pickerRow(
          label: 'Space B',
          color: AppColors.secondary,
          value: _spaceB,
          spaces: spaces.where((s) => s.id != _spaceA).toList(),
          onChanged: (v) => setState(() {
            _spaceB = v;
            _lastSpaceB = v;
          }),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (_spaceA != null && _spaceB != null) ...[
          _buildComparisonTable(
            repo: repo,
            idA: _spaceA!,
            idB: _spaceB!,
            labelA: spaces
                    .where((s) => s.id == _spaceA)
                    .map((s) => s.name)
                    .firstOrNull ??
                'Space A',
            labelB: spaces
                    .where((s) => s.id == _spaceB)
                    .map((s) => s.name)
                    .firstOrNull ??
                'Space B',
            colorA: AppColors.primary,
            colorB: AppColors.secondary,
          ),
        ] else
          Center(
            child: Text(
              'Select two spaces above to compare.',
              style: AppTypography.bodyMedium(context),
            ),
          ),
      ],
    );
  }

  Widget _pickerRow({
    required String label,
    required Color color,
    required String? value,
    required List<GrowSpace> spaces,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(label,
          style: AppTypography.labelLarge(context).copyWith(color: color)),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: context.colSurface2,
          decoration: const InputDecoration(isDense: true),
          hint: Text(
            'Select a space…',
            style: TextStyle(color: context.colTextMuted),
          ),
          items: spaces
              .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name,
                        style: TextStyle(color: context.colTextPrimary)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    ]);
  }

  Widget _buildComparisonTable({
    required GrowRepository repo,
    required String idA,
    required String idB,
    required String labelA,
    required String labelB,
    required Color colorA,
    required Color colorB,
  }) {
    final mA = _metricsForSpace(idA, repo.plants, repo.harvestLogs);
    final mB = _metricsForSpace(idB, repo.plants, repo.harvestLogs);

    return AppCard(
      child: Column(children: [
        // Header
        Row(children: [
          const SizedBox(width: 140),
          Expanded(child: _colHeader(labelA, colorA)),
          Expanded(child: _colHeader(labelB, colorB)),
        ]),
        Divider(color: context.colBorder, height: 20),

        _compareRow(
            'Total Plants',
            mA.totalPlants.toString(),
            mB.totalPlants.toString(),
            mA.totalPlants.toDouble(),
            mB.totalPlants.toDouble(),
            colorA,
            colorB),
        _compareRow(
            'Completed Harvests',
            mA.completedHarvests.toString(),
            mB.completedHarvests.toString(),
            mA.completedHarvests.toDouble(),
            mB.completedHarvests.toDouble(),
            colorA,
            colorB),
        _compareRow(
            'Avg Dry (g)',
            mA.avgYield != null ? '${mA.avgYield!.toStringAsFixed(1)} g' : '—',
            mB.avgYield != null ? '${mB.avgYield!.toStringAsFixed(1)} g' : '—',
            mA.avgYield ?? 0,
            mB.avgYield ?? 0,
            colorA,
            colorB),
        _compareRow(
            'Best Dry (g)',
            mA.bestYield != null ? '${mA.bestYield!.toStringAsFixed(1)} g' : '—',
            mB.bestYield != null ? '${mB.bestYield!.toStringAsFixed(1)} g' : '—',
            mA.bestYield ?? 0,
            mB.bestYield ?? 0,
            colorA,
            colorB),
        _compareRow(
            'Total Dry (g)',
            mA.totalDryWeight.toStringAsFixed(1),
            mB.totalDryWeight.toStringAsFixed(1),
            mA.totalDryWeight,
            mB.totalDryWeight,
            colorA,
            colorB),
        _compareRow(
            'Failure Rate',
            '${mA.failureRate.toStringAsFixed(1)}%',
            '${mB.failureRate.toStringAsFixed(1)}%',
            // lower is better — invert
            100 - mA.failureRate,
            100 - mB.failureRate,
            colorA,
            colorB),
      ]),
    );
  }

  Widget _colHeader(String label, Color color) {
    return Text(label,
        textAlign: TextAlign.center,
        style: AppTypography.labelLarge(context).copyWith(color: color));
  }

  Widget _compareRow(
    String metric,
    String valA,
    String valB,
    double numA,
    double numB,
    Color colorA,
    Color colorB,
  ) {
    final aWins = numA > numB;
    final tied = numA == numB;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
          width: 140,
          child: Text(metric, style: AppTypography.bodyMedium(context)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: (!tied && aWins)
                  ? colorA.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(valA,
                textAlign: TextAlign.center,
                style: AppTypography.labelLarge(context).copyWith(
                    color:
                        (!tied && aWins) ? colorA : context.colTextSecondary)),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: (!tied && !aWins)
                  ? colorB.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(valB,
                textAlign: TextAlign.center,
                style: AppTypography.labelLarge(context).copyWith(
                    color:
                        (!tied && !aWins) ? colorB : context.colTextSecondary)),
          ),
        ),
      ]),
    );
  }

  // ── Grow vs Grow (strain-based) ───────────────

  Widget _buildGrowComparison(GrowRepository repo) {
    // Build harvest-log lookup so edits are reflected in yield calculations.
    final logByPlantId = <String, HarvestLog>{};
    for (final log in repo.harvestLogs) {
      logByPlantId[log.plantId] = log;
    }

    final completedByStrain = <String, List<Plant>>{};

    for (final plant in repo.plants) {
      if (!plant.isArchived || plant.status != PlantStatus.completed) {
        continue;
      }
      final key = plant.strainId ?? plant.strain.toLowerCase().trim();
      completedByStrain.putIfAbsent(key, () => []).add(plant);
    }

    if (completedByStrain.isEmpty) {
      return const EmptyState(
        art: EmptyArt.compare,
        title: 'No Completed Grows',
        subtitle: 'Take a plant through its full lifecycle\nto unlock grow comparisons.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: completedByStrain.entries.map((entry) {
        final strainName =
            repo.strainById(entry.key)?.name ?? entry.value.first.strain;
        final plants = entry.value;

        final yields = plants.where((p) {
          final log = logByPlantId[p.id];
          final dry = log?.dryWeight ?? p.dryWeight;
          return dry != null && dry > 0;
        }).map((p) {
          final log = logByPlantId[p.id];
          return (log?.dryWeight ?? p.dryWeight)!;
        }).toList();

        final avgYield = yields.isNotEmpty
            ? yields.reduce((a, b) => a + b) / yields.length
            : null;

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(strainName, style: AppTypography.headlineSmall(context)),
                  if (avgYield != null)
                    Text(
                      'Avg ${avgYield.toStringAsFixed(1)} g',
                      style: AppTypography.labelLarge(context)
                          .copyWith(color: AppColors.primary),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                  '${plants.length} completed grow${plants.length == 1 ? '' : 's'}',
                  style: AppTypography.bodySmall(context)),
              const SizedBox(height: AppSpacing.sm),

              // Mini bar chart per grow
              if (yields.isNotEmpty) ...[
                Divider(color: context.colBorder),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: plants.asMap().entries.map((e) {
                    final p = e.value;
                    final log = logByPlantId[p.id];
                    final dry = log?.dryWeight ?? p.dryWeight;
                    if (dry == null || dry <= 0) {
                      return const SizedBox.shrink();
                    }
                    final maxY = yields.reduce((a, b) => a > b ? a : b);
                    final fraction = maxY > 0 ? dry / maxY : 0.0;
                    final isSuccess = dry >= (avgYield ?? 0);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${dry.toStringAsFixed(0)} g',
                              style: AppTypography.bodySmall(context)
                                  .copyWith(fontSize: 9),
                            ),
                            const SizedBox(height: 3),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              height: 60 * fraction,
                              decoration: BoxDecoration(
                                color: isSuccess
                                    ? AppColors.growing
                                    : AppColors.danger,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'G${e.key + 1}',
                              style: AppTypography.bodySmall(context)
                                  .copyWith(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Metrics model ─────────────────────────────────

class _SpaceMetrics {
  final int totalPlants;
  final int completedHarvests;
  final double? avgYield;
  final double? bestYield;
  final double totalDryWeight;
  final int removedCount;
  final double failureRate;

  const _SpaceMetrics({
    required this.totalPlants,
    required this.completedHarvests,
    required this.avgYield,
    required this.bestYield,
    required this.totalDryWeight,
    required this.removedCount,
    required this.failureRate,
  });
}
