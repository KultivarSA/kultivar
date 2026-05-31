import 'package:flutter/material.dart';

import '../../models/plant_note.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Horizontal chip row of note categories with counts, used on the
/// plant-detail notes section.
///
/// Performance note (also see comment inside [build]): the count
/// histogram is built in a single linear pass per build — replaces the
/// prior O(categories × notes) scan that became noticeable once plants
/// accumulated 50+ notes.
///
/// Extracted from `plant_detail_screen.dart` (Q1a).
class NoteCategoryFilterBar extends StatelessWidget {
  final List<PlantNote> notes;
  final NoteCategory? selected;
  final ValueChanged<NoteCategory> onSelected;

  const NoteCategoryFilterBar({
    super.key,
    required this.notes,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Single linear pass over notes builds a {category: count} histogram
    // — replaces N category × M note rescans on every rebuild, which got
    // expensive once plants accumulated 50+ notes.
    final countsByCategory = <NoteCategory, int>{};
    for (final n in notes) {
      countsByCategory[n.category] = (countsByCategory[n.category] ?? 0) + 1;
    }
    final presentCategories = NoteCategory.values
        .where((cat) => countsByCategory[cat] != null)
        .toList();

    if (presentCategories.length < 2) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presentCategories.map((cat) {
          final isSelected = selected == cat;
          final count = countsByCategory[cat] ?? 0;
          final color = cat.color;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSelected(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.18)
                      : context.colSurface2,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: isSelected
                        ? color.withValues(alpha: 0.6)
                        : context.colBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon,
                        size: 12,
                        color: isSelected ? color : context.colTextMuted),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      cat.categoryLabel,
                      style: AppTypography.labelSmall(context).copyWith(
                        color: isSelected ? color : context.colTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.2)
                            : context.colSurface3,
                        borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull),
                      ),
                      child: Text(
                        '$count',
                        style: AppTypography.labelSmall(context).copyWith(
                          fontSize: 10,
                          color:
                              isSelected ? color : context.colTextMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
