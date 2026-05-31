import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/grow_space.dart';
import '../models/plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'plant_detail_screen.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const _kDayWidth = 7.0; // pixels per day
const _kRowHeight = 56.0; // height of each plant row
const _kBarHeight = 20.0; // height of the coloured phase bar
const _kBarOffsetY = (_kRowHeight - _kBarHeight) / 2; // vertical centre
const _kNameColW = 112.0; // sticky plant-name column width
const _kRulerH = 38.0; // date ruler height
const _kMinDays = 60; // minimum total date-span shown

// ── Phase colours ─────────────────────────────────────────────────────────────
const _colVeg = AppColors.growing; // teal
const _colFlower = AppColors.secondary; // purple
const _colDrying = AppColors.drying; // amber
const _colCuring = AppColors.info; // blue (distinct from flower purple)

// ─────────────────────────────────────────────────────────────────────────────
// SpaceTimelineScreen
//
// Gantt-style multi-plant timeline. Each row represents one plant; columns are
// days. Phase bars are coloured by grow stage (veg / flower / drying / curing).
// A vertical "Today" line is drawn across all rows. Tap a plant name to open
// its PlantDetailScreen.
// ─────────────────────────────────────────────────────────────────────────────

class SpaceTimelineScreen extends StatelessWidget {
  final GrowSpace space;
  final List<Plant> plants;

  const SpaceTimelineScreen({
    super.key,
    required this.space,
    required this.plants,
  });

  // ── Date-range helpers ───────────────────────────

  DateTime _earliest(List<Plant> sorted) =>
      sorted.map((p) => p.startDate).reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime _latest(List<Plant> sorted) {
    final today = DateTime.now();
    DateTime latest = today.add(const Duration(days: 14));
    for (final p in sorted) {
      final candidates = [
        if (p.curingEndDate != null) p.curingEndDate!,
        if (p.archivedAt != null) p.archivedAt!,
        // Drying: add a small buffer so the bar doesn't clip
        if (p.dryingEndDate != null)
          p.dryingEndDate!.add(const Duration(days: 14)),
        // Expected harvest: show target + drying buffer
        if (p.targetHarvestDate != null)
          p.targetHarvestDate!.add(const Duration(days: 21)),
      ];
      for (final d in candidates) {
        if (d.isAfter(latest)) latest = d;
      }
    }
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    if (plants.isEmpty) {
      return Scaffold(
        backgroundColor: context.colBg,
        appBar: _appBar(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timeline_rounded,
                  size: 48, color: context.colTextMuted),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No plants in this space yet.',
                style: AppTypography.bodyMedium(context)
                    .copyWith(color: context.colTextSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Oldest plant at top of list
    final sorted = [...plants]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final earliest = _earliest(sorted);
    final latest = _latest(sorted);
    final totalDays =
        math.max(_kMinDays, latest.difference(earliest).inDays);
    final todayDays =
        DateTime.now().difference(earliest).inDays.clamp(0, totalDays);

    return Scaffold(
      backgroundColor: context.colBg,
      appBar: _appBar(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendBar(),
          Container(height: 1, color: context.colBorder),
          Expanded(
            child: _TimelineGrid(
              plants: sorted,
              earliest: earliest,
              totalDays: totalDays,
              todayDays: todayDays,
              onPlantTap: (p) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PlantDetailScreen(plant: p, siblings: sorted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _appBar(BuildContext context) => AppBar(
        backgroundColor: context.colBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Timeline', style: AppTypography.headlineSmall(context)),
            Text(
              space.name,
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted),
            ),
          ],
        ),
      );
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _LegendBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          _dot(_colVeg, 'Veg', context),
          _dot(_colFlower, 'Flower', context),
          _dot(_colDrying, 'Drying', context),
          _dot(_colCuring, 'Curing', context),
          const SizedBox(width: AppSpacing.md),
          // Today indicator swatch
          Container(
            width: 14,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'Today',
            style: AppTypography.labelSmall(context)
                .copyWith(color: context.colTextSecondary),
          ),
          const SizedBox(width: AppSpacing.md),
          // Target-harvest swatch
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.65), width: 1.5),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'Target harvest',
            style: AppTypography.labelSmall(context)
                .copyWith(color: context.colTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, String label, BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              label,
              style: AppTypography.labelSmall(context)
                  .copyWith(color: context.colTextSecondary),
            ),
          ],
        ),
      );
}

// ── Timeline grid (sticky names + scrollable bars) ───────────────────────────

class _TimelineGrid extends StatelessWidget {
  final List<Plant> plants;
  final DateTime earliest;
  final int totalDays;
  final int todayDays;
  final void Function(Plant) onPlantTap;

