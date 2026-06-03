import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/plant.dart';
import '../../../repository/grow_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/known_tags.dart';
import '../../app_sheet.dart';
import '../../strain_autocomplete_field.dart';
import '../../tag_editor.dart';

/// Q7 — Edit-plant bottom sheet.
///
/// Extracted from `plant_detail_screen.dart`'s `_showEditPlantDialog`.
/// Surfaces every editable field on a [Plant] in a single sheet —
/// name, strain, phenotype, genetics, mother plant (for clones),
/// medium, light, pot size, start date, tags (F8), and the
/// stage-aware reminder cadence toggle (F10).
abstract final class EditPlantSheet {
  EditPlantSheet._();

  static Future<void> show(
    BuildContext context, {
    required GrowRepository repo,
    required Plant plant,
  }) {
    final nameCtrl = TextEditingController(text: plant.name);
    final strainCtrl = TextEditingController(text: plant.strain);
    final phenoCtrl = TextEditingController(text: plant.phenotypeTag ?? '');
    DateTime selectedStartDate = plant.startDate;
    bool selectedIsAutoflower = plant.isAutoflower;
    String? selectedMedium = plant.medium;
    String? selectedLightType = plant.lightType;
    double? selectedPotSize = plant.potSizeLitres;
    String? selectedMotherPlantId = plant.motherPlantId;
    // F8 — editable tag list.
    final plantTags = List<String>.from(plant.tags);
    // F10 — stage-aware interval adjustment toggle.
    bool autoAdjustByStage = plant.autoAdjustIntervalsByStage;

    // Bug fix: pop-with-result pattern -- see add_note_sheet.dart.
    return showModalBottomSheet<Plant>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AppSheet(
          title: 'Edit Plant',
          subtitle: 'Update name, strain & dates',
          icon: Icons.edit_rounded,
          iconColor: AppColors.primary,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: ctx.colTextPrimary),
              decoration: const InputDecoration(labelText: 'Plant Name'),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Strain autocomplete ──────────────
            StrainAutocompleteField(
              initialValue: strainCtrl.text,
              onTextChanged: (v) => strainCtrl.text = v,
              onStrainSelected: (strain) => ss(() {
                strainCtrl.text = strain.name;
                selectedIsAutoflower = strain.isAutoflower;
              }),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Phenotype tag ────────────────────
            TextField(
              controller: phenoCtrl,
              style: TextStyle(color: ctx.colTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Phenotype Tag (optional)',
                hintText: 'e.g. Pheno #1, Purple pheno…',
                prefixIcon: Icon(Icons.biotech_rounded, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Quick-suggest chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: StatefulBuilder(
                builder: (_, setSuggest) => Row(
                  children: [
                    for (final tag in const [
                      'Pheno #1', 'Pheno #2', 'Pheno #3',
                      'Purple', 'Tall', 'Short', 'Resinous',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            phenoCtrl.text = tag;
                            setSuggest(() {});
                            ss(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: phenoCtrl.text == tag
                                  ? AppColors.training.withValues(alpha: 0.2)
                                  : ctx.colSurface3,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull),
                              border: Border.all(
                                color: phenoCtrl.text == tag
                                    ? AppColors.training
                                    : ctx.colBorder,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                color: phenoCtrl.text == tag
                                    ? AppColors.training
                                    : ctx.colTextSecondary,
                                fontWeight: phenoCtrl.text == tag
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),
            // ── Genetics ────────────────────────
            Row(children: [
              Text('Genetics:', style: AppTypography.bodyMedium(ctx)),
              const SizedBox(width: AppSpacing.sm),
              ChoiceChip(
                label: const Text('Photoperiod'),
                selected: !selectedIsAutoflower,
                onSelected: (_) => ss(() => selectedIsAutoflower = false),
                selectedColor: AppColors.growing,
                labelStyle: TextStyle(
                  color: !selectedIsAutoflower
                      ? Colors.black
                      : ctx.colTextSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ChoiceChip(
                label: const Text('Autoflower'),
                selected: selectedIsAutoflower,
                onSelected: (_) => ss(() => selectedIsAutoflower = true),
                selectedColor: AppColors.drying,
                labelStyle: TextStyle(
                  color: selectedIsAutoflower
                      ? Colors.black
                      : ctx.colTextSecondary,
                ),
              ),
            ]),

            const SizedBox(height: AppSpacing.sm),
            // ── Mother plant (only shown when plant is a clone) ──
            if (plant.isClone) ...[
              Consumer<GrowRepository>(
                builder: (_, repo, __) {
                  final candidates = repo.plants
                      .where((p) =>
                          p.id != plant.id &&
                          (p.status == PlantStatus.growing ||
                              p.status == PlantStatus.harvested))
                      .toList();
                  return DropdownButtonFormField<String>(
                    initialValue: selectedMotherPlantId,
                    dropdownColor: ctx.colSurface2,
                    decoration: const InputDecoration(
                      labelText: 'Mother Plant (optional)',
                      prefixIcon:
                          Icon(Icons.account_tree_rounded, size: 18),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('— No mother selected —',
                            style: TextStyle(color: ctx.colTextMuted)),
                      ),
                      ...candidates.map((p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Text('${p.name} (${p.strain})',
                                style:
                                    TextStyle(color: ctx.colTextPrimary)),
                          )),
                    ],
                    onChanged: (v) =>
                        ss(() => selectedMotherPlantId = v),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ── Medium ──────────────────────────
            Row(children: [
              Text('Medium:', style: AppTypography.bodyMedium(ctx)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final entry in const {
                      'soil': 'Soil',
                      'coco': 'Coco',
                      'hydro': 'Hydro',
                      'living_soil': 'Living Soil',
                      'other': 'Other',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: selectedMedium == entry.key,
                        onSelected: (_) => ss(() => selectedMedium =
                            selectedMedium == entry.key ? null : entry.key),
                        selectedColor: AppColors.secondary,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: selectedMedium == entry.key
                              ? Colors.white
                              : ctx.colTextSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: AppSpacing.sm),
            // ── Light type ──────────────────────
            Row(children: [
              Text('Light:', style: AppTypography.bodyMedium(ctx)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final entry in const {
                      'led': 'LED',
                      'hps': 'HPS',
                      'cmh': 'CMH',
                      'fluorescent': 'Fluoro',
                      'outdoor': 'Outdoor',
                      'other': 'Other',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: selectedLightType == entry.key,
                        onSelected: (_) => ss(() => selectedLightType =
                            selectedLightType == entry.key
                                ? null
                                : entry.key),
                        selectedColor: AppColors.drying,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: selectedLightType == entry.key
                              ? Colors.black
                              : ctx.colTextSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: AppSpacing.sm),

            // ── Pot size ────────────────────────
            Text('Pot size',
                style: AppTypography.bodySmall(ctx)
                    .copyWith(color: ctx.colTextMuted)),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: {
                1.0: '1 L',
                3.0: '3 L',
                5.0: '5 L',
                10.0: '10 L',
                15.0: '15 L',
                20.0: '20 L',
                25.0: '25 L+',
              }.entries.map((e) {
                final sel = selectedPotSize == e.key;
                return ChoiceChip(
                  label: Text(e.value),
                  selected: sel,
                  onSelected: (_) =>
                      ss(() => selectedPotSize = sel ? null : e.key),
                  selectedColor: AppColors.growing,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: sel ? Colors.black : ctx.colTextSecondary,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.sm),
            // ── Start date ──────────────────────
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: selectedStartDate,
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365 * 3)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  ss(() => selectedStartDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: ctx.colSurface3,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Start: ${selectedStartDate.toLocal().toString().split(' ')[0]}',
                      style: AppTypography.bodyMedium(ctx)
                          .copyWith(color: AppColors.primary),
                    ),
                    const Icon(Icons.calendar_today,
                        color: AppColors.primary, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── F8 — Tags ────────────────────────
            TagEditor(
              tags: plantTags,
              suggestions: allKnownTags(repo),
              onTagsChanged: (next) => ss(() {
                plantTags
                  ..clear()
                  ..addAll(next);
              }),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── F10 — Stage-aware reminder cadence ────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.training,
              title: Text('Auto-adjust care cadence by stage',
                  style: AppTypography.labelLarge(ctx)),
              subtitle: Text(
                'Stretch watering/feeding/IPM intervals as the plant '
                'moves from veg → flower → flush. '
                'Base values below are treated as the veg baseline.',
                style: AppTypography.bodySmall(ctx)
                    .copyWith(color: ctx.colTextMuted),
              ),
              value: autoAdjustByStage,
              onChanged: (v) => ss(() => autoAdjustByStage = v),
            ),

            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  elevation: 0,
                  textStyle: AppTypography.labelLarge(ctx).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final resolvedStrain = strainCtrl.text.trim().isEmpty
                      ? plant.strain
                      : strainCtrl.text.trim();
                  final rawPheno = phenoCtrl.text.trim();
                  Navigator.pop(
                      ctx,
                      plant.copyWith(
                        name: nameCtrl.text.trim(),
                        strain: resolvedStrain,
                        startDate: selectedStartDate,
                        isAutoflower: selectedIsAutoflower,
                        medium: selectedMedium,
                        lightType: selectedLightType,
                        phenotypeTag: rawPheno.isEmpty ? null : rawPheno,
                        potSizeLitres: selectedPotSize,
                        motherPlantId:
                            plant.isClone ? selectedMotherPlantId : null,
                        tags: List.from(plantTags),
                        autoAdjustIntervalsByStage: autoAdjustByStage,
                      ));
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
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
    ).then((updated) {
      // Bug fix v6 -- see add_note_sheet.dart for the focus-blur race.
      Future.delayed(const Duration(milliseconds: 500), () {
        nameCtrl.dispose();
        strainCtrl.dispose();
        phenoCtrl.dispose();
      });
      if (updated == null) return;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => repo.updatePlant(updated));
    });
  }
}
