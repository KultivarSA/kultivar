import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plant.dart';
import '../models/plant_note.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'plant_detail_screen.dart';

/// F3 — Calendar view.
///
/// Renders a custom monthly grid that aggregates four event sources:
/// 1. **Scheduled care reminders** (watering / feeding / IPM) — projected
///    forward from the most recent care note for each plant using the
///    plant's configured interval.
/// 2. **Stage flips** (`Plant.flipDate`) — historical, marks when a plant
///    moved to 12/12.
/// 3. **Target & actual harvests** (`Plant.targetHarvestDate`,
///    `harvestedDate`).
/// 4. **Historical notes** — any PlantNote on that day.
///
/// Custom widget (no `table_calendar` dependency) so we don't pull in
/// another package while the win32 diamond from P4 is still unresolved.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

// ── Event model ──────────────────────────────────────────────────────────────

enum _EventKind {
  watering,
  feeding,
  ipm,
  flip,
  targetHarvest,
  actualHarvest,
  note,
}

extension _EventKindExt on _EventKind {
  Color get color {
    switch (this) {
      case _EventKind.watering:
        return AppColors.water;
      case _EventKind.feeding:
        return AppColors.accent;
      case _EventKind.ipm:
        return AppColors.ipmColor;
      case _EventKind.flip:
        return AppColors.training;
      case _EventKind.targetHarvest:
        return AppColors.harvested;
      case _EventKind.actualHarvest:
        return AppColors.growing;
      case _EventKind.note:
        return AppColors.secondary;
    }
  }

  IconData get icon {
    switch (this) {
      case _EventKind.watering:
        return Icons.water_drop_rounded;
      case _EventKind.feeding:
        return Icons.eco_rounded;
      case _EventKind.ipm:
        return Icons.bug_report_rounded;
      case _EventKind.flip:
        return Icons.flip_camera_android_rounded;
      case _EventKind.targetHarvest:
        return Icons.agriculture_outlined;
      case _EventKind.actualHarvest:
        return Icons.agriculture_rounded;
      case _EventKind.note:
        return Icons.notes_rounded;
    }
  }

  String label(Plant plant) {
    switch (this) {
      case _EventKind.watering:
        return '${plant.name} · Watering due';
      case _EventKind.feeding:
        return '${plant.name} · Feeding due';
      case _EventKind.ipm:
        return '${plant.name} · IPM spray due';
      case _EventKind.flip:
        return '${plant.name} · Flipped to 12/12';
      case _EventKind.targetHarvest:
        return '${plant.name} · Target harvest';
      case _EventKind.actualHarvest:
        return '${plant.name} · Harvested';
      case _EventKind.note:
        return plant.name;
    }
  }
}

class _CalEvent {
  final DateTime date;
  final Plant plant;
  final _EventKind kind;
  // For notes the actual note is carried so we can show the category +
  // content in the day sheet.
  final PlantNote? note;
  // True for *projected* (future) care reminders so the day sheet can
  // visually distinguish them from completed/logged events.
  final bool projected;

  _CalEvent({
    required this.date,
    required this.plant,
    required this.kind,
    this.note,
    this.projected = false,
  });
}

// ── Screen ───────────────────────────────────────────────────────────────────

