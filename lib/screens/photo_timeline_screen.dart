import 'dart:async';
import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/plant.dart';
import '../models/plant_note.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../utils/image_cache_size.dart';
import '../utils/photo_path_resolver.dart';
import '../widgets/app_toast.dart';
import '../widgets/empty_state.dart';
import '../widgets/empty_state_art.dart';
import 'photo_markup_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PhotoTimelineScreen
//
// World-class photo journal.  Three view modes:
//   • Timeline  — stage-grouped, lifecycle event markers, grow-day numbers
//   • Grid       — week-grouped compact grid with category filter pills
//   • Flipbook   — auto-advance slideshow; watch your plant grow in seconds
//
// Full-screen viewer: pinch-zoom, swipe navigation, day badge, stage pill,
// note context drawer, share → Grow Card.
//
// Usage:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => PhotoTimelineScreen(plant: plant, notes: notes)));
// ─────────────────────────────────────────────────────────────────────────────

// ── View modes ────────────────────────────────────────────────────────────────

enum _ViewMode { timeline, grid, flipbook }

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _TimelinePhoto {
  final String path;
  final DateTime date;
  final int growDay;
  final GrowStage stage;
  final NoteCategory category;
  final Color categoryColor;
  final String categoryLabel;
  final String content;

  /// ID of the [PlantNote] that owns this photo.  Carried so the F5
  /// annotate flow can append the new markup file to the right note via
  /// `repo.updateNote()` without re-scanning by date/content.
  final String noteId;

  /// Bare filename (or relative URL) as stored on the note.  Needed so
  /// we can update the note's `photoUrls` list with the exact entry that
  /// matched this rendered photo — useful when the same filename appears
  /// on multiple notes.
  final String storedRef;

  const _TimelinePhoto({
    required this.path,
    required this.date,
    required this.growDay,
    required this.stage,
    required this.category,
    required this.categoryColor,
    required this.categoryLabel,
    required this.content,
    required this.noteId,
    required this.storedRef,
  });
}

// ── Timeline item hierarchy ───────────────────────────────────────────────────

abstract class _TimelineItem {}

class _StageHeaderItem extends _TimelineItem {
  final GrowStage stage;
  final int startDay;
  _StageHeaderItem({required this.stage, required this.startDay});
}

class _LifecycleItem extends _TimelineItem {
  final String label;
  final IconData icon;
  final Color color;
  final int growDay;
  _LifecycleItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.growDay,
  });
}

