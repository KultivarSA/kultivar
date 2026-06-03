import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/strain_library.dart';
import '../data/training_reference.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TrainingLogSheet
//
// Structured training event logger.  Stays within the AppSheet chrome.
//
// Usage:
//   TrainingLogSheet.show(context, plant: plant);
// ─────────────────────────────────────────────────────────────────────────────

class TrainingLogSheet extends StatefulWidget {
  final Plant plant;

  const TrainingLogSheet({super.key, required this.plant});

  static Future<void> show(BuildContext context, {required Plant plant}) {
    // Bug fix: pop-with-result pattern -- see add_note_sheet.dart.
    final repo = context.read<GrowRepository>();
    return showModalBottomSheet<PlantNote>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrainingLogSheet(plant: plant),
    ).then((note) {
      if (note == null) return;
      // Bug fix v7 -- see batch_care_sheet.dart.
      Future.delayed(
          const Duration(milliseconds: 500), () => repo.addNote(note));
    });
  }

  @override
  State<TrainingLogSheet> createState() => _TrainingLogSheetState();
}

class _TrainingLogSheetState extends State<TrainingLogSheet> {
  TrainingTechnique? _technique;
  TrainingSeverity? _severity;
  String? _targetSite;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _nodeCtrl;
  late final TextEditingController _recoveryCtrl;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
    _nodeCtrl = TextEditingController();
    _recoveryCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _nodeCtrl.dispose();
    _recoveryCtrl.dispose();
    super.dispose();
  }

  // ── Computed ────────────────────────────────────────────────────────────

  bool get _canSave => _technique != null;

  /// Catalog entry for the current plant's strain (for recommendations).
  BuiltInStrain? get _catalogStrain => kStrainLibrary
      .where(
          (s) => s.name.toLowerCase() == widget.plant.strain.toLowerCase())
      .firstOrNull;

  /// Catalog strain training keys → resolved technique labels for display.
  /// Keys are lowercase abbreviations ('lst', 'fim', 'mainline', etc.).
  List<String> get _recommendations {
    final strain = _catalogStrain;
    if (strain == null) return [];
    return strain.training
        .map(_techniqueFromCatalogKey)
        .whereType<TrainingTechnique>()
        .map((t) => t.label)
        .toList();
  }

  /// Map a catalog training key (e.g. 'fim', 'mainline') to a technique enum.
  static TrainingTechnique? _techniqueFromCatalogKey(String key) {
    final k = key.toLowerCase().trim();
    for (final t in TrainingTechnique.values) {
      if (t.label.toLowerCase() == k || t.name.toLowerCase() == k) return t;
    }
    // Handle catalogue abbreviations that don't exactly match label/name.
    switch (k) {
      case 'fim':        return TrainingTechnique.fimming;
      case 'mainline':   return TrainingTechnique.mainlining;
      case 'lollipop':   return TrainingTechnique.lollipopping;
      case 'schwazz':    return TrainingTechnique.schwazzing;
      case 'supercrop':  return TrainingTechnique.supercropping;
    }
    return null;
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _selectTechnique(TrainingTechnique t) {
    setState(() {
      _technique = t;
      // Reset severity and site when technique changes.
      _severity = null;
      _targetSite = null;
      _nodeCtrl.clear();
      // Pre-fill recovery days from technique default.
      _recoveryCtrl.text = t.defaultRecoveryDays.toString();
    });
  }

  void _save() {
    if (!_canSave) return;
    final repo = context.read<GrowRepository>();
    // repo is still needed for newId(); persistence now happens
    // inside show().then() after the modal route is fully popped.

    // Build target site string.
    String? site = _targetSite;
    final node = int.tryParse(_nodeCtrl.text.trim());
    if (node != null) site = 'Node $node';

    final details = TrainingDetails.auto(
      technique: _technique!,
      severity: _severity,
      targetSite: site,
      nodeNumber: node,
    );

    // Override recovery days if user edited them.
    final override = int.tryParse(_recoveryCtrl.text.trim());
    final finalDetails = override != null && override != details.recoveryDays
        ? TrainingDetails(
            technique: details.technique,
            severity: details.severity,
            targetSite: details.targetSite,
            nodeNumber: details.nodeNumber,
            recoveryDays: override,
          )
        : details;

    final note = PlantNote(
      id: repo.newId(),
      plantId: widget.plant.id,
      createdAt: DateTime.now(),
      content: _buildContent(finalDetails),
      category: NoteCategory.training,
      trainingDetails: finalDetails,
    );

    // Bug fix: pop with the note as result; show().then() persists it.
    Navigator.pop(context, note);
  }

  String _buildContent(TrainingDetails d) {
    final parts = <String>[d.technique.label];
    if (d.severity != null) parts.add(d.severity!.label.toLowerCase());
    if (d.targetSite != null) parts.add('· ${d.targetSite}');
    if (_notesCtrl.text.trim().isNotEmpty) {
      parts.add('— ${_notesCtrl.text.trim()}');
    }
    return parts.join(' ');
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final info =
        _technique != null ? kTrainingReference[_technique!] : null;

    return AppSheet(
      title: 'Log Training',
      subtitle: widget.plant.name,
      icon: Icons.content_cut_rounded,
      iconColor: AppColors.training,
      children: [
        // ── Strain recommendations ───────────────────────────────────────
        if (_recommendations.isNotEmpty && _technique == null) ...[
          _RecommendationBanner(
            strainName: widget.plant.strain,
            techniques: _recommendations,
            onTap: (t) {
              final match = TrainingTechnique.values
                  .where((v) => v.label.toLowerCase() == t.toLowerCase())
                  .firstOrNull;
              if (match != null) _selectTechnique(match);
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Technique grid ───────────────────────────────────────────────
        Text(
          'Technique',
          style: AppTypography.bodySmall(context)
              .copyWith(color: context.colTextMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        _TechniqueGrid(
          selected: _technique,
          onSelect: _selectTechnique,
        ),

        // ── Detail panel (animated) ──────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          child: _technique == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    // A4 — theme-aware so light mode doesn't pick up
                    // the bumped dark-mode borderFaint.
                    Divider(height: 1, color: context.colBorderFaint),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Stress level indicator ──────────────────
                    if (info != null) _StressIndicator(info: info),

                    // ── Severity chips ──────────────────────────
                    if (_technique!.hasSeverity) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text('Severity',
                          style: AppTypography.bodySmall(context)
                              .copyWith(color: context.colTextMuted)),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: TrainingSeverity.values.map((s) {
                          final sel = _severity == s;
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _severity = sel ? null : s;
                                  _recoveryCtrl.text =
                                      (sel ? _technique!.defaultRecoveryDays
                                           : s.recoveryDaysFor(_technique!))
                                          .toString();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppColors.training.withValues(
                                          alpha: 0.15)
                                      : context.colSurface3,
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusFull),
                                  border: Border.all(
                                    color: sel
                                        ? AppColors.training
                                        : context.colBorder,
                                    width: sel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  s.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: sel
                                        ? AppColors.training
                                        : context.colTextSecondary,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // ── Target site ─────────────────────────────
                    if (_technique!.hasTargetSite) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text('Target Site (optional)',
                          style: AppTypography.bodySmall(context)
                              .copyWith(color: context.colTextMuted)),
                      const SizedBox(height: AppSpacing.xs),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              targetSitesFor(_technique!).map((site) {
                            final sel = _targetSite == site;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _targetSite = sel ? null : site),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.secondary.withValues(
                                            alpha: 0.12)
                                        : context.colSurface3,
                                    borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusFull),
                                    border: Border.all(
                                      color: sel
                                          ? AppColors.secondary
                                          : context.colBorder,
                                    ),
                                  ),
                                  child: Text(
                                    site,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: sel
                                          ? AppColors.secondary
                                          : context.colTextSecondary,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    // ── Node number (topping / FIM) ──────────────
                    if (_technique == TrainingTechnique.topping ||
                        _technique == TrainingTechnique.fimming) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _nodeCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: TextStyle(color: context.colTextPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Node # (optional)',
                            hintText: '4',
                            prefixIcon:
                                Icon(Icons.looks_one_rounded, size: 18),
                          ),
                        ),
                      ),
                    ],

                    // ── Recovery days ────────────────────────────
                    if (_technique!.defaultRecoveryDays > 0) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Icon(Icons.healing_rounded,
                              size: 14, color: AppColors.training),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Expected recovery',
                            style: AppTypography.bodySmall(context)
                                .copyWith(color: context.colTextMuted),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: _recoveryCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style: TextStyle(
                                  color: context.colTextPrimary,
                                  fontSize: 14),
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                suffixText: 'days',
                                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── Notes ────────────────────────────────────
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      style: TextStyle(color: context.colTextPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'Anything worth remembering…',
                        prefixIcon:
                            Icon(Icons.notes_rounded, size: 18),
                      ),
                    ),

                    // ── Technique reference ─────────────────────
                    if (info != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      GestureDetector(
                        onTap: () =>
                            _TechniqueReferenceSheet.show(context, info),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.help_outline_rounded,
                                size: 14,
                                color: context.colTextMuted),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              'About ${info.name}',
                              style: AppTypography.bodySmall(context)
                                  .copyWith(
                                color: context.colTextMuted,
                                decoration: TextDecoration.underline,
                                decorationColor: context.colTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Save CTA ────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(_technique == null
                ? 'Select a technique above'
                : 'Log ${_technique!.label}'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _canSave ? AppColors.training : context.colSurface3,
              foregroundColor:
                  _canSave ? Colors.white : context.colTextMuted,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              elevation: 0,
              textStyle: AppTypography.labelLarge(context)
                  .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            onPressed: _canSave ? _save : null,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTypography.labelLarge(context)
                    .copyWith(color: context.colTextMuted)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Technique grid — 3-column icon cards
// ─────────────────────────────────────────────────────────────────────────────

class _TechniqueGrid extends StatelessWidget {
  final TrainingTechnique? selected;
  final ValueChanged<TrainingTechnique> onSelect;

  const _TechniqueGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final techniques = TrainingTechnique.values
        .where((t) => t != TrainingTechnique.other)
        .toList()
      ..add(TrainingTechnique.other);

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: techniques.map((t) {
        final info = kTrainingReference[t]!;
        final isSelected = selected == t;
        final stressColor = info.stressColor;
        return GestureDetector(
          onTap: () => onSelect(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.training.withValues(alpha: 0.12)
                  : context.colSurface2,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isSelected
                    ? AppColors.training
                    : context.colBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  info.icon,
                  size: 22,
                  color:
                      isSelected ? AppColors.training : stressColor,
                ),
                const SizedBox(height: 5),
                Text(
                  t.shortLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isSelected
                        ? AppColors.training
                        : context.colTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Stress dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < t.stressLevel
                            ? stressColor
                            : context.colSurface3,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stress level indicator bar
// ─────────────────────────────────────────────────────────────────────────────

class _StressIndicator extends StatelessWidget {
  final TrainingTechniqueInfo info;
  const _StressIndicator({required this.info});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(info.icon, size: 16, color: AppColors.training),
        const SizedBox(width: AppSpacing.xs),
        Text(
          info.name,
          style: AppTypography.labelLarge(context)
              .copyWith(fontSize: 14, color: AppColors.training),
        ),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: info.stressColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
                color: info.stressColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(
                  3,
                  (i) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < info.stressLevel
                              ? info.stressColor
                              : info.stressColor.withValues(alpha: 0.2),
                        ),
                      )),
              Text(
                info.stressLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: info.stressColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendation banner — shown when catalog strain has training suggestions
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationBanner extends StatelessWidget {
  final String strainName;
  final List<String> techniques;
  final void Function(String technique) onTap;

  const _RecommendationBanner({
    required this.strainName,
    required this.techniques,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.training.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
            color: AppColors.training.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.recommend_rounded,
                  size: 13, color: AppColors.training),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Recommended for $strainName',
                  style: AppTypography.bodySmall(context).copyWith(
                    color: AppColors.training,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: techniques
                .take(4)
                .map((t) => GestureDetector(
                      onTap: () => onTap(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.training
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.training,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Technique reference sheet — full technique info on a ?-tap
// ─────────────────────────────────────────────────────────────────────────────

class _TechniqueReferenceSheet extends StatelessWidget {
  final TrainingTechniqueInfo info;

  const _TechniqueReferenceSheet({required this.info});

  static void show(BuildContext context, TrainingTechniqueInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TechniqueReferenceSheet(info: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: info.name,
      icon: info.icon,
      iconColor: AppColors.training,
      children: [
        // Stress + recovery row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: info.stressColor.withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                    color: info.stressColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                info.stressLabel,
                style: TextStyle(
                  color: info.stressColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (info.defaultRecoveryDays > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.training.withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                      color: AppColors.training.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.healing_rounded,
                        size: 11, color: AppColors.training),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      '~${info.defaultRecoveryDays}d recovery',
                      style: const TextStyle(
                        color: AppColors.training,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Description
        Text(
          info.description,
          style:
              AppTypography.bodyMedium(context).copyWith(height: 1.55),
        ),
        const SizedBox(height: AppSpacing.md),

        // When to apply
        _RefRow(
          icon: Icons.schedule_rounded,
          color: AppColors.secondary,
          label: 'When to apply',
          value: info.whenToApply,
        ),
        const SizedBox(height: AppSpacing.sm),

        // Yield impact
        _RefRow(
          icon: Icons.bar_chart_rounded,
          color: AppColors.primary,
          label: 'Yield impact',
          value: info.yieldImpact,
        ),
        const SizedBox(height: AppSpacing.md),

        // Pro tip
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.drying.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
                color: AppColors.drying.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.tips_and_updates_rounded,
                  size: 15, color: AppColors.drying),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pro Tip',
                      style: AppTypography.labelLarge(context).copyWith(
                          fontSize: 12, color: AppColors.drying),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      info.proTip,
                      style: AppTypography.bodySmall(context)
                          .copyWith(height: 1.5, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _RefRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _RefRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label  ',
                  style: AppTypography.labelLarge(context)
                      .copyWith(fontSize: 12, color: color),
                ),
                TextSpan(
                  text: value,
                  style: AppTypography.bodySmall(context)
                      .copyWith(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
