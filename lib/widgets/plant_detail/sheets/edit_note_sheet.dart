import 'package:flutter/material.dart';

import '../../../models/plant_note.dart';
import '../../../repository/grow_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/known_tags.dart';
import '../../app_sheet.dart';
import '../../tag_editor.dart';

/// Q7 — Edit-note bottom sheet.
///
/// Extracted from `plant_detail_screen.dart`'s `_showEditNoteDialog`.
/// The note's original timestamp is preserved — only category, content
/// and tags are mutable.  Photos and voice notes can't be edited from
/// here (they have their own attachment editors on the add-note flow);
/// this surface is for fast text + categorisation tweaks.
abstract final class EditNoteSheet {
  EditNoteSheet._();

  /// Opens the sheet.  Returns when the user either saves or cancels.
  static Future<void> show(
    BuildContext context, {
    required GrowRepository repo,
    required PlantNote note,
  }) {
    final contentCtrl = TextEditingController(text: note.content);
    NoteCategory selectedCat = note.category;
    // F8 — editable tag list seeded from the note's current tags.
    final editedTags = List<String>.from(note.tags);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AppSheet(
          title: 'Edit Note',
          subtitle: 'Original timestamp preserved',
          icon: Icons.edit_note_rounded,
          iconColor: AppColors.primary,
          children: [
            // ── Category chips ────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: NoteCategory.values.map((cat) {
                final isSel = selectedCat == cat;
                final col = cat.color;
                return FilterChip(
                  label: Text(cat.name.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          color: isSel
                              ? Colors.white
                              : context.colTextMuted)),
                  selected: isSel,
                  onSelected: (_) => ss(() => selectedCat = cat),
                  backgroundColor: context.colSurface3,
                  selectedColor: col,
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Note body ─────────────────────────
            TextField(
              controller: contentCtrl,
              maxLines: 5,
              autofocus: true,
              style: TextStyle(color: context.colTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Edit your note…',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── F8 — Tag editor ───────────────────
            TagEditor(
              tags: editedTags,
              suggestions: allKnownTags(repo),
              onTagsChanged: (next) => ss(() {
                editedTags
                  ..clear()
                  ..addAll(next);
              }),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Save ──────────────────────────────
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
                  textStyle: AppTypography.labelLarge(ctx)
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  final text = contentCtrl.text.trim();
                  if (text.isEmpty) return;
                  repo.updateNote(note.copyWith(
                    content: text,
                    category: selectedCat,
                    tags: List.from(editedTags),
                  ));
                  Navigator.pop(ctx);
                },
                child: const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // ── Cancel ────────────────────────────
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: AppTypography.labelLarge(ctx)
                        .copyWith(color: ctx.colTextSecondary)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => contentCtrl.dispose());
  }
}
