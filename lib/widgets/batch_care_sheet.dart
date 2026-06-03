import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grow_space.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_toast.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BatchCareSheet
//
// One-tap care logging for every plant in a space.
//
// • Defaults to all active plants selected, category = Watering.
// • Each plant row shows how long ago it last received this care.
// • Note field is optional — when empty a sensible default is used.
// • Creates one PlantNote per selected plant in a single repo flush.
//
// Usage:
//   BatchCareSheet.show(context,
//     space: space, plants: activePlants, allNotes: notes);
// ─────────────────────────────────────────────────────────────────────────────

// Categories available for batch logging (training / harvest / etc excluded).
const _batchCategories = [
  NoteCategory.watering,
  NoteCategory.feeding,
  NoteCategory.ipm,
  NoteCategory.observation,
];

class BatchCareSheet extends StatefulWidget {
  final GrowSpace space;

  /// Active (non-archived) plants in this space.
  final List<Plant> plants;

  /// All notes in the repo — used to compute "last cared" per plant.
  final List<PlantNote> allNotes;

  const BatchCareSheet({
    super.key,
    required this.space,
    required this.plants,
    required this.allNotes,
  });

  /// Shows the sheet and returns when dismissed.
  static Future<void> show(
    BuildContext context, {
    required GrowSpace space,
    required List<Plant> plants,
    required List<PlantNote> allNotes,
  }) {
    // Bug fix: pop-with-result pattern -- see add_note_sheet.dart for
    // the full _dependents.isEmpty race explanation.
    // Capture repo up-front so we don't touch context across the
    // async gap (only the toast does, guarded by context.mounted).
    final repo = context.read<GrowRepository>();
    return showModalBottomSheet<List<PlantNote>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BatchCareSheet(
        space: space,
        plants: plants,
        allNotes: allNotes,
      ),
    ).then((notes) {
      if (notes == null || notes.isEmpty) return;
      for (final note in notes) {
        repo.addNote(note);
      }
      if (!context.mounted) return;
      final label = notes.first.category.categoryLabel.toLowerCase();
      AppToast.show(
        context,
        'Logged $label for ${notes.length} '
            '${notes.length == 1 ? 'plant' : 'plants'}',
        type: ToastType.success,
      );
    });
  }

  @override
  State<BatchCareSheet> createState() => _BatchCareSheetState();
}