class _PhotoGroupItem extends _TimelineItem {
  final int growDay;
  final List<_TimelinePhoto> photos;
  _PhotoGroupItem({required this.growDay, required this.photos});
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline builder — pure logic, no widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TB {
  _TB._();

  // ── Grow day (1-based) ──────────────────────────────────────────────────
  static int growDay(Plant plant, DateTime date) =>
      date.difference(plant.startDate).inDays + 1;

  // ── Stage inference ─────────────────────────────────────────────────────
  static GrowStage stageFor(Plant plant, DateTime date) {
    final day = date.difference(plant.startDate).inDays;
    if (plant.flipDate != null && !plant.isAutoflower) {
      if (date.isBefore(plant.flipDate!)) {
        if (day < 7) return GrowStage.germination;
        if (day < 21) return GrowStage.seedling;
        return GrowStage.vegetative;
      }
      final fd = date.difference(plant.flipDate!).inDays;
      if (fd < 14) return GrowStage.stretch;
      if (fd < 42) return GrowStage.earlyFlower;
      if (fd < 63) return GrowStage.lateFlower;
      return GrowStage.flush;
    }
    if (day < 5) return GrowStage.germination;
    if (day < 14) return GrowStage.seedling;
    if (day < 28) return GrowStage.vegetative;
    if (day < 42) return GrowStage.stretch;
    if (day < 63) return GrowStage.earlyFlower;
    if (day < 77) return GrowStage.lateFlower;
    return GrowStage.flush;
  }

  // ── Stage colour & icon ─────────────────────────────────────────────────
  static Color colorFor(GrowStage stage) {
    switch (stage) {
      case GrowStage.germination:
        return const Color(0xFF9CA3AF);
      case GrowStage.seedling:
        return AppColors.growing;
      case GrowStage.vegetative:
        return AppColors.primary;
      case GrowStage.stretch:
        return AppColors.secondary;
      case GrowStage.earlyFlower:
        return AppColors.warning;
      case GrowStage.lateFlower:
        return AppColors.harvested;
      case GrowStage.flush:
        return AppColors.danger;
    }
  }

  static IconData iconFor(GrowStage stage) {
    switch (stage) {
      case GrowStage.germination:
        return Icons.spa_outlined;
      case GrowStage.seedling:
        return Icons.eco_rounded;
      case GrowStage.vegetative:
        return Icons.park_rounded;
      case GrowStage.stretch:
        return Icons.trending_up_rounded;
      case GrowStage.earlyFlower:
        return Icons.local_florist_rounded;
      case GrowStage.lateFlower:
        return Icons.local_florist_rounded;
      case GrowStage.flush:
        return Icons.water_drop_rounded;
    }
  }

  // ── Build enriched photo list ───────────────────────────────────────────
  static List<_TimelinePhoto> buildPhotos(Plant plant, List<PlantNote> notes) {
    final photos = <_TimelinePhoto>[];
    for (final note in notes) {
      for (final url in note.photoUrls) {
        final date = note.createdAt;
        photos.add(_TimelinePhoto(
          path: PhotoPathResolver.resolve(url),
          date: date,
          growDay: growDay(plant, date),
          stage: stageFor(plant, date),
          category: note.category,
          categoryColor: note.categoryColor,
          categoryLabel: note.categoryLabel,
          content: note.content,
          noteId: note.id,
          storedRef: url,
        ));
      }
    }
    photos.sort((a, b) => a.date.compareTo(b.date));
    return photos;
  }

  // ── Build lifecycle event markers ───────────────────────────────────────
  static List<_LifecycleItem> buildLifecycleItems(
      Plant plant, List<PlantNote> notes) {
    final items = <_LifecycleItem>[];
    if (plant.flipDate != null) {
      items.add(_LifecycleItem(
        label: 'Flipped to Flower',
        icon: Icons.wb_sunny_rounded,
        color: AppColors.warning,
        growDay: growDay(plant, plant.flipDate!),
      ));
    }
    if (plant.harvestedDate != null) {
      items.add(_LifecycleItem(
        label: 'Harvested',
        // Match the lifecycle-icon refresh in plant_timeline.dart —
        // content_cut reads as "snip" more clearly than the
        // agriculture / tractor glyph this previously used.
        icon: Icons.content_cut_rounded,
        color: AppColors.harvested,
        growDay: growDay(plant, plant.harvestedDate!),
      ));
    }
    for (final note in notes) {
      if (note.category == NoteCategory.training &&
          note.trainingDetails != null &&
          note.trainingDetails!.technique.stressLevel >= 2) {
        final d = note.trainingDetails!;
        items.add(_LifecycleItem(
          label: d.technique.label +
              (d.targetSite != null ? ' · ${d.targetSite}' : ''),
          icon: Icons.content_cut_rounded,
          color: AppColors.training,
          growDay: growDay(plant, note.createdAt),
        ));
      }
      if (note.category == NoteCategory.milestone) {
        items.add(_LifecycleItem(
          label: note.content.length > 44
              ? '${note.content.substring(0, 44)}…'
              : note.content,
          // Match NoteCategory.milestone in plant_note.dart — trophy
          // glyph reads as celebratory achievement; flag read as
          // "report problem" to several test users.
          icon: Icons.emoji_events_rounded,
          color: AppColors.growing,
          growDay: growDay(plant, note.createdAt),
        ));
      }
    }
    return items;
  }

  // ── Merge photos + lifecycle items into ordered timeline ────────────────
  static List<_TimelineItem> buildTimelineItems(
    Plant plant,
    List<PlantNote> notes,
    List<_TimelinePhoto> photos,
  ) {
    if (photos.isEmpty) return [];
    final lc = buildLifecycleItems(plant, notes);
    final items = <_TimelineItem>[];

    // Group by grow day
    final Map<int, List<_TimelinePhoto>> byDay = {};
    for (final p in photos) {
      (byDay[p.growDay] ??= []).add(p);
    }
    final sortedDays = byDay.keys.toList()..sort();
    GrowStage? currentStage;

    for (var i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      final prevDay = i > 0 ? sortedDays[i - 1] : 0;
      final dayPhotos = byDay[day]!;
      final stage = dayPhotos.first.stage;

      // Stage header when stage changes
      if (stage != currentStage) {
        items.add(_StageHeaderItem(stage: stage, startDay: day));
        currentStage = stage;
      }

      // Lifecycle items that fall between the previous photo day and this one
      for (final e in lc) {
        if (e.growDay > prevDay && e.growDay <= day) items.add(e);
      }

      items.add(_PhotoGroupItem(growDay: day, photos: dayPhotos));
    }

    // Lifecycle items after the last photo
    final lastDay = sortedDays.last;
    for (final e in lc) {
      if (e.growDay > lastDay) items.add(e);
    }

    return items;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PhotoTimelineScreen — main widget
// ─────────────────────────────────────────────────────────────────────────────

class PhotoTimelineScreen extends StatefulWidget {
  final Plant plant;
  final List<PlantNote> notes;

  const PhotoTimelineScreen({
    super.key,
    required this.plant,
    required this.notes,
  });

  @override
  State<PhotoTimelineScreen> createState() => _PhotoTimelineScreenState();
}

class _PhotoTimelineScreenState extends State<PhotoTimelineScreen> {
  _ViewMode _mode = _ViewMode.timeline;
  NoteCategory? _filter;

  // F5 — these were `late final` and computed once in initState, which
  // meant adding an annotated photo to a note (via PhotoMarkupScreen)
  // wouldn't show up until the user backed out and reopened the screen.
  // They're now mutable + `_refreshFromRepo` swaps in fresh photos
  // after any in-screen edit.
  late List<_TimelinePhoto> _allPhotos;
  late List<_TimelineItem> _timelineItems;

  @override
  void initState() {
    super.initState();
    _allPhotos = _TB.buildPhotos(widget.plant, widget.notes);
    _timelineItems =
        _TB.buildTimelineItems(widget.plant, widget.notes, _allPhotos);
  }

  /// Rebuild the cached photo/timeline lists from the current repo
  /// state.  Called after the user annotates a photo (F5) so the new
  /// markup file appears in the timeline without backing out.
  void _refreshFromRepo() {
    final repo = context.read<GrowRepository>();
    final notes = repo.notes
        .where((n) => n.plantId == widget.plant.id)
        .toList();
    setState(() {
      _allPhotos = _TB.buildPhotos(widget.plant, notes);
      _timelineItems =
          _TB.buildTimelineItems(widget.plant, notes, _allPhotos);
    });
  }

  List<_TimelinePhoto> get _filtered => _filter == null
      ? _allPhotos
      : _allPhotos.where((p) => p.category == _filter).toList();

  List<_TimelineItem> get _filteredTimeline => _filter == null
      ? _timelineItems
      : () {
          final days = _filtered.map((p) => p.growDay).toSet();
          return _timelineItems.where((item) {
            if (item is _PhotoGroupItem) return days.contains(item.growDay);
            return true; // keep headers and lifecycle markers
          }).toList();
        }();

  @override
  Widget build(BuildContext context) {
    final photos = _filtered;

    return Scaffold(
      backgroundColor: context.colSurface1,
      appBar: _buildAppBar(photos.length),
      body: kIsWeb
          ? const Center(
              child: Text('Photos are available on mobile only.'))
          : photos.isEmpty && _filter == null
              ? const EmptyState(
                  art: EmptyArt.photo,
                  title: 'No Photos Yet',
                  subtitle:
                      'Attach photos when logging notes\nto build your visual grow journal.',
                )
              : Column(
                  children: [
                    // ── Stage progress scrubber ─────────────────────────────
                    if (_allPhotos.isNotEmpty)
                      _ScrubberBar(plant: widget.plant, photos: _allPhotos),

                    // ── Category filter pills ───────────────────────────────
                    _FilterPills(
                      selected: _filter,
                      available: _allPhotos.map((p) => p.category).toSet(),
                      onSelect: (cat) =>
                          setState(() => _filter = _filter == cat ? null : cat),
                    ),

                    // ── View body ───────────────────────────────────────────
                    Expanded(child: _buildBody(photos)),
                  ],
                ),
    );
  }

  AppBar _buildAppBar(int count) => AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photo Timeline',
                style: AppTypography.headlineMedium(context)),
            Text(
              '$count photo${count == 1 ? '' : 's'} · ${widget.plant.name}',
              style: AppTypography.bodySmall(context),
            ),
          ],
        ),
        actions: [
          _ModeButton(
            icon: Icons.view_agenda_rounded,
            active: _mode == _ViewMode.timeline,
            tooltip: 'Timeline',
            onTap: () => setState(() => _mode = _ViewMode.timeline),
          ),
          _ModeButton(
            icon: Icons.grid_on_rounded,
            active: _mode == _ViewMode.grid,
            tooltip: 'Grid',
            onTap: () => setState(() => _mode = _ViewMode.grid),
          ),
          _ModeButton(
            icon: Icons.play_circle_outline_rounded,
            active: _mode == _ViewMode.flipbook,
            tooltip: 'Flipbook',
            onTap: () => setState(() => _mode = _ViewMode.flipbook),
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      );

  Widget _buildBody(List<_TimelinePhoto> photos) {
    if (photos.isEmpty) {
      return Center(
        child: Text('No photos match this filter.',
            style: AppTypography.bodyMedium(context)
                .copyWith(color: context.colTextMuted)),
      );
    }
    switch (_mode) {
      case _ViewMode.timeline:
        return _TimelineView(
          items: _filteredTimeline,
          allPhotos: _allPhotos,
          plant: widget.plant,
          onPhotosChanged: _refreshFromRepo,
        );
      case _ViewMode.grid:
        return _GridView(
          photos: photos,
          plant: widget.plant,
          onPhotosChanged: _refreshFromRepo,
        );
      case _ViewMode.flipbook:
        return _FlipbookView(
          photos: photos,
          plant: widget.plant,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage progress scrubber bar
// ─────────────────────────────────────────────────────────────────────────────

class _ScrubberBar extends StatelessWidget {
  final Plant plant;
  final List<_TimelinePhoto> photos;

  const _ScrubberBar({required this.plant, required this.photos});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    final firstDay = photos.first.growDay;
    final lastDay = photos.last.growDay;
    final span = (lastDay - firstDay).clamp(1, 999);

    // Collect distinct stage segments
    final segments = <(GrowStage, double, double)>[];
    GrowStage? prev;
    double segStart = 0;
    for (final p in photos) {
      final frac = (p.growDay - firstDay) / span;
      if (p.stage != prev) {
        if (prev != null) segments.add((prev, segStart, frac));
        prev = p.stage;
        segStart = frac;
      }
    }
    if (prev != null) segments.add((prev, segStart, 1.0));

    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 8),
        child: LayoutBuilder(builder: (_, constraints) {
          return Stack(
            children: [
              // Track
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                child: Row(
                  children: segments.map((seg) {
                    final (stage, start, end) = seg;
                    return Expanded(
                      flex: ((end - start) * 1000).round().clamp(1, 1000),
                      child: Container(
                        height: 6,
                        color: _TB.colorFor(stage).withValues(alpha: 0.6),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Photo dots
              ...photos.map((p) {
                final frac = (p.growDay - firstDay) / span;
                final x = frac * constraints.maxWidth - 3;
                return Positioned(
                  left: x.clamp(0, constraints.maxWidth - 6),
                  top: 0,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _TB.colorFor(p.stage),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                );
              }),
              // Day labels
              Positioned(
                left: 0,
                bottom: 0,
                child: Text('Day $firstDay',
                    style: TextStyle(
                        fontSize: 8,
                        color: context.colTextMuted)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Text('Day $lastDay',
                    style: TextStyle(
                        fontSize: 8,
                        color: context.colTextMuted)),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter pills
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPills extends StatelessWidget {
  final NoteCategory? selected;
  final Set<NoteCategory> available;
  final ValueChanged<NoteCategory> onSelect;

  const _FilterPills({
    required this.selected,
    required this.available,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cats = NoteCategory.values
        .where((c) => available.contains(c))
        .toList();
    if (cats.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 4),
        children: [
          _PillChip(
            label: 'All',
            color: AppColors.primary,
            selected: selected == null,
            onTap: () {
              if (selected != null) onSelect(selected!); // toggle off
            },
          ),
          ...cats.map((c) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _PillChip(
                  label: c.categoryLabel,
                  color: c.color,
                  selected: selected == c,
                  onTap: () => onSelect(c),
                ),
              )),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PillChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : context.colSurface3,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: selected ? color : context.colBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : context.colTextSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View mode toggle button
// ─────────────────────────────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon,
            size: 22,
            color: active ? AppColors.primary : context.colTextMuted),
        onPressed: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMELINE VIEW
// Stage-grouped list with lifecycle event markers and grow-day numbers.
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineView extends StatelessWidget {
  final List<_TimelineItem> items;
  final List<_TimelinePhoto> allPhotos;
  final Plant plant;
  final VoidCallback? onPhotosChanged;

  const _TimelineView({
    required this.items,
    required this.allPhotos,
    required this.plant,
    this.onPhotosChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
          child: Text('No photos for this filter.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(
          bottom: AppSpacing.xl, top: AppSpacing.xs),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is _StageHeaderItem) {
          return _StageHeaderCard(item: item);
        }
        if (item is _LifecycleItem) {
          return _LifecycleCard(item: item);
        }
        if (item is _PhotoGroupItem) {
          return _PhotoDayGroup(
            item: item,
            allPhotos: allPhotos,
            plant: plant,
            onPhotosChanged: onPhotosChanged,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _StageHeaderCard extends StatelessWidget {
  final _StageHeaderItem item;
  const _StageHeaderCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _TB.colorFor(item.stage);
    final icon = _TB.iconFor(item.stage);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            item.stage.label,
            style: AppTypography.labelLarge(context).copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'from Day ${item.startDay}',
            style: AppTypography.bodySmall(context).copyWith(
              color: context.colTextMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              height: 1,
              color: color.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

class _LifecycleCard extends StatelessWidget {
  final _LifecycleItem item;
  const _LifecycleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 12, color: item.color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              color: item.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              'Day ${item.growDay}',
              style: TextStyle(
                fontSize: 9,
                color: item.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoDayGroup extends StatelessWidget {
  final _PhotoGroupItem item;
  final List<_TimelinePhoto> allPhotos;
  final Plant plant;
  final VoidCallback? onPhotosChanged;

  const _PhotoDayGroup({
    required this.item,
    required this.allPhotos,
    required this.plant,
    this.onPhotosChanged,
  });

  @override
  Widget build(BuildContext context) {
    final stageColor = _TB.colorFor(item.photos.first.stage);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day label
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    'Day ${item.growDay}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: stageColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _shortDate(item.photos.first.date),
                  style: TextStyle(
                    fontSize: 10,
                    color: context.colTextMuted,
                  ),
                ),
                if (item.photos.length > 1) ...[
                  const Spacer(),
                  Text(
                    '${item.photos.length} photos',
                    style: TextStyle(
                        fontSize: 10, color: context.colTextMuted),
                  ),
                ],
              ],
            ),
          ),
          // Photos — 1 photo: full width; 2+: 2-column grid
          if (item.photos.length == 1)
            _PhotoTile(
              photo: item.photos.first,
              allPhotos: allPhotos,
              borderRadius: AppSpacing.radiusMd,
              height: 200,
              onPhotosChanged: onPhotosChanged,
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.3,
              children: item.photos
                  .map((p) => _PhotoTile(
                        photo: p,
                        allPhotos: allPhotos,
                        borderRadius: AppSpacing.radiusSm,
                        onPhotosChanged: onPhotosChanged,
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID VIEW
// Compact 3-col grid. Week-grouped. Photo dot badges for events.
// ─────────────────────────────────────────────────────────────────────────────

class _GridView extends StatelessWidget {
  final List<_TimelinePhoto> photos;
  final Plant plant;
  final VoidCallback? onPhotosChanged;

  const _GridView({
    required this.photos,
    required this.plant,
    this.onPhotosChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Group photos by ISO week number
    final Map<String, List<_TimelinePhoto>> byWeek = {};
    for (final p in photos) {
      final key = _weekKey(p.date, plant.startDate);
      (byWeek[key] ??= []).add(p);
    }
    final weeks = byWeek.keys.toList()..sort();

    // Build a flat list of items: (String header | _TimelinePhoto photo)
    final flatItems = <Object>[];
    for (final wk in weeks) {
      flatItems.add(wk);
      flatItems.addAll(byWeek[wk]!);
    }

    return CustomScrollView(
      slivers: [
        for (final wk in weeks) ...[
          SliverToBoxAdapter(
            child: _WeekHeader(
              label: wk,
              count: byWeek[wk]!.length,
            ),
          ),
          SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final p = byWeek[wk]![i];
                return _PhotoTile(
                  photo: p,
                  allPhotos: photos,
                  borderRadius: 3,
                  onPhotosChanged: onPhotosChanged,
                );
              },
              childCount: byWeek[wk]!.length,
            ),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
          ),
        ],
        const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }

  /// Returns a human-friendly week key like "Week 4" based on grow days.
  String _weekKey(DateTime date, DateTime startDate) {
    final day = date.difference(startDate).inDays;
    final week = (day ~/ 7) + 1;
    return 'Week $week';
  }
}

class _WeekHeader extends StatelessWidget {
  final String label;
  final int count;
  const _WeekHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.labelLarge(context).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$count photo${count == 1 ? '' : 's'}',
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLIPBOOK VIEW
// Watch your plant grow. Auto-advance with speed control + scrub bar.
// ─────────────────────────────────────────────────────────────────────────────

class _FlipbookView extends StatefulWidget {
  final List<_TimelinePhoto> photos;
  final Plant plant;

  const _FlipbookView({required this.photos, required this.plant});

  @override
  State<_FlipbookView> createState() => _FlipbookViewState();
}

class _FlipbookViewState extends State<_FlipbookView> {
  late final PageController _pageCtrl;
  Timer? _timer;
  bool _playing = false;
  int _index = 0;
  double _speed = 1.0;

  static const List<double> _speeds = [0.5, 1.0, 2.0, 4.0];
  // Base interval: 1400 ms at 1× speed
  int get _intervalMs => (1400 / _speed).round();

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // P1.3 — Preload the first photo + immediate neighbour on entry
    // so the slideshow opens without a black frame.  Neighbours of
    // later pages are preloaded reactively in `_preloadNeighbours`.
    _preloadNeighbours(_index);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  /// P1.3 — Decode-and-cache the photos at `i-1`, `i`, `i+1` so a
  /// swipe (or the auto-advance timer) finds the next image already
  /// in the ImageCache.  Without this, every swipe paid the full
  /// disk → decode → upload cost on the main isolate, showing a
  /// brief black flash between frames.
  ///
  /// We cap at ±1 because each decoded full-screen photo on an iPhone
  /// 16 Pro Max is ~12 MB at display density; preloading ±2 would
  /// triple that and risk evicting hot tiles from the rest of the
  /// app's caches.
  void _preloadNeighbours(int i) {
    final ctx = context;
    if (!mounted) return;
    final n = widget.photos.length;
    for (final j in <int>[i - 1, i, i + 1]) {
      if (j < 0 || j >= n) continue;
      // FileImage is the same provider Image.file uses internally, so
      // the precache populates the same cache entry the carousel hits.
      precacheImage(FileImage(File(widget.photos[j].path)), ctx);
    }
  }

  void _play() {
    _timer?.cancel();
    setState(() => _playing = true);
    _timer = Timer.periodic(Duration(milliseconds: _intervalMs), (_) {
      if (!mounted) return;
      if (_index >= widget.photos.length - 1) {
        _pause();
        return;
      }
      setState(() => _index++);
      _pageCtrl.animateToPage(
        _index,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
      );
    });
  }

  void _pause() {
    _timer?.cancel();
    if (mounted) setState(() => _playing = false);
  }

  void _togglePlay() => _playing ? _pause() : _play();

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    final stageColor = _TB.colorFor(photo.stage);

    return Stack(
      children: [
        // ── Photo carousel ────────────────────────────────────────────────
        GestureDetector(
          onTap: _togglePlay,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.photos.length,
            onPageChanged: (i) {
              _pause();
              setState(() => _index = i);
              // P1.3 — keep the next/prev frame warm in ImageCache.
              _preloadNeighbours(i);
            },
            itemBuilder: (_, i) {
              final p = widget.photos[i];
              return Image.file(
                File(p.path),
                fit: BoxFit.contain,
                // A9 — slideshow viewer; describe by category + day.
                semanticLabel:
                    '${p.categoryLabel} photo, day ${p.growDay}',
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image,
                      size: 64, color: Colors.white38),
                ),
              );
            },
          ),
        ),

        // ── Top overlay: day counter ──────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Animated day counter
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    'Day ${photo.growDay}',
                    key: ValueKey(photo.growDay),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                // Stage pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.25),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                        color: stageColor.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    photo.stage.shortLabel,
                    style: TextStyle(
                      color: stageColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Bottom controls ────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scrub bar
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12),
                    activeTrackColor: stageColor,
                    inactiveTrackColor:
                        Colors.white.withValues(alpha: 0.3),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _index.toDouble(),
                    min: 0,
                    max: (widget.photos.length - 1).toDouble(),
                    onChanged: (v) {
                      _pause();
                      final i = v.round();
                      setState(() => _index = i);
                      _pageCtrl.jumpToPage(i);
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.xs),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Rewind
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded,
                          color: Colors.white, size: 28),
                      tooltip: 'Previous photo',
                      onPressed: () {
                        _pause();
                        final i = (_index - 1).clamp(
                            0, widget.photos.length - 1);
                        setState(() => _index = i);
                        _pageCtrl.jumpToPage(i);
                      },
                    ),

                    // Play / Pause
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: stageColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),

                    // Forward
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded,
                          color: Colors.white, size: 28),
                      tooltip: 'Next photo',
                      onPressed: () {
                        _pause();
                        final i = (_index + 1).clamp(
                            0, widget.photos.length - 1);
                        setState(() => _index = i);
                        _pageCtrl.jumpToPage(i);
                      },
                    ),

                    const SizedBox(width: AppSpacing.sm),

                    // Speed chips
                    ..._speeds.map((s) => Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _speed = s);
                              if (_playing) _play(); // restart with new speed
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                              decoration: BoxDecoration(
                                color: _speed == s
                                    ? stageColor
                                    : Colors.white
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull),
                              ),
                              child: Text(
                                '$s×',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        )),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${_index + 1} / ${widget.photos.length}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ),

        // ── Tap-to-play hint (shown when paused on first photo) ───────────
        if (!_playing && _index == 0)
          Center(
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline_rounded,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tap to play your grow',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared photo tile — used in timeline and grid views
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoTile extends StatelessWidget {
  final _TimelinePhoto photo;
  final List<_TimelinePhoto> allPhotos;
  final double borderRadius;
  final double? height;
  /// F5 — invoked when the user annotated a photo, so the timeline can
  /// rebuild its cached photo list with the new markup file added.
  final VoidCallback? onPhotosChanged;

  const _PhotoTile({
    required this.photo,
    required this.allPhotos,
    this.borderRadius = 6,
    this.height,
    this.onPhotosChanged,
  });

  @override
  Widget build(BuildContext context) {
    final stageColor = _TB.colorFor(photo.stage);
    return Semantics(
      // A9 — describe the tile as a button to open the full-screen
      // viewer.  Label folds together the category + grow day so
      // TalkBack announces "Feeding photo, day 28 of grow, button"
      // — useful when scrubbing a long photo grid by category.
      button: true,
      label: '${photo.categoryLabel} photo, day ${photo.growDay} of grow',
      child: GestureDetector(
        onTap: () {
          final idx = allPhotos.indexOf(photo);
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => _FullScreenViewer(
                photos: allPhotos,
                initialIndex: idx < 0 ? 0 : idx,
                onPhotosChanged: onPhotosChanged,
              ),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        },
      // A8 — Category-tinted border around the whole tile so a quick
      // scan groups photos by what kind of activity they document
      // (feeding / training / IPM / observation).  The thin 1.5 px
      // ring at 60% alpha is loud enough to register but not enough
      // to distract from the photo itself.
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius + 1),
          border: Border.all(
            color: photo.categoryColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(photo.path),
                  fit: BoxFit.cover,
                  // P1.4 — grid tile decode cap.  The tile's logical
                  // height is `height` (the column width); StackFit
                  // expands it to fill the cell.  Capping at height
                  // is conservative (tile is square-ish) and keeps
                  // RAM ~150× lower than native decode on a 30-photo
                  // grid.
                  cacheHeight: imageCacheHeight(context, height),
                  // A9 — parent _PhotoTile Semantics wrap already
                  // announces the tile as a button with category +
                  // grow day; this Image.file shouldn't add a
                  // duplicate "image" node.
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => Container(
                    color: context.colSurface2,
                    child: Icon(Icons.broken_image,
                        color: context.colTextMuted),
                  ),
                ),
                // Category dot (top-right) — keep the dot in addition
                // to the border because on a dense 3-col grid the
                // border colour reads as "tile chrome" and only the
                // dot carries the per-thumbnail accent at glance
                // distance.
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: photo.categoryColor,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 1),
                    ),
                  ),
                ),
                // A8 — Date overlay (bottom-left).  Was "D14" only;
                // now extended to "D14 · Jun 3" so the user can scan
                // a thumbnail and immediately know which grow day +
                // calendar date it documents.  Stage colour stays as
                // the badge fill so the lifecycle phase is still
                // encoded visually (seedling / veg / flower / etc).
                Positioned(
                  bottom: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'D${photo.growDay} · ${fmtShortDate(photo.date)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULL-SCREEN VIEWER
// Swipe left/right, pinch-to-zoom, day badge, stage pill,
// note context drawer, share → Grow Card.
// ─────────────────────────────────────────────────────────────────────────────

class _FullScreenViewer extends StatefulWidget {
  final List<_TimelinePhoto> photos;
  final int initialIndex;
  /// F5 — bubble back to the parent timeline so it can rebuild its
  /// cached photo list with the freshly-annotated image.
  final VoidCallback? onPhotosChanged;

  const _FullScreenViewer({
    required this.photos,
    required this.initialIndex,
    this.onPhotosChanged,
  });

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer> {
  late final PageController _ctrl;
  late int _index;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  _TimelinePhoto get _current => widget.photos[_index];

  void _showNoteDrawer(BuildContext context) {
    final photo = _current;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteContextSheet(photo: photo),
    );
  }

  /// F5 — open [PhotoMarkupScreen] for the current photo.  On a
  /// successful save, append the new filename to the source note's
  /// `photoUrls` so the markup appears in the timeline as its own entry.
  /// We *append* rather than replace so the original photo is preserved
  /// as evidence of the unannotated state — useful for issue reports.
  ///
  /// Uses the State's own `context`/`mounted` rather than taking a
  /// `BuildContext` parameter — keeps the analyzer happy across the
  /// async gap (the parameter form trips `use_build_context_synchronously`
  /// because it can't link the param back to `mounted`).
  Future<void> _annotateCurrent() async {
    if (kIsWeb) return; // Markup needs a filesystem; web has no native paths.
    final photo = _current;
    final repo = context.read<GrowRepository>();

    final savedFilename = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoMarkupScreen(photoPath: photo.path),
      ),
    );

    if (!mounted) return;
    if (savedFilename == null) return; // User cancelled.

    // Look up the source note and append the markup file.  If the note
    // has been deleted in the background we surface a toast rather than
    // creating a dangling photo file.
    final note = repo.notes.where((n) => n.id == photo.noteId).firstOrNull;
    if (note == null) {
      AppToast.show(context, 'Source note no longer exists',
          type: ToastType.error);
      return;
    }

    // Use copyWith with a fresh list so the repo's change detection
    // picks up the new entry (in-place mutation wouldn't notify).
    final newPhotos = [...note.photoUrls, savedFilename];
    repo.updateNote(note.copyWith(photoUrls: newPhotos));

    AppToast.show(context, 'Annotation saved', type: ToastType.success);

    // Pop the viewer back to the timeline so the caller's
    // [onPhotosChanged] hook fires and the new entry shows up.
    widget.onPhotosChanged?.call();
    Navigator.of(context).pop();
  }

  void _showGrowCard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GrowCardSheet(
        photo: _current,
        // Plant name and strain passed via photo metadata
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = _current;
    final stageColor = _TB.colorFor(photo.stage);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showOverlay = !_showOverlay),
        child: Stack(
          children: [
            // ── Photo carousel ──────────────────────────────────────────
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(
                    File(widget.photos[i].path),
                    fit: BoxFit.contain,
                    // A9 — full-screen pinch-zoom viewer; describe by
                    // category + day so VoiceOver users can navigate
                    // the carousel by sound.
                    semanticLabel:
                        '${widget.photos[i].categoryLabel} photo, day ${widget.photos[i].growDay}',
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white38,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),

            // ── Top bar (back + counter + share) ────────────────────────
            AnimatedOpacity(
              opacity: _showOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      4,
                      MediaQuery.of(context).padding.top + 4,
                      4,
                      16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white, size: 20),
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(
                        '${_index + 1} / ${widget.photos.length}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      const Spacer(),
                      if (!kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.brush_rounded,
                              color: Colors.white, size: 20),
                          tooltip: 'Annotate',
                          onPressed: _annotateCurrent,
                        ),
                      IconButton(
                        icon: const Icon(Icons.ios_share_rounded,
                            color: Colors.white, size: 20),
                        tooltip: 'Share grow card',
                        onPressed: () => _showGrowCard(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom info overlay ──────────────────────────────────────
            AnimatedOpacity(
              opacity: _showOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {}, // prevent tap-through hiding overlay
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                        16,
                        32,
                        16,
                        MediaQuery.of(context).padding.bottom + 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Day badge + stage pill
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: stageColor
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull),
                                border: Border.all(
                                    color: stageColor
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                'Day ${photo.growDay}',
                                style: TextStyle(
                                  color: stageColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                              decoration: BoxDecoration(
                                color: photo.categoryColor
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull),
                              ),
                              child: Text(
                                photo.stage.label,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (photo.content.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            photo.content,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        const SizedBox(height: AppSpacing.sm),

                        // Note context button
                        GestureDetector(
                          onTap: () => _showNoteDrawer(context),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.expand_less_rounded,
                                  color: Colors.white60, size: 16),
                              SizedBox(width: AppSpacing.xxs),
                              Text(
                                'View note',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Note context sheet (swipe up from viewer)
// ─────────────────────────────────────────────────────────────────────────────

class _NoteContextSheet extends StatelessWidget {
  final _TimelinePhoto photo;
  const _NoteContextSheet({required this.photo});

  @override
  Widget build(BuildContext context) {
    final stageColor = _TB.colorFor(photo.stage);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: context.colBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  'Day ${photo.growDay}',
                  style: TextStyle(
                    color: stageColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: photo.categoryColor.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  photo.categoryLabel,
                  style: TextStyle(
                    color: photo.categoryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            photo.content.isNotEmpty
                ? photo.content
                : 'No note content.',
            style: AppTypography.bodyMedium(context).copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _formatDate(photo.date),
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextMuted),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// GROW CARD — shareable one-tap card
// ─────────────────────────────────────────────────────────────────────────────

class _GrowCardSheet extends StatefulWidget {
  final _TimelinePhoto photo;
  const _GrowCardSheet({required this.photo});

  @override
  State<_GrowCardSheet> createState() => _GrowCardSheetState();
}

class _GrowCardSheetState extends State<_GrowCardSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kultivar_grow_card.png');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Day ${widget.photo.growDay} · ${widget.photo.stage.label}\n#Kultivar',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: context.colSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: context.colBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grow Card',
                  style: AppTypography.labelLarge(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Share your grow with one tap.',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── The card ──────────────────────────────────────────────
                RepaintBoundary(
                  key: _cardKey,
                  child: _GrowCard(photo: photo),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Share button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _sharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.ios_share_rounded, size: 17),
                    label: Text(_sharing ? 'Preparing…' : 'Share Grow Card'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _sharing ? null : _share,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowCard extends StatelessWidget {
  final _TimelinePhoto photo;
  const _GrowCard({required this.photo});

  @override
  Widget build(BuildContext context) {
    final stageColor = _TB.colorFor(photo.stage);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: SizedBox(
        height: 320,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo background — A9: parent share card has its own
            // labelled controls; the photo backdrop is decorative.
            //
            // P1.4 — Deliberately NOT passing cacheWidth/cacheHeight.
            // This widget is rendered into a RepaintBoundary →
            // toImage() at high pixelRatio for the share PNG export;
            // downsampling here would visibly blur the shared card.
            // The on-screen preview is short-lived (only while the
            // sheet is open) so the memory hit is acceptable.
            Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF111118),
                child: const Center(
                  child: Icon(Icons.photo,
                      color: Colors.white24, size: 64),
                ),
              ),
            ),

            // Bottom gradient
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1.0],
                  colors: [
                    Colors.transparent,
                    Color(0xE6000000),
                  ],
                ),
              ),
            ),

            // Top-right: app watermark
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: const Text(
                  'Kultivar',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Bottom info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Day + stage row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: stageColor,
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
                          ),
                          child: Text(
                            'Day ${photo.growDay}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          photo.stage.label,
                          style: TextStyle(
                            color:
                                stageColor.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: photo.categoryColor.withValues(alpha: 0.8),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Text(
                        photo.categoryLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (photo.content.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        photo.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
