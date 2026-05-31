import 'package:flutter/material.dart';

import '../models/environment_log.dart';
import '../models/grow_space.dart';
import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/plant_environment_analytics.dart';
import '../utils/temp_format.dart';
import '../utils/vpd_analytics.dart';
import '../widgets/app_card.dart';

// ── Aggregated per-phase stats ────────────────────────────────────────────────
//
// Accumulates VPD values and optimal-zone counts across all plants in a space
// so the analytics screen can show space-level (not per-plant) breakdowns.

class _PhaseAgg {
  final List<double> vpds;
  final int total;   // readings with both temp + humidity
  final int optimal; // readings where space.isOptimal() returned true

  const _PhaseAgg({this.vpds = const [], this.total = 0, this.optimal = 0});

  _PhaseAgg add(double vpd, bool isOpt) => _PhaseAgg(
        vpds: [...vpds, vpd],
        total: total + 1,
        optimal: optimal + (isOpt ? 1 : 0),
      );

  double get avgVpd =>
      vpds.isEmpty ? 0 : vpds.reduce((a, b) => a + b) / vpds.length;

  double get optimalPct => total == 0 ? 0 : optimal / total * 100;

  /// % of VPD readings in [phase]'s ideal band.
  double vpdPctInRange(GrowPhase phase) {
    if (vpds.isEmpty) return 0;
    final inRange = vpds
        .where((v) => v >= phase.targetLow && v <= phase.targetHigh)
        .length;
    return inRange / vpds.length * 100;
  }

  VpdStatus vpdStatus(GrowPhase phase) {
    if (avgVpd < phase.targetLow) return VpdStatus.low;
    if (avgVpd > phase.targetHigh) return VpdStatus.high;
    return VpdStatus.ideal;
  }