class _BatchCareSheetState extends State<BatchCareSheet> {
  NoteCategory _category = NoteCategory.watering;
  late Set<String> _selectedIds;
  final _noteCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Default: all growing plants selected; drying/curing/etc. deselected.
    _selectedIds = widget.plants
        .where((p) => p.status == PlantStatus.growing)
        .map((p) => p.id)
        .toSet();
    // If nothing is growing, fall back to all plants.
    if (_selectedIds.isEmpty) {
      _selectedIds = widget.plants.map((p) => p.id).toSet();
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _defaultContent(NoteCategory cat) {
    switch (cat) {
      case NoteCategory.watering:
        return 'Watered';
      case NoteCategory.feeding:
        return 'Fed';
      case NoteCategory.ipm:
        return 'IPM applied';
      case NoteCategory.observation:
        return 'Checked';
      default:
        return cat.categoryLabel;
    }
  }

  /// Returns when this plant last received [category] care, or null.
  DateTime? _lastCare(String plantId) {
    final relevant = widget.allNotes
        .where((n) => n.plantId == plantId && n.category == _category)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return relevant.isEmpty ? null : relevant.first.createdAt;
  }

  String _lastCareLabel(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  Color _lastCareColor(DateTime? dt, BuildContext context) {
    if (dt == null) return AppColors.warning;
    final days = DateTime.now().difference(dt).inDays;
    if (days >= 3) return AppColors.warning;
    return context.colTextMuted;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _log(BuildContext context) async {
    if (_selectedIds.isEmpty || _loading) return;
    setState(() => _loading = true);

    final repo = context.read<GrowRepository>();
    final now = DateTime.now();
    final content = _noteCtrl.text.trim().isEmpty
        ? _defaultContent(_category)
        : _noteCtrl.text.trim();

    // Bug fix: build notes, pop with them, persist in show().then()
    // so notifyListeners doesn't fire mid-pop-animation.
    final notes = [
      for (final id in _selectedIds)
        PlantNote(
          id: repo.newId(),
          plantId: id,
          createdAt: now,
          content: content,
          category: _category,
        ),
    ];

    if (!mounted) return;
    Navigator.pop(context, notes);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canLog = _selectedIds.isNotEmpty && !_loading;
    final catColor = _category.color;

    return Padding(
      // Lift above keyboard.
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLg)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colBorder,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),

            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding, AppSpacing.sm,
                  AppSpacing.pagePadding, 0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(_category.icon, color: catColor, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Log Care',
                          style: AppTypography.headlineMedium(context)),
                      Text(widget.space.name,
                          style: AppTypography.bodySmall(context)
                              .copyWith(color: context.colTextMuted)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: context.colBorderFaint),
            const SizedBox(height: AppSpacing.md),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Category chips ─────────────────────────────────
                    Text('Type',
                        style: AppTypography.bodySmall(context)
                            .copyWith(color: context.colTextMuted)),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: _batchCategories.map((cat) {
                        final sel = _category == cat;
                        final c = cat.color;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: GestureDetector(
                            onTap: () => setState(() => _category = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: sel
                                    ? c.withValues(alpha: 0.15)
                                    : context.colSurface2,
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull),
                                border: Border.all(
                                  color: sel
                                      ? c.withValues(alpha: 0.7)
                                      : context.colBorder,
                                  width: sel ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(cat.icon,
                                      size: 13,
                                      color: sel
                                          ? c
                                          : context.colTextMuted),
                                  const SizedBox(width: 5),
                                  Text(
                                    cat.categoryLabel,
                                    style: AppTypography.labelSmall(context)
                                        .copyWith(
                                      color: sel
                                          ? c
                                          : context.colTextSecondary,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Plant selection ────────────────────────────────
                    Row(
                      children: [
                        Text(
                          '${_selectedIds.length} of '
                          '${widget.plants.length} selected',
                          style: AppTypography.bodySmall(context)
                              .copyWith(color: context.colTextMuted),
                        ),
                        const Spacer(),
                        // All / None toggle
                        GestureDetector(
                          onTap: () => setState(() {
                            if (_selectedIds.length ==
                                widget.plants.length) {
                              _selectedIds.clear();
                            } else {
                              _selectedIds = widget.plants
                                  .map((p) => p.id)
                                  .toSet();
                            }
                          }),
                          child: Text(
                            _selectedIds.length == widget.plants.length
                                ? 'Deselect all'
                                : 'Select all',
                            style: AppTypography.labelSmall(context)
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Plant list
                    ...widget.plants.map((plant) {
                      final selected = _selectedIds.contains(plant.id);
                      final last = _lastCare(plant.id);
                      final lastLabel = _lastCareLabel(last);
                      final lastColor = _lastCareColor(last, context);
                      final statusColor =
                          AppColors.statusColor(plant.statusLabel);

                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedIds.remove(plant.id);
                          } else {
                            _selectedIds.add(plant.id);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(
                              bottom: AppSpacing.xs),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: selected
                                ? catColor.withValues(alpha: 0.06)
                                : context.colSurface2,
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd),
                            border: Border.all(
                              color: selected
                                  ? catColor.withValues(alpha: 0.4)
                                  : context.colBorder,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Checkbox
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? catColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: selected
                                        ? catColor
                                        : context.colBorder,
                                    width: 1.5,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(Icons.check_rounded,
                                        size: 13, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: AppSpacing.sm),

                              // Status dot
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),

                              // Name + strain
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(plant.name,
                                        style: AppTypography.labelLarge(
                                            context)
                                            .copyWith(fontSize: 13)),
                                    if (plant.strain.isNotEmpty &&
                                        plant.strain != 'Unknown')
                                      Text(
                                        plant.strain,
                                        style:
                                            AppTypography.bodySmall(context)
                                                .copyWith(fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),

                              // Last care badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: lastColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusFull),
                                  border: Border.all(
                                      color: lastColor
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  lastLabel,
                                  style: AppTypography.labelSmall(context)
                                      .copyWith(
                                    color: lastColor,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: AppSpacing.md),

                    // ── Optional note ──────────────────────────────────
                    TextField(
                      controller: _noteCtrl,
                      style: TextStyle(color: context.colTextPrimary),
                      decoration: InputDecoration(
                        labelText: 'Note (optional)',
                        hintText:
                            'Leave empty to use "${_defaultContent(_category)}"',
                        hintStyle: TextStyle(
                            color: context.colTextMuted, fontSize: 12),
                        prefixIcon:
                            const Icon(Icons.notes_rounded, size: 18),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Log button ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : Icon(_category.icon, size: 18),
                        label: Text(
                          _selectedIds.isEmpty
                              ? 'Select at least one plant'
                              : 'Log ${_category.categoryLabel} '
                                'for ${_selectedIds.length} '
                                '${_selectedIds.length == 1 ? 'plant' : 'plants'}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              canLog ? catColor : context.colSurface3,
                          foregroundColor:
                              canLog ? Colors.white : context.colTextMuted,
                          padding:
                              const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd),
                          ),
                          elevation: 0,
                          textStyle: AppTypography.labelLarge(context)
                              .copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                        ),
                        onPressed: canLog ? () => _log(context) : null,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10)),
                        child: Text('Cancel',
                            style: AppTypography.labelLarge(context)
                                .copyWith(
                                    color: context.colTextSecondary,
                                    fontSize: 14)),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
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
