import 'package:flutter/material.dart';
import '../models/time_window.dart';
import '../theme/app_colors.dart';

class TimeWindowSelector extends StatelessWidget {
  final TimeWindow selected;
  final ValueChanged<TimeWindow> onChanged;

  const TimeWindowSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: TimeWindow.values.map((window) {
        final isSelected = window == selected;

        return ChoiceChip(
          label: Text(window.label),
          selected: isSelected,
          onSelected: (_) => onChanged(window),
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
