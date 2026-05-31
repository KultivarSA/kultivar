import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// F8 — Free-form tag editor.
///
/// Pure UI; the parent owns the [tags] list and receives mutations via
/// [onTagsChanged].  Optional [suggestions] populates an autocomplete
/// chip row so users picking from "their existing pool" don't end up
/// with `mother` vs `Mother` vs `#mother` duplicates.
///
/// Tag rules (enforced by [normalizeTag]):
///   * lower-cased
///   * leading `#` stripped
///   * whitespace replaced with `-`
///   * empty/whitespace-only inputs rejected
///
/// Duplicates within the current note's list are silently ignored on
/// add.  De-duplication across the whole app is the caller's job.
class TagEditor extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;
  final List<String> suggestions;
  final String label;

  const TagEditor({
    super.key,
    required this.tags,
    required this.onTagsChanged,
    this.suggestions = const [],
    this.label = 'Tags',
  });

  /// Public so tests + the search filter can apply the exact same rules.
  static String? normalizeTag(String raw) {
    var s = raw.trim().toLowerCase();
    if (s.startsWith('#')) s = s.substring(1);
    s = s.replaceAll(RegExp(r'\s+'), '-');
    if (s.isEmpty) return null;
    return s;
  }

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _addRaw(String raw) {
    final norm = TagEditor.normalizeTag(raw);
    if (norm == null) return;
    if (widget.tags.contains(norm)) {
      _ctrl.clear();
      return;
    }
    widget.onTagsChanged([...widget.tags, norm]);
    _ctrl.clear();
  }

  void _remove(String tag) {
    widget.onTagsChanged([...widget.tags]..remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    // Suggestions not already on this note.
    final unsuggested = widget.suggestions
        .where((s) => !widget.tags.contains(s))
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTypography.bodySmall(context)),
        const SizedBox(height: AppSpacing.xs),

        // ── Active tags as chips with delete handles ──
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.tags
                .map((t) => Chip(
                      label: Text('#$t',
                          style: AppTypography.labelSmall(context)
                              .copyWith(color: AppColors.primary)),
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.10),
                      side: BorderSide(
                          color:
                              AppColors.primary.withValues(alpha: 0.4)),
                      deleteIcon: const Icon(Icons.close_rounded,
                          size: 14, color: AppColors.primary),
                      onDeleted: () => _remove(t),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),

        // ── Input field ────────────────────────────
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            // Block control chars that would never be useful in a tag.
            FilteringTextInputFormatter.deny(RegExp(r'[,#\n\t]')),
            LengthLimitingTextInputFormatter(32),
          ],
          style: TextStyle(color: context.colTextPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Add a tag (e.g. mother, test-pheno)',
            hintStyle: TextStyle(color: context.colTextMuted, fontSize: 13),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_rounded, size: 18),
              tooltip: 'Add tag',
              onPressed: () => _addRaw(_ctrl.text),
            ),
          ),
          onSubmitted: _addRaw,
        ),

        // ── Suggestion chips ───────────────────────
        if (unsuggested.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'From your library',
            style: AppTypography.labelSmall(context)
                .copyWith(color: context.colTextMuted),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: unsuggested
                .map((s) => ActionChip(
                      label: Text('#$s',
                          style: AppTypography.labelSmall(context)
                              .copyWith(color: context.colTextSecondary)),
                      backgroundColor: context.colSurface3,
                      side: BorderSide(color: context.colBorderFaint),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      onPressed: () => _addRaw(s),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