  /// Minimum threshold for showing a phase row — avoids noise from 1–2 readings.
  bool get hasData => total >= 3;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SpaceEnvironmentAnalyticsScreen extends StatefulWidget {
  final GrowSpace space;

  /// ALL environment logs from the repository.  The screen filters to this
  /// space internally; passing all logs lets per-plant helpers (which also
  /// filter by grow-space ID) work correctly without a separate pass.
  final List<EnvironmentLog> logs;

  /// ALL plants that have ever been assigned to this space, including archived
  /// ones. Archived plants contribute historical phase data.
  final List<Plant> plants;

  const SpaceEnvironmentAnalyticsScreen({
    super.key,
    required this.space,
    required this.logs,
    required this.plants,
  });

  @override
  State<SpaceEnvironmentAnalyticsScreen> createState() =>
      _SpaceEnvironmentAnalyticsScreenState();
}

class _SpaceEnvironmentAnalyticsScreenState
    extends State<SpaceEnvironmentAnalyticsScreen> {
  // ── Time window ───────────────────────────────────────────────────────────
  // Controls the headline stats and streak sections.
  // Phase breakdowns always use all-time data (plant windows define phases).
  static const _windows = [
    (label: '7 days', days: 7),
    (label: '30 days', days: 30),
    (label: 'All time', days: -1),
  ];
  int _windowDays = 30;

  // ── Data helpers ──────────────────────────────────────────────────────────

  /// All logs for this space, newest-first.
  List<EnvironmentLog> _spaceLogs() => widget.logs
      .where((l) => l.growSpaceId == widget.space.id)
      .toList()
    ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

  List<EnvironmentLog> _windowed(List<EnvironmentLog> all) {
    if (_windowDays < 0) return all;
    final cutoff = DateTime.now().subtract(Duration(days: _windowDays));
    return all.where((l) => l.recordedAt.isAfter(cutoff)).toList();
  }

  double? _optimalPct(List<EnvironmentLog> logs) {
    final complete = logs
        .where((l) => l.temperature != null && l.humidity != null)
        .toList();
    if (complete.isEmpty) return null;
    final inRange = complete
        .where((l) =>
            widget.space.isOptimal(l.temperature!, l.humidity!))
        .length;
    return inRange / complete.length * 100;
  }

  double? _avgTemp(List<EnvironmentLog> logs) {
    final vals = logs
        .where((l) => l.temperature != null)
        .map((l) => l.temperature!)
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  double? _avgHumidity(List<EnvironmentLog> logs) {
    final vals = logs
        .where((l) => l.humidity != null)
        .map((l) => l.humidity!)
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  /// Aggregates VPD and optimal-% by grow phase across all plants in the space.
  /// A log is attributed to a phase when it falls inside any plant's grow window.
  Map<GrowPhase, _PhaseAgg> _buildPhaseAgg(List<EnvironmentLog> spaceLogs) {
    final result = <GrowPhase, _PhaseAgg>{};
    for (final log in spaceLogs) {
      if (log.temperature == null || log.humidity == null) continue;
      final vpd = computeVpd(log.temperature!, log.humidity!);
      final isOpt =
          widget.space.isOptimal(log.temperature!, log.humidity!);
      for (final plant in widget.plants) {
        final phase = growPhaseForTimestamp(log.recordedAt, plant);
        if (phase == null) continue;
        result[phase] =
            (result[phase] ?? const _PhaseAgg()).add(vpd, isOpt);
      }
    }
    return result;
  }

  /// Pairs each plant with its VPD summary; omits plants with insufficient data.
  List<(Plant, PlantVpdSummary)> _plantSummaries() => widget.plants
      .map((p) => (p, computePlantVpdAnalytics(p, widget.logs)))
      .where((pair) => pair.$2.hasData)
      .toList();

  /// Returns the current streak (consecutive equal-status readings from latest).
  ({int streak, bool inRange})? _currentStreak(List<EnvironmentLog> logs) {
    final complete = logs
        .where((l) => l.temperature != null && l.humidity != null)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (complete.isEmpty) return null;

    final first = widget.space.isOptimal(
        complete.first.temperature!, complete.first.humidity!);
    int count = 1;
    for (int i = 1; i < complete.length; i++) {
      final inRange = widget.space.isOptimal(
          complete[i].temperature!, complete[i].humidity!);
      if (inRange != first) break;
      count++;
    }
    return (streak: count, inRange: first);
  }

  /// Longest consecutive sequence of in-range readings across all time.
  int _longestInRange(List<EnvironmentLog> logs) {
    final complete = logs
        .where((l) => l.temperature != null && l.humidity != null)
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt)); // oldest first
    int longest = 0, current = 0;
    for (final l in complete) {
      if (widget.space.isOptimal(l.temperature!, l.humidity!)) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allLogs = _spaceLogs();
    final winLogs = _windowed(allLogs);
    final pct = _optimalPct(winLogs);
    final avgT = _avgTemp(winLogs);
    final avgH = _avgHumidity(winLogs);
    final phases = _buildPhaseAgg(allLogs);
    final hasPhaseData = phases.values.any((a) => a.hasData);
    final streak = _currentStreak(allLogs);
    final longest = _longestInRange(allLogs);
    final summaries = _plantSummaries();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics', style: AppTypography.headlineMedium(context)),
            Text(widget.space.name,
                style: AppTypography.bodySmall(context)
                    .copyWith(color: context.colTextMuted)),
          ],
        ),
      ),
      body: allLogs.isEmpty
          ? _emptyState(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.pagePadding,
                AppSpacing.pagePadding,
                120,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Time window selector ──────────
                  _buildWindowSelector(context),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Headline stats ────────────────
                  _buildHeadlineStats(context, winLogs, pct, avgT, avgH),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Optimal zone breakdown ─────────
                  if (pct != null) ...[
                    _buildOptimalZone(context, winLogs, pct),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // ── Streak ────────────────────────
                  if (streak != null) ...[
                    _buildStreakCard(context, streak, longest),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // ── Phase breakdown ───────────────
                  if (hasPhaseData) ...[
                    _buildPhaseCard(context, phases),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // ── Per-plant VPD ─────────────────
                  if (summaries.isNotEmpty) ...[
                    _sectionHeader(
                        context, Icons.eco_rounded, 'Per-Plant VPD'),
                    const SizedBox(height: AppSpacing.sm),
                    ...summaries.map(
                      (pair) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _PlantVpdCard(
                          plant: pair.$1,
                          summary: pair.$2,
                          space: widget.space,
                          logs: widget.logs,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 52, color: context.colTextMuted),
            const SizedBox(height: AppSpacing.md),
            Text('No environment data yet',
                style: AppTypography.headlineSmall(context)
                    .copyWith(color: context.colTextMuted)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Log temperature and humidity readings from the space '
              'detail screen to see analytics here.',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Window selector ───────────────────────────────────────────────────────

  Widget _buildWindowSelector(BuildContext context) {
    return Row(
      children: _windows.map((opt) {
        final selected = _windowDays == opt.days;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: GestureDetector(
            onTap: () => setState(() => _windowDays = opt.days),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.secondary.withValues(alpha: 0.15)
                    : context.colSurface2,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: selected
                      ? AppColors.secondary.withValues(alpha: 0.5)
                      : context.colBorder,
                ),
              ),
              child: Text(
                opt.label,
                style: AppTypography.labelLarge(context).copyWith(
                  color:
                      selected ? AppColors.secondary : context.colTextMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Headline stats ────────────────────────────────────────────────────────

  Widget _buildHeadlineStats(
    BuildContext context,
    List<EnvironmentLog> wLogs,
    double? pct,
    double? avgT,
    double? avgH,
  ) {
    final pctColor = pct == null
        ? context.colTextMuted
        : pct >= 75
            ? AppColors.optimal
            : pct >= 50
                ? AppColors.warning
                : AppColors.danger;

    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      child: Row(
        children: [
          _statCell(context,
              label: 'Readings',
              value: '${wLogs.length}',
              color: context.colTextSecondary),
          _statDivider(context),
          _statCell(context,
              label: 'In Optimal',
              value: pct != null ? '${pct.toStringAsFixed(0)}%' : '—',
              color: pctColor),
          _statDivider(context),
          _statCell(context,
              label: 'Avg Temp',
              value: avgT != null ? formatTemp(avgT) : '—',
              color: Colors.orange),
          _statDivider(context),
          _statCell(context,
              label: 'Avg RH',
              value: avgH != null ? '${avgH.toStringAsFixed(0)}%' : '—',
              color: AppColors.water),
        ],
      ),
    );
  }

  Widget _statCell(BuildContext context,
      {required String label, required String value, required Color color}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.headlineSmall(context).copyWith(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.bodySmall(context).copyWith(
              color: context.colTextMuted,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _statDivider(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: context.colBorderFaint,
      );

  // ── Optimal zone breakdown ────────────────────────────────────────────────

  Widget _buildOptimalZone(
    BuildContext context,
    List<EnvironmentLog> wLogs,
    double pct,
  ) {
    final complete = wLogs
        .where((l) => l.temperature != null && l.humidity != null)
        .toList();

    int inRange = 0, tooHot = 0, tooCold = 0, tooWet = 0, tooDry = 0;
    for (final l in complete) {
      final tempOk = widget.space.isOptimalTemp(l.temperature!);
      final humOk = widget.space.isOptimalHumidity(l.humidity!);
      if (tempOk && humOk) {
        inRange++;
      } else {
        if (!tempOk) {
          if (l.temperature! > widget.space.tempMax) { tooHot++; }
          else { tooCold++; }
        }
        if (!humOk) {
          if (l.humidity! > widget.space.humidityMax) { tooWet++; }
          else { tooDry++; }
        }
      }
    }

    final color = pct >= 75
        ? AppColors.optimal
        : pct >= 50
            ? AppColors.warning
            : AppColors.danger;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              context, Icons.thermostat_rounded, 'Optimal Zone'),
          const SizedBox(height: AppSpacing.md),

          // Big % + progress bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: AppTypography.headlineLarge(context).copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('readings in optimal zone',
                        style: AppTypography.bodySmall(context)
                            .copyWith(color: context.colTextMuted)),
                    const SizedBox(height: 5),
                    _bar(context, pct / 100, color, height: 6),
                  ],
                ),
              ),
            ],
          ),

          if (complete.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (inRange > 0)
                  _chip(context, Icons.check_circle_rounded,
                      '$inRange in range', AppColors.optimal),
                if (tooHot > 0)
                  _chip(context, Icons.keyboard_arrow_up_rounded,
                      '$tooHot too hot', AppColors.danger),
                if (tooCold > 0)
                  _chip(context, Icons.keyboard_arrow_down_rounded,
                      '$tooCold too cold', AppColors.info),
                if (tooWet > 0)
                  _chip(context, Icons.water_drop_rounded,
                      '$tooWet too humid', AppColors.water),
                if (tooDry > 0)
                  _chip(context, Icons.dry_rounded,
                      '$tooDry too dry', AppColors.warning),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Streak card ───────────────────────────────────────────────────────────

  Widget _buildStreakCard(
    BuildContext context,
    ({int streak, bool inRange}) current,
    int longestInRange,
  ) {
    final color =
        current.inRange ? AppColors.optimal : AppColors.warning;
    final icon = current.inRange
        ? Icons.local_fire_department_rounded
        : Icons.warning_amber_rounded;
    final description = current.inRange
        ? 'consecutive readings in optimal zone'
        : 'consecutive readings outside optimal zone';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              context, Icons.trending_up_rounded, 'Streak Analysis'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${current.streak}×',
                      style: AppTypography.headlineMedium(context).copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      description,
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (longestInRange >= 2) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(color: context.colBorderFaint, height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              const Icon(Icons.emoji_events_rounded,
                  size: 13, color: AppColors.accent),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Best run: $longestInRange readings in optimal zone',
                style: AppTypography.bodySmall(context)
                    .copyWith(color: context.colTextMuted, fontSize: 11),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Phase breakdown card ──────────────────────────────────────────────────

  Widget _buildPhaseCard(
      BuildContext context, Map<GrowPhase, _PhaseAgg> phases) {
    final activePhases = GrowPhase.values
        .where((p) => phases[p]?.hasData == true)
        .toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, Icons.air_rounded, 'VPD by Grow Phase'),
          const SizedBox(height: 3),
          Text(
            'Aggregated across all plants that have grown in this space.',
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextMuted, fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.md),

          // VPD by phase
          ...activePhases.map((phase) {
            final agg = phases[phase]!;
            final status = agg.vpdStatus(phase);
            final color = _vpdStatusColor(status);
            return _vpdPhaseRow(
              context,
              label: phase.shortLabel,
              avgVpd: agg.avgVpd,
              pctInRange: agg.vpdPctInRange(phase),
              readingCount: agg.total,
              targetLabel: phase.targetLabel,
              color: color,
            );
          }),

          const SizedBox(height: AppSpacing.sm),
          Divider(color: context.colBorderFaint, height: 1),
          const SizedBox(height: AppSpacing.md),

          // Optimal % by phase
          _sectionHeader(
              context, Icons.thermostat_rounded, 'Optimal Zone by Phase'),
          const SizedBox(height: AppSpacing.sm),
          ...activePhases.map((phase) {
            final agg = phases[phase]!;
            return _optimalPhaseRow(context, phase.shortLabel, agg.optimalPct);
          }),
        ],
      ),
    );
  }

  Widget _vpdPhaseRow(
    BuildContext context, {
    required String label,
    required double avgVpd,
    required double pctInRange,
    required int readingCount,
    required String targetLabel,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(label,
                style: AppTypography.bodySmall(context).copyWith(
                  color: context.colTextSecondary,
                  fontSize: 12,
                )),
          ),
          _kpaBadge(context, avgVpd, color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(context, pctInRange / 100, color),
                const SizedBox(height: 3),
                Text(
                  '${pctInRange.toStringAsFixed(0)}% in range · '
                  'target $targetLabel · $readingCount readings',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optimalPhaseRow(
      BuildContext context, String label, double pct) {
    final color = pct >= 75
        ? AppColors.optimal
        : pct >= 50
            ? AppColors.warning
            : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(label,
                style: AppTypography.bodySmall(context).copyWith(
                  color: context.colTextSecondary,
                  fontSize: 12,
                )),
          ),
          _pctBadge(context, pct, color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _bar(context, pct / 100, color)),
        ],
      ),
    );
  }

  // ── Shared primitives ─────────────────────────────────────────────────────

  Widget _bar(BuildContext context, double fraction, Color color,
      {double height = 4}) {
    return LayoutBuilder(builder: (ctx, c) {
      return Stack(children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: context.colSurface3,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
        ),
        Container(
          height: height,
          width: c.maxWidth * fraction.clamp(0.0, 1.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
        ),
      ]);
    });
  }

  Widget _kpaBadge(BuildContext context, double vpd, Color color) =>
      _badge(context, '${vpd.toStringAsFixed(2)} kPa', color);

  Widget _pctBadge(BuildContext context, double pct, Color color) =>
      _badge(context, '${pct.toStringAsFixed(0)}%', color);

  Widget _badge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall(context).copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _chip(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(label,
              style: AppTypography.labelSmall(context)
                  .copyWith(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _sectionHeader(
      BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.colTextMuted),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title.toUpperCase(),
          style: AppTypography.labelSmall(context).copyWith(
            color: context.colTextMuted,
            letterSpacing: 0.8,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  static Color _vpdStatusColor(VpdStatus status) {
    switch (status) {
      case VpdStatus.ideal:
        return AppColors.optimal;
      case VpdStatus.high:
        return AppColors.danger;
      case VpdStatus.low:
        return const Color(0xFF64B5F6); // light blue — "too low" = high humidity
    }
  }
}

// ── Per-plant VPD expansion card ──────────────────────────────────────────────

class _PlantVpdCard extends StatelessWidget {
  final Plant plant;
  final PlantVpdSummary summary;
  final GrowSpace space;
  final List<EnvironmentLog> logs;

  const _PlantVpdCard({
    required this.plant,
    required this.summary,
    required this.space,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    final phaseOptimal = PlantEnvironmentAnalytics.computePhaseOptimalPercent(
      plant: plant,
      space: space,
      logs: logs,
    );
    final insights = PlantEnvironmentAnalytics.generateInsights(
      plant: plant,
      logs: logs,
      space: space,
    );

    final statusColor = summary.overallPctInRange >= 75
        ? AppColors.optimal
        : summary.overallPctInRange >= 50
            ? AppColors.warning
            : AppColors.danger;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        expansionTileTheme: ExpansionTileThemeData(
          backgroundColor: context.colSurface1,
          collapsedBackgroundColor: context.colSurface1,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.only(
            left: AppSpacing.cardPadding,
            right: AppSpacing.cardPadding,
            bottom: AppSpacing.cardPadding,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            side: BorderSide(color: context.colBorder),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            side: BorderSide(color: context.colBorder),
          ),
          iconColor: context.colTextMuted,
          collapsedIconColor: context.colTextMuted,
        ),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plant.name,
                      style: AppTypography.labelLarge(context)),
                  Text(plant.strain,
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextMuted)),
                ],
              ),
            ),
            _overallBadge(context, statusColor),
          ],
        ),
        children: [
          // VPD by phase
          if (summary.phases.isNotEmpty) ...[
            _miniHeader(context, 'VPD by Phase'),
            const SizedBox(height: AppSpacing.xs),
            ...summary.phases.map((r) => _vpdRow(context, r)),
          ],

          // Optimal % by phase
          if (phaseOptimal.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _miniHeader(context, 'Optimal Zone by Phase'),
            const SizedBox(height: AppSpacing.xs),
            ...GrowPhase.values
                .where((p) => phaseOptimal.containsKey(p))
                .map((p) => _optRow(context, p, phaseOptimal[p]!)),
          ],

          // Insights
          if (insights.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _miniHeader(context, 'Insights'),
            const SizedBox(height: AppSpacing.xs),
            ...insights.map((i) => _insightRow(context, i)),
          ],
        ],
      ),
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Widget _overallBadge(BuildContext context, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${summary.overallPctInRange.toStringAsFixed(0)}% VPD',
        style: AppTypography.labelSmall(context)
            .copyWith(color: color, fontSize: 11),
      ),
    );
  }

  Widget _miniHeader(BuildContext context, String title) => Text(
        title.toUpperCase(),
        style: AppTypography.labelSmall(context).copyWith(
          color: context.colTextMuted,
          fontSize: 9,
          letterSpacing: 0.8,
        ),
      );

  Widget _vpdRow(BuildContext context, VpdPhaseResult r) {
    final color = _vpdStatusColor(r.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(r.phase.shortLabel,
                style: AppTypography.bodySmall(context).copyWith(
                    fontSize: 11, color: context.colTextSecondary)),
          ),
          _smallBadge(context,
              '${r.avgVpd.toStringAsFixed(2)} kPa', color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '${r.pctInRange.toStringAsFixed(0)}% in range · '
              '${r.readingCount} readings',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optRow(BuildContext context, GrowPhase phase, double pct) {
    final color = pct >= 75
        ? AppColors.optimal
        : pct >= 50
            ? AppColors.warning
            : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(phase.shortLabel,
                style: AppTypography.bodySmall(context).copyWith(
                    fontSize: 11, color: context.colTextSecondary)),
          ),
          _smallBadge(context, '${pct.toStringAsFixed(0)}%', color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: LayoutBuilder(builder: (ctx, c) {
              return Stack(children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: ctx.colSurface3,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
                Container(
                  height: 3,
                  width: c.maxWidth * (pct / 100).clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
              ]);
            }),
          ),
        ],
      ),
    );
  }

  Widget _insightRow(BuildContext context, PlantEnvironmentInsight i) {
    final color = i.severity == InsightSeverity.positive
        ? AppColors.growing
        : i.severity == InsightSeverity.warning
            ? AppColors.warning
            : context.colTextMuted;
    final icon = i.severity == InsightSeverity.positive
        ? Icons.check_circle_rounded
        : i.severity == InsightSeverity.warning
            ? Icons.warning_rounded
            : Icons.info_rounded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Expanded(
            child: Text(i.message,
                style: AppTypography.bodySmall(context)
                    .copyWith(color: color, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _smallBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text,
          style: AppTypography.labelSmall(context)
              .copyWith(color: color, fontSize: 10)),
    );
  }

  static Color _vpdStatusColor(VpdStatus status) {
    switch (status) {
      case VpdStatus.ideal:
        return AppColors.optimal;
      case VpdStatus.high:
        return AppColors.danger;
      case VpdStatus.low:
        return const Color(0xFF64B5F6);
    }
  }
}
