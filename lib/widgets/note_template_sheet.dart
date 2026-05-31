import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note_template.dart';
import '../models/plant_note.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class NoteTemplateSheet extends StatefulWidget {
  /// Called when user picks a template.
  /// Returns the template content and category.
  final void Function(NoteTemplate) onSelected;

  const NoteTemplateSheet({
    super.key,
    required this.onSelected,
  });

  @override
  State<NoteTemplateSheet> createState() => _NoteTemplateSheetState();
}

class _NoteTemplateSheetState extends State<NoteTemplateSheet> {
  bool _showCreate = false;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _selectedCategory = 'observation';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: _showCreate
          ? _buildCreateForm(context, repo)
          : _buildList(context, repo),
    );
  }

  Widget _buildList(BuildContext context, GrowRepository repo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Drag handle ───────────────────
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colBorderFaint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // ── Header ────────────────────────
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(Icons.description_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text('Note Templates',
                style: AppTypography.headlineMedium(context)),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _showCreate = true),
            icon: const Icon(Icons.add, color: AppColors.primary, size: 16),
            label: Text('New',
                style: AppTypography.labelLarge(context)
                    .copyWith(color: AppColors.primary)),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        if (repo.noteTemplates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                'No templates yet.\nCreate one to reuse common notes.',
                style: AppTypography.bodyMedium(context),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...repo.noteTemplates.map((t) {
            final catColor = _parseCategory(t.category).color;
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onSelected(t);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.colSurface2,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: catColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_parseCategory(t.category).icon,
                          color: catColor, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title,
                              style: AppTypography.labelLarge(context)),
                          Text(t.content,
                              style: AppTypography.bodySmall(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    // Delete
                    GestureDetector(
                      onTap: () => repo.deleteNoteTemplate(t.id),
                      child: Icon(Icons.close,
                          size: 16, color: context.colTextMuted),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCreateForm(BuildContext context, GrowRepository repo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Drag handle ───────────────────
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colBorderFaint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // ── Header ────────────────────────
        Row(children: [
          GestureDetector(
            onTap: () => setState(() => _showCreate = false),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colSurface3,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(Icons.arrow_back_rounded,
                  color: context.colTextSecondary, size: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('New Template',
              style: AppTypography.headlineMedium(context)),
        ]),
        const SizedBox(height: AppSpacing.md),

        TextField(
          controller: _titleCtrl,
          style: TextStyle(color: context.colTextPrimary),
          decoration: const InputDecoration(labelText: 'Template Name'),
        ),
        const SizedBox(height: AppSpacing.md),

        // Category
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: NoteCategory.values.map((c) {
            final sel = _selectedCategory == c.name;
            final color = c.color;
            return FilterChip(
              label: Text(c.name.toUpperCase(),
                  style: AppTypography.labelSmall(context).copyWith(
                      color: sel ? Colors.white : context.colTextMuted)),
              selected: sel,
              onSelected: (_) => setState(() => _selectedCategory = c.name),
              backgroundColor: context.colSurface3,
              selectedColor: color,
              showCheckmark: false,
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),

        TextField(
          controller: _contentCtrl,
          maxLines: 4,
          style: TextStyle(color: context.colTextPrimary),
          decoration: const InputDecoration(
            labelText: 'Template Content',
            hintText: 'e.g. Watered with 1L, pH 6.2, EC 1.4',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (_titleCtrl.text.trim().isEmpty ||
                  _contentCtrl.text.trim().isEmpty) {
                return;
              }
              repo.addNoteTemplate(NoteTemplate(
                id: repo.newId(),
                title: _titleCtrl.text.trim(),
                content: _contentCtrl.text.trim(),
                category: _selectedCategory,
                createdAt: DateTime.now(),
              ));
              setState(() => _showCreate = false);
            },
            child: const Text('Save Template'),
          ),
        ),
      ],
    );
  }

  /// Parses a [NoteCategory.name] string and returns the matching enum value,
  /// falling back to [NoteCategory.other] for unknown strings.
  NoteCategory _parseCategory(String name) => NoteCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => NoteCategory.other,
      );
}
