import 'package:flutter/material.dart';
import '../models/time_window.dart';
import '../theme/app_colors.dart';

class TimeWindowSelector extends StatelessWidget {
  final TimeWindow selected;
  final ValueChanged<TimeWindow> onChanged;

  /// Windows the current subscription tier may not select.  Rendered with
  /// a premium lock icon; tapping one fires [onLockedTap] (typically the
  /// paywall) instead of [onChanged].
  final Set<TimeWindow> locked;
  final VoidCallback? onLockedTap;

  const TimeWindowSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.locked = const {},
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: TimeWindow.values.map((window) {
        final isSelected = window == selected;
        final isLocked = locked.contains(window);

        return ChoiceChip(
          avatar: isLocked
              ? const Icon(Icons.workspace_premium_rounded,
                  size: 14, color: AppColors.accent)
              : null,
          label: Text(window.label),
          selected: isSelected,
          onSelected: (_) =>
              isLocked ? onLockedTap?.call() : onChanged(window),
          selectedColor: AppColors.primary,
          backgroundColor: context.colSurface3,
          labelStyle: TextStyle(
            color: isSelected ? Colors.black : context.colTextSecondary,
            fontWeight: FontWeight.bold,
          ),
        );
      }).toList(),
    );
  }
}
