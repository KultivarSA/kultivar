import 'dart:io';

import 'package:flutter/material.dart';

import '../models/plant_history_event.dart';
import '../models/plant_note.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/image_cache_size.dart';

enum _Filter { all, milestones, notes }

class PlantTimeline extends StatefulWidget {
  final List<PlantHistoryEvent> events;
  final DateTime startDate;

  const PlantTimeline({
    super.key,
    required this.events,
    required this.startDate,
  });

  @override
  State<PlantTimeline> createState() => _PlantTimelineState();
}

class _PlantTimelineState extends State<PlantTimeline> {
  _Filter _filter = _Filter.all;

  /// True when an event should be treated as a "milestone" for both
  /// filtering and visual styling.  Lifecycle transitions are always
  /// milestones; user-authored notes are milestones too when their
  /// category is [NoteCategory.milestone] — so adding a "Hit 30 cm"
  /// milestone note actually shows up under the Milestones filter
  /// rather than getting buried in the Notes bucket.
  bool _isMilestone(PlantHistoryEvent e) {
    if (e.type != PlantHistoryEventType.note) return true;
    return e.noteCategory == NoteCategory.milestone;
  }

  List<PlantHistoryEvent> get _filtered {
    switch (_filter) {
      case _Filter.all:
        return widget.events;
      case _Filter.milestones:
        return widget.events.where(_isMilestone).toList();
      case _Filter.notes:
        return widget.events.where((e) => !_isMilestone(e)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter chips ──────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _Filter.values.map((f) {
              final selected = _filter == f;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: FilterChip(
                  label: Text(_filterLabel(f)),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: AppColors.primary.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.primary,
                  labelStyle: AppTypography.labelSmall(context).copyWith(
                    color: selected
                        ? AppColors.primary
                        : context.colTextSecondary,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : context.colBorder,
                  ),
                  backgroundColor: context.colSurface1,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Event list ────────────────────────────
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Row(
              children: [
                Icon(Icons.filter_list_off_rounded,
                    color: context.colTextMuted, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _filter == _Filter.milestones
                      ? 'No lifecycle milestones yet.'
                      : _filter == _Filter.notes
                          ? 'No notes logged yet.'
                          : 'No timeline events yet.',
                  style: AppTypography.bodyMedium(context),
                ),
              ],
            ),
          )
        else
          ...events.asMap().entries.map((entry) {
            final isLast = entry.key == events.length - 1;
            return _item(context, entry.value, isLast: isLast);
          }),
      ],
    );
  }

  String _filterLabel(_Filter f) {
    switch (f) {
      case _Filter.all:
        return 'All';
      case _Filter.milestones:
        return 'Milestones';
      case _Filter.notes:
        return 'Notes';
    }
  }

  Widget _item(BuildContext context, PlantHistoryEvent event,
      {required bool isLast}) {
    // Per-event colour + icon resolution.  Note-typed events delegate
    // to their NoteCategory so a watering note gets the water drop
    // glyph + AppColors.water, a training note gets scissors +
    // AppColors.training, etc. — matching the icons already used in
    // the plant-detail notes section.
    final color = _colorForEvent(event);
    final icon = _iconForEvent(event);
    final dayX =
        event.timestamp.difference(widget.startDate).inDays.clamp(0, 9999);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: timeline spine ───────────────
        //
        // Every event — lifecycle or note — gets the same illuminated
        // treatment now: tinted background, full-saturation border,
        // category-coloured icon.  Previously notes were rendered in
        // muted surface-2 grey which made the timeline read as a wall
        // of indistinguishable rows.
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18),
                  border: Border.all(
                    color: color.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              if (!isLast)
                Container(
                  width: 1.5,
                  height: 28,
                  color: context.colBorder,
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),

        // ── Right: content card ────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colSurface1,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: title + day/date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: AppTypography.labelLarge(context).copyWith(
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            'Day $dayX',
                            style: AppTypography.labelSmall(context).copyWith(
                              color: AppColors.primary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(event.timestamp),
                          style: AppTypography.bodySmall(context)
                              .copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),

                // Description
                if (event.description != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(event.description!,
                      style: AppTypography.bodyMedium(context)),
                ],

                // Photo thumbnail
                if (event.photoUrl != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  // A9 — Semantics wraps the whole tap target so
                  // screen readers announce "Plant photo, button" and
                  // a single double-tap opens the full-screen viewer.
                  Semantics(
                    button: true,
                    label: 'Plant photo from ${_formatDate(event.timestamp)}',
                    child: GestureDetector(
                      onTap: () => _viewPhoto(context, event.photoUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(event.photoUrl!),
                          width: double.infinity,
                          height: 140,
                          fit: BoxFit.cover,
                          // P1.4 — cap decode at 2× the row height so
                          // the bitmap matches the display budget.
                          // Width is `double.infinity` (parent-bound)
                          // so we key off height; aspect ratio is
                          // preserved by Flutter.
                          cacheHeight: imageCacheHeight(context, 140),
                          // Excluded from semantics — the parent
                          // Semantics widget already announces the
                          // photo; without this, TalkBack would
                          // pronounce a second "image" node.
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) => Container(
                            height: 40,
                            color: context.colSurface3,
                            child: Center(
                              child: Icon(Icons.broken_image,
                                  color: context.colTextMuted),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _viewPhoto(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                File(path),
                semanticLabel: 'Plant photo',
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Icon for an event.  Note events delegate to the NoteCategory's
  /// own icon (water drop / bug / scissors / etc.) so the timeline
  /// reads at a glance.  Lifecycle events keep their bespoke glyphs.
  IconData _iconForEvent(PlantHistoryEvent e) {
    if (e.type == PlantHistoryEventType.note && e.noteCategory != null) {
      return e.noteCategory!.icon;
    }
    // Lifecycle-glyph pass — three sharpened mappings:
    //   • flipToFlower  →  local_florist (flower, literal — twilight
    //                      was about light schedule, which is the
    //                      *cause* not the *event*).
    //   • harvested     →  content_cut (snipping, literal — the
    //                      agriculture/tractor glyph reads as "field
    //                      farming" rather than a single harvest).
    //   • removed       →  delete_outline (clearly destructive — was
    //                      warning_rounded which collided with the
    //                      "issue" note glyph after our note-icon
    //                      polish to report_problem_rounded).
    switch (e.type) {
      case PlantHistoryEventType.planted:
        return Icons.spa_rounded;
      case PlantHistoryEventType.flipToFlower:
        return Icons.local_florist_rounded;
      case PlantHistoryEventType.moved:
        return Icons.swap_horiz_rounded;
      case PlantHistoryEventType.harvested:
        return Icons.content_cut_rounded;
      case PlantHistoryEventType.dryingStarted:
        return Icons.air_rounded;
      case PlantHistoryEventType.dryingCompleted:
        return Icons.task_alt_rounded;
      case PlantHistoryEventType.curingStarted:
        return Icons.inventory_2_rounded;
      case PlantHistoryEventType.curingCompleted:
        return Icons.verified_rounded;
      case PlantHistoryEventType.removed:
        return Icons.delete_outline_rounded;
      case PlantHistoryEventType.note:
        // Fallback for legacy events lacking a noteCategory.
        return Icons.edit_note_rounded;
    }
  }

  /// Colour for an event.  Note events delegate to the NoteCategory's
  /// own colour token so a watering note tints blue, IPM tints amber,
  /// training tints purple, etc. — matching what the notes section
  /// already uses.
  Color _colorForEvent(PlantHistoryEvent e) {
    if (e.type == PlantHistoryEventType.note && e.noteCategory != null) {
      return e.noteCategory!.color;
    }
    switch (e.type) {
      case PlantHistoryEventType.planted:
        return AppColors.growing;
      case PlantHistoryEventType.flipToFlower:
        return AppColors.secondary;
      case PlantHistoryEventType.moved:
        return AppColors.secondary;
      case PlantHistoryEventType.harvested:
        return AppColors.harvested;
      case PlantHistoryEventType.dryingStarted:
        return AppColors.drying;
      case PlantHistoryEventType.dryingCompleted:
        return AppColors.drying;
      case PlantHistoryEventType.curingStarted:
        return AppColors.curing;
      case PlantHistoryEventType.curingCompleted:
        return AppColors.completed;
      case PlantHistoryEventType.removed:
        return AppColors.danger;
      case PlantHistoryEventType.note:
        return AppColors.primary;
    }
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year.toString().substring(2)}';
  }
}
