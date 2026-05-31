import 'package:flutter/material.dart';

import '../data/strain_library.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class StrainAutocompleteField extends StatefulWidget {
  /// Initial text shown in the field (e.g. when editing).
  final String initialValue;

  /// Called on every keystroke with the raw text.
  final ValueChanged<String> onTextChanged;

  /// Called when the user taps a built-in suggestion. Use this to
  /// auto-fill isAutoflower / targetHarvestDate in the parent sheet.
  final ValueChanged<BuiltInStrain>? onStrainSelected;

  const StrainAutocompleteField({
    super.key,
    this.initialValue = '',
    required this.onTextChanged,
    this.onStrainSelected,
  });

  @override
  State<StrainAutocompleteField> createState() =>
      _StrainAutocompleteFieldState();
}

class _StrainAutocompleteFieldState extends State<StrainAutocompleteField> {
  late final TextEditingController _ctrl;
  List<BuiltInStrain> _suggestions = [];

  // Colour for the type badge on each suggestion.
  static Color _typeColor(String type) {
    switch (type) {
      case 'Indica':
        return AppColors.secondary;
      case 'Sativa':
        return AppColors.growing;
      default:
        return AppColors.primary;
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final q = text.toLowerCase().trim();
    setState(() {
      _suggestions = q.isEmpty
          ? []
          : kStrainLibrary
              .where((s) => s.name.toLowerCase().contains(q))
              .take(6)
              .toList();
    });
    widget.onTextChanged(text);
  }

  void _select(BuiltInStrain strain) {
    _ctrl.text = strain.name;
    // Move cursor to end.
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: strain.name.length));
    setState(() => _suggestions = []);
    widget.onTextChanged(strain.name);
    widget.onStrainSelected?.call(strain);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Text field ────────────────────────────────
        TextField(
          controller: _ctrl,
          style: TextStyle(color: context.colTextPrimary),
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: 'Strain',
            hintText: 'Type to search or enter any name…',
            hintStyle:
                TextStyle(color: context.colTextMuted, fontSize: 13),
            prefixIcon:
                const Icon(Icons.science_rounded, size: 18),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        size: 18, color: context.colTextMuted),
                    tooltip: 'Clear strain',
                    onPressed: () {
                      _ctrl.clear();
                      _onChanged('');
                    },
                  )
                : null,
          ),
        ),

        // ── Suggestion panel ──────────────────────────
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Container(
            decoration: BoxDecoration(
              color: context.colSurface2,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: context.colBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _suggestions.asMap().entries.map((e) {
                final i = e.key;
                final strain = e.value;
                final typeColor = _typeColor(strain.type);
                final isLast = i == _suggestions.length - 1;
                return InkWell(
                  onTap: () => _select(strain),
                  borderRadius: BorderRadius.vertical(
                    top: i == 0
                        ? const Radius.circular(AppSpacing.radiusMd)
                        : Radius.zero,
                    bottom: isLast
                        ? const Radius.circular(AppSpacing.radiusMd)
                        : Radius.zero,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 10),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(
                                  color: context.colBorderFaint)),
                    ),
                    child: Row(children: [
                      // Name
                      Expanded(
                        child: Text(
                          strain.name,
                          style: AppTypography.bodyMedium(context)
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),

                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull),
                          border: Border.all(
                              color: typeColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          strain.type,
                          style: AppTypography.labelSmall(context).copyWith(
                              color: typeColor, fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),

                      // Auto badge (only for autos)
                      if (strain.isAutoflower) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.drying.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
                            border: Border.all(
                                color: AppColors.drying
                                    .withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            'Auto',
                            style:
                                AppTypography.labelSmall(context).copyWith(
                              color: AppColors.drying,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],

                      // Flower-time label
                      Text(
                        strain.isAutoflower
                            ? '~${strain.flowerDays}d'
                            : '~${strain.flowerDays}d flower',
                        style: AppTypography.bodySmall(context)
                            .copyWith(color: context.colTextMuted),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