class _CalendarScreenState extends State<CalendarScreen> {
  /// First day of the currently displayed month (always day 1, midnight).
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
  }

  // ── Event aggregation ─────────────────────────

  /// Builds the full event list for the visible month plus one day of padding
  /// on either side (so the leading/trailing week rows from adjacent months
  /// pick up their own events too).
  Map<DateTime, List<_CalEvent>> _buildEventsForMonth(GrowRepository repo) {
    final monthStart = _visibleMonth;
    final monthEnd =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    // Visible grid actually spans 6 weeks of cells; widen the window a
    // little so adjacent-month dots show up.
    final from = monthStart.subtract(const Duration(days: 7));
    final to = monthEnd.add(const Duration(days: 7));

    final events = <_CalEvent>[];

    // Plant lookup for note rows.
    final plantById = repo.plantsById;

    // ── Plant-derived events ───────────────────
    for (final plant in repo.plants) {
      // Skip archived plants — their care reminders aren't useful anymore,
      // but we still want to surface harvest/flip history.
      // Stage flip
      if (plant.flipDate != null &&
          _inRange(plant.flipDate!, from, to)) {
        events.add(_CalEvent(
          date: _dateOnly(plant.flipDate!),
          plant: plant,
          kind: _EventKind.flip,
        ));
      }

      // Target harvest
      if (plant.targetHarvestDate != null &&
          _inRange(plant.targetHarvestDate!, from, to)) {
        events.add(_CalEvent(
          date: _dateOnly(plant.targetHarvestDate!),
          plant: plant,
          kind: _EventKind.targetHarvest,
        ));
      }

      // Actual harvest
      if (plant.harvestedDate != null &&
          _inRange(plant.harvestedDate!, from, to)) {
        events.add(_CalEvent(
          date: _dateOnly(plant.harvestedDate!),
          plant: plant,
          kind: _EventKind.actualHarvest,
        ));
      }

      // Skip projecting care reminders for non-active plants.
      if (plant.isArchived || plant.status != PlantStatus.growing) continue;

      // Project care reminders forward from the last care note of each
      // category, or from start date if the plant has never been watered/
      // fed/sprayed.  Cap projection at the visible window's end.
      if (plant.wateringReminderEnabled) {
        _addProjectedCare(events, repo.notes, plant,
            NoteCategory.watering, _EventKind.watering,
            plant.wateringIntervalDays, from, to);
      }
      if (plant.feedingReminderEnabled) {
        _addProjectedCare(events, repo.notes, plant,
            NoteCategory.feeding, _EventKind.feeding,
            plant.feedingIntervalDays, from, to);
      }
      if (plant.ipmReminderEnabled) {
        _addProjectedCare(events, repo.notes, plant,
            NoteCategory.ipm, _EventKind.ipm,
            plant.ipmIntervalDays, from, to);
      }
    }

    // ── Historical notes ───────────────────────
    for (final n in repo.notes) {
      if (!_inRange(n.createdAt, from, to)) continue;
      final plant = plantById[n.plantId];
      if (plant == null) continue;
      events.add(_CalEvent(
        date: _dateOnly(n.createdAt),
        plant: plant,
        kind: _EventKind.note,
        note: n,
      ));
    }

    // Bucket by day.
    final byDay = <DateTime, List<_CalEvent>>{};
    for (final ev in events) {
      (byDay[ev.date] ??= <_CalEvent>[]).add(ev);
    }
    // Sort each day's events: projected last, then by kind for stability.
    for (final list in byDay.values) {
      list.sort((a, b) {
        if (a.projected != b.projected) return a.projected ? 1 : -1;
        return a.kind.index.compareTo(b.kind.index);
      });
    }
    return byDay;
  }

  /// Project care reminders for one category, between [from] and [to].
  void _addProjectedCare(
    List<_CalEvent> out,
    List<PlantNote> notes,
    Plant plant,
    NoteCategory category,
    _EventKind kind,
    int intervalDays,
    DateTime from,
    DateTime to,
  ) {
    if (intervalDays <= 0) return;
    DateTime? lastCare;
    for (final n in notes) {
      if (n.plantId != plant.id) continue;
      if (n.category != category) continue;
      if (lastCare == null || n.createdAt.isAfter(lastCare)) {
        lastCare = n.createdAt;
      }
    }
    // Anchor: last care note's date, or the plant's start date.
    DateTime anchor = _dateOnly(lastCare ?? plant.startDate);

    // Walk forward in [intervalDays] steps and emit events that fall inside
    // the visible window.  Guard with a hard iteration cap so a malformed
    // interval (e.g. 0 days) can never spin forever.
    var safety = 366;
    var next = anchor.add(Duration(days: intervalDays));
    while (next.isBefore(to) && safety-- > 0) {
      if (!next.isBefore(from)) {
        out.add(_CalEvent(
          date: next,
          plant: plant,
          kind: kind,
          projected: true,
        ));
      }
      next = next.add(Duration(days: intervalDays));
    }
  }

  bool _inRange(DateTime d, DateTime from, DateTime to) =>
      !d.isBefore(from) && d.isBefore(to);

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // ── Build ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();
    final eventsByDay = _buildEventsForMonth(repo);
    final today = _dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'Jump to today',
            icon: const Icon(Icons.today_rounded),
            onPressed: () => setState(() {
              final now = DateTime.now();
              _visibleMonth = DateTime(now.year, now.month, 1);
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _MonthHeader(
              month: _visibleMonth,
              onPrev: () => setState(() {
                _visibleMonth = DateTime(
                    _visibleMonth.year, _visibleMonth.month - 1, 1);
              }),
              onNext: () => setState(() {
                _visibleMonth = DateTime(
                    _visibleMonth.year, _visibleMonth.month + 1, 1);
              }),
            ),
            const _WeekdayRow(),
            Expanded(
              child: _MonthGrid(
                month: _visibleMonth,
                today: today,
                eventsByDay: eventsByDay,
                onDayTap: (day, events) =>
                    _showDaySheet(context, day, events),
              ),
            ),
            const _LegendRow(),
          ],
        ),
      ),
    );
  }

  // ── Day-detail bottom sheet ──────────────────

  void _showDaySheet(
      BuildContext context, DateTime day, List<_CalEvent> events) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colSurface2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.md,
                      AppSpacing.pagePadding,
                      AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(fmtShortDate(day),
                          style: AppTypography.headlineMedium(ctx)),
                      const Spacer(),
                      Text(
                        '${events.length} '
                        'event${events.length == 1 ? '' : 's'}',
                        style: AppTypography.labelSmall(ctx)
                            .copyWith(color: ctx.colTextMuted),
                      ),
                    ],
                  ),
                ),
                Divider(color: ctx.colBorderFaint, height: 1),
                Flexible(
                  child: events.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text('Nothing scheduled for this day.',
                              style: AppTypography.bodySmall(ctx)
                                  .copyWith(color: ctx.colTextMuted)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: events.length,
                          separatorBuilder: (_, __) => Divider(
                              color: ctx.colBorderFaint, height: 1),
                          itemBuilder: (_, i) {
                            final e = events[i];
                            return _DayEventTile(
                              event: e,
                              onTap: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PlantDetailScreen(plant: e.plant),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Month header ─────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrev,
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_monthNames[month.month - 1]} ${month.year}',
                style: AppTypography.headlineLarge(context),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ── Weekday header row ───────────────────────────────────────────────────────

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  // Mon-first matches Plant.flipDate displays elsewhere in the app and
  // is the ISO 8601 default; keeps consistency rather than US-style Sun.
  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding, vertical: 4),
      child: Row(
        children: _labels
            .map((l) => Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: AppTypography.labelSmall(context)
                          .copyWith(color: context.colTextMuted),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Month grid (6 rows × 7 cols) ─────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final Map<DateTime, List<_CalEvent>> eventsByDay;
  final void Function(DateTime day, List<_CalEvent> events) onDayTap;

  const _MonthGrid({
    required this.month,
    required this.today,
    required this.eventsByDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    // Compute the first cell — Monday on or before the 1st of the month.
    final first = month;
    // weekday: Mon=1 … Sun=7.  Need to back-step to Monday.
    final leadOffset = first.weekday - 1;
    final gridStart = first.subtract(Duration(days: leadOffset));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 0.78,
        ),
        itemCount: 42, // 6 weeks × 7 days
        itemBuilder: (_, i) {
          final day = gridStart.add(Duration(days: i));
          final dayKey = DateTime(day.year, day.month, day.day);
          final events = eventsByDay[dayKey] ?? const <_CalEvent>[];
          final inMonth = day.month == month.month;
          final isToday = dayKey == today;
          return _DayCell(
            day: day,
            isInMonth: inMonth,
            isToday: isToday,
            events: events,
            onTap: () => onDayTap(dayKey, events),
          );
        },
      ),
    );
  }
}

// ── Single day cell ──────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isInMonth;
  final bool isToday;
  final List<_CalEvent> events;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isInMonth,
    required this.isToday,
    required this.events,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final numColor = isInMonth
        ? (isToday ? Colors.black : context.colTextPrimary)
        : context.colTextMuted.withValues(alpha: 0.5);

    // De-duplicate event kinds for the dot row so the cell stays legible
    // even when a day has e.g. 4 watering reminders projected from
    // multiple plants.  We still surface the true count in the sheet.
    final uniqueKinds = <_EventKind>{
      for (final e in events) e.kind,
    }.toList();

    return InkWell(
      onTap: events.isEmpty && !isInMonth ? null : onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? AppColors.primary
              : (events.isNotEmpty
                  ? context.colSurface2
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isToday
                ? AppColors.primary
                : (events.isNotEmpty
                    ? context.colBorderFaint
                    : Colors.transparent),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${day.day}',
              textAlign: TextAlign.center,
              style: AppTypography.labelLarge(context).copyWith(
                color: numColor,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            // UX8 — show category icons in tinted chips instead of generic
            // coloured dots.  Each glyph reads as "what kind of thing is
            // happening that day" at a single glance, vs. dots that
            // require a colour-key memory lookup.  Up to 3 distinct
            // kinds fit comfortably in the cell; +N counter handles
            // busy days.
            if (uniqueKinds.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: [
                  for (final k in uniqueKinds.take(3))
                    Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: k.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      alignment: Alignment.center,
                      child: Icon(k.icon, color: k.color, size: 9),
                    ),
                  if (uniqueKinds.length > 3)
                    Container(
                      height: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.colSurface3,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '+${uniqueKinds.length - 3}',
                        style: AppTypography.labelSmall(context).copyWith(
                          fontSize: 8,
                          color: context.colTextMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              )
            else
              const SizedBox(height: 13),
          ],
        ),
      ),
    );
  }
}

// ── Day event tile ───────────────────────────────────────────────────────────

class _DayEventTile extends StatelessWidget {
  final _CalEvent event;
  final VoidCallback onTap;

  const _DayEventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = event.kind.color;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(event.kind.icon, size: 16, color: c),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.kind.label(event.plant),
                    style: AppTypography.labelLarge(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.note != null && event.note!.content.isNotEmpty)
                    Text(
                      event.note!.content,
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (event.projected)
                    Text('Projected',
                        style: AppTypography.labelSmall(context).copyWith(
                            color: context.colTextMuted,
                            fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: context.colTextMuted),
          ],
        ),
      ),
    );
  }
}

// ── Legend ───────────────────────────────────────────────────────────────────

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  static const _items = <_LegendItem>[
    _LegendItem('Water', AppColors.water),
    _LegendItem('Feed', AppColors.accent),
    _LegendItem('IPM', AppColors.ipmColor),
    _LegendItem('Harvest', AppColors.harvested),
    _LegendItem('Flip', AppColors.training),
    _LegendItem('Note', AppColors.secondary),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding, vertical: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final it in _items) ...[
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: it.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(it.label,
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted)),
              const SizedBox(width: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);
}