  const _TimelineGrid({
    required this.plants,
    required this.earliest,
    required this.totalDays,
    required this.todayDays,
    required this.onPlantTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalWidth = totalDays * _kDayWidth;
    final todayX = todayDays * _kDayWidth;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sticky name column ────────────────────
        SizedBox(
          width: _kNameColW,
          child: Column(
            children: [
              // Spacer row aligns with the date ruler
              Container(
                height: _kRulerH,
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: context.colBorder),
                  ),
                ),
                child: Text(
                  '${plants.length} plant${plants.length == 1 ? '' : 's'}',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 10),
                ),
              ),
              // Plant name cells
              ...plants.map(
                (p) => _NameCell(plant: p, onTap: () => onPlantTap(p)),
              ),
            ],
          ),
        ),

        // Vertical separator
        Container(width: 1, color: context.colBorder),

        // ── Scrollable timeline ───────────────────
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Scroll to show "today" on first load by using a key offset
            child: SizedBox(
              width: totalWidth,
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date ruler
                      _DateRuler(
                          earliest: earliest, totalDays: totalDays),
                      // Plant bar rows with alternating background tint
                      ...plants.asMap().entries.map(
                            (e) => Container(
                              width: totalWidth,
                              height: _kRowHeight,
                              color: e.key.isEven
                                  ? Colors.transparent
                                  : context.colSurface1
                                      .withValues(alpha: 0.4),
                              child: _PlantBarRow(
                                plant: e.value,
                                earliest: earliest,
                                totalDays: totalDays,
                              ),
                            ),
                          ),
                    ],
                  ),

                  // ── Today vertical line ───────────
                  Positioned(
                    left: todayX,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1.5,
                      color: AppColors.primary.withValues(alpha: 0.65),
                    ),
                  ),

                  // "Now" label pinned to the ruler
                  Positioned(
                    left: todayX - 13,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Now',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sticky plant-name cell ────────────────────────────────────────────────────

class _NameCell extends StatelessWidget {
  final Plant plant;
  final VoidCallback onTap;

  const _NameCell({required this.plant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dot = _statusDotColor(plant.status);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _kRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: dot),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.name,
                      style: AppTypography.labelSmall(context).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      plant.strain,
                      style: AppTypography.bodySmall(context).copyWith(
                        fontSize: 10,
                        color: context.colTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 12, color: context.colTextMuted),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusDotColor(PlantStatus s) {
    switch (s) {
      case PlantStatus.growing:
        return AppColors.growing;
      case PlantStatus.harvested:
        return AppColors.harvested;
      case PlantStatus.drying:
        return AppColors.drying;
      case PlantStatus.curing:
        return AppColors.curing;
      case PlantStatus.completed:
        return AppColors.completed;
      case PlantStatus.removed:
        return AppColors.removed;
    }
  }
}

// ── Date ruler ────────────────────────────────────────────────────────────────

class _DateRuler extends StatelessWidget {
  final DateTime earliest;
  final int totalDays;

  const _DateRuler({required this.earliest, required this.totalDays});

  @override
  Widget build(BuildContext context) {
    // Collect (x, label) for the first day of each month in the range
    final marks = <({double x, String label})>[];
    // Start from the first complete month at or after `earliest`
    var cursor = DateTime(earliest.year, earliest.month, 1);
    if (cursor.isBefore(earliest)) {
      cursor = DateTime(earliest.year, earliest.month + 1, 1);
    }
    while (true) {
      final offsetDays = cursor.difference(earliest).inDays;
      if (offsetDays > totalDays) break;
      marks.add((
        x: offsetDays * _kDayWidth,
        label: _label(cursor),
      ));
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return SizedBox(
      height: _kRulerH,
      child: Stack(
        children: [
          // Bottom border
          Positioned(
            bottom: 0,
            left: 0,
            right: totalDays * _kDayWidth,
            child: Container(height: 1, color: context.colBorder),
          ),
          // Month tick + label
          ...marks.map(
            (m) => Positioned(
              left: m.x,
              top: 0,
              bottom: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 1,
                    height: 8,
                    margin: const EdgeInsets.only(bottom: 1),
                    color: context.colBorder,
                  ),
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      m.label,
                      style: AppTypography.labelSmall(context).copyWith(
                        fontSize: 10,
                        color: context.colTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _label(DateTime d) =>
      '${_months[d.month - 1]} ${d.year.toString().substring(2)}';
}

// ── Plant bar row ─────────────────────────────────────────────────────────────

class _PlantBarRow extends StatelessWidget {
  final Plant plant;
  final DateTime earliest;
  final int totalDays;

  const _PlantBarRow({
    required this.plant,
    required this.earliest,
    required this.totalDays,
  });

  double _x(DateTime d) =>
      d.difference(earliest).inDays.clamp(0, totalDays) * _kDayWidth;

  double _span(DateTime from, DateTime to) => math.max(
        2.0,
        (to.difference(from).inDays.clamp(0, totalDays) * _kDayWidth)
            .toDouble(),
      );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // ── Phase bars ─────────────────────────────────
    final phases = <_PhaseBar>[];

    // Veg: startDate → flipDate / harvestedDate / today
    final vegEnd = plant.flipDate ??
        plant.harvestedDate ??
        (plant.status == PlantStatus.growing ? now : null);
    if (vegEnd != null && vegEnd.isAfter(plant.startDate)) {
      phases.add(_PhaseBar(
        left: _x(plant.startDate),
        width: _span(plant.startDate, vegEnd),
        color: _colVeg,
        label: 'Veg',
      ));
    }

    // Flower: flipDate → harvestedDate / today
    if (plant.flipDate != null) {
      final flowerEnd = plant.harvestedDate ??
          (plant.status == PlantStatus.growing ? now : null);
      if (flowerEnd != null && flowerEnd.isAfter(plant.flipDate!)) {
        phases.add(_PhaseBar(
          left: _x(plant.flipDate!),
          width: _span(plant.flipDate!, flowerEnd),
          color: _colFlower,
          label: 'Flower',
        ));
      }
    }

    // Drying: harvestedDate → dryingEndDate / today
    if (plant.harvestedDate != null) {
      final dryEnd = plant.dryingEndDate ??
          (plant.status == PlantStatus.drying ? now : null);
      if (dryEnd != null) {
        phases.add(_PhaseBar(
          left: _x(plant.harvestedDate!),
          width: _span(plant.harvestedDate!, dryEnd),
          color: _colDrying,
          label: 'Dry',
        ));
      }
    }

    // Curing: dryingEndDate → curingEndDate / archivedAt / today
    if (plant.dryingEndDate != null &&
        (plant.status == PlantStatus.curing ||
            plant.status == PlantStatus.completed)) {
      final cureEnd = plant.curingEndDate ??
          plant.archivedAt ??
          (plant.status == PlantStatus.curing ? now : null);
      if (cureEnd != null) {
        phases.add(_PhaseBar(
          left: _x(plant.dryingEndDate!),
          width: _span(plant.dryingEndDate!, cureEnd),
          color: _colCuring,
          label: 'Cure',
        ));
      }
    }

    // ── Milestone markers ──────────────────────────
    final milestones = <_Milestone>[];

    // Flip-to-flower
    if (plant.flipDate != null) {
      milestones.add(_Milestone(
        x: _x(plant.flipDate!),
        icon: Icons.wb_twilight_rounded,
        color: _colFlower,
        tooltip: 'Flipped to flower',
      ));
    }

    // Harvest
    if (plant.harvestedDate != null) {
      milestones.add(_Milestone(
        x: _x(plant.harvestedDate!),
        icon: Icons.agriculture_rounded,
        color: _colDrying,
        tooltip: 'Harvested',
      ));
    }

    // Target harvest (future only, shown as a ghost marker)
    if (plant.targetHarvestDate != null &&
        plant.harvestedDate == null &&
        plant.targetHarvestDate!.isAfter(now)) {
      milestones.add(_Milestone(
        x: _x(plant.targetHarvestDate!),
        icon: Icons.flag_rounded,
        color: AppColors.accent.withValues(alpha: 0.65),
        tooltip: 'Target harvest',
        isDashed: true,
      ));
    }

    return SizedBox(
      height: _kRowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Phase bars
          ...phases.map(
            (ph) => Positioned(
              left: ph.left,
              top: _kBarOffsetY,
              child: Container(
                width: ph.width,
                height: _kBarHeight,
                decoration: BoxDecoration(
                  color: ph.color.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: ph.width > 28
                    ? Text(
                        ph.label,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: 0.3,
                        ),
                      )
                    : null,
              ),
            ),
          ),

          // Milestone markers (drawn above the bar)
          ...milestones.map(
            (m) => Positioned(
              left: m.x - 8,
              top: _kBarOffsetY - 9,
              child: Tooltip(
                message: m.tooltip,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        m.isDashed ? Colors.transparent : AppColors.bg,
                    border: Border.all(
                      color: m.color,
                      width: m.isDashed ? 1 : 1.5,
                    ),
                  ),
                  child: Icon(m.icon, size: 8, color: m.color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private data classes ──────────────────────────────────────────────────────

class _PhaseBar {
  final double left;
  final double width;
  final Color color;
  final String label;

  const _PhaseBar({
    required this.left,
    required this.width,
    required this.color,
    required this.label,
  });
}

class _Milestone {
  final double x;
  final IconData icon;
  final Color color;
  final String tooltip;
  final bool isDashed;

  const _Milestone({
    required this.x,
    required this.icon,
    required this.color,
    required this.tooltip,
    this.isDashed = false,
  });
}
