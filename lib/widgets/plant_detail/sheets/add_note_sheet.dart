import 'package:flutter/material.dart';

import '../../../models/plant.dart';
import '../../../models/plant_note.dart';
import '../../../repository/grow_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/known_tags.dart';
import '../../../utils/pot_label.dart';
import '../../app_sheet.dart';
import '../../deficiency_wizard_sheet.dart';
import '../../photo_attachment_picker.dart';
import '../../tag_editor.dart';
import '../../voice_note_attachment.dart';

const _issues = [
  'Mold',
  'Pest',
  'Nutrient Deficiency',
  'Yellowing',
  'Burn',
  'Other',
];

/// Q7 — Add-note bottom sheet.
///
/// Extracted from `plant_detail_screen.dart`'s `_showAddNoteDialog`.
/// Supports all eight note categories with category-specific input
/// forms:
///   * Issue           → wizard launcher + dropdown
///   * Feeding         → volume / pH / EC / NPK / product / amendments
///   * Watering        → volume / pH / runoff pH
///   * IPM             → product / target / method / dilution
///   * Training        → technique dropdown
///   * Transplant      → new pot size picker
///   * Measurement     → height in cm
///   * Observation /
///     Milestone /
///     Other           → no extra fields
///
/// Plus universal photo + voice-note + tag attachment editors.
abstract final class AddNoteSheet {
  AddNoteSheet._();

  static Future<void> show(
    BuildContext context, {
    required GrowRepository repo,
    required Plant plant,
    String prefillContent = '',
    NoteCategory prefillCategory = NoteCategory.observation,
  }) {
    final contentCtrl = TextEditingController(text: prefillContent);
    NoteCategory selectedCat = prefillCategory;
    String selectedIssue = 'Mold';
    String selectedTrainingTechnique = 'LST';
    final photoPaths = <String>[];
    // F7 — voice-note attachments.  Same storage pattern as photoPaths.
    final audioPaths = <String>[];
    // F8 — free-form tags.
    final tags = <String>[];

    // Feeding fields
    final waterVolCtrl = TextEditingController();
    final phInCtrl = TextEditingController();
    final ecCtrl = TextEditingController();
    final nCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    final kCtrl = TextEditingController();
    final productCtrl = TextEditingController();
    final amendmentsCtrl = TextEditingController();

    // Watering fields
    final wVolCtrl = TextEditingController();
    final wPhCtrl = TextEditingController();
    final runoffCtrl = TextEditingController();

    // IPM fields
    final ipmProductCtrl = TextEditingController();
    final pestCtrl = TextEditingController();
    String ipmMethod = 'spray';
    final dilutionCtrl = TextEditingController();

    // Measurement fields
    final heightCtrl = TextEditingController();

    // Transplant fields
    double? newPotSize;

    // Bug fix (v3 follow-up): same _dependents.isEmpty race that
    // hit the FAB Add Plant / Add Space flows also fires here when
    // a note has photos attached.  Root cause is identical: the
    // Save handler used to call `repo.addNote(...)` BEFORE
    // `Navigator.pop`, so the synchronous notifyListeners triggered
    // a parent PlantDetailScreen rebuild while the modal route was
    // still in the element tree.
    //
    // Fix: build the entity (and optional transplant plant patch),
    // pass them through Navigator.pop's result as a record, persist
    // in the .then() callback -- which fires only AFTER the route
    // is fully popped from the tree.
    return showModalBottomSheet<({PlantNote note, Plant? plantPatch})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AppSheet(
          title: 'Add Note',
          subtitle: plant.name,
          icon: Icons.note_add_rounded,
          iconColor: AppColors.growing,
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
                          color:
                              isSel ? Colors.white : ctx.colTextMuted)),
                  selected: isSel,
                  onSelected: (_) => ss(() => selectedCat = cat),
                  backgroundColor: ctx.colSurface3,
                  selectedColor: col,
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Issue fields ──────────────────────
            if (selectedCat == NoteCategory.issue) ...[
              DropdownButtonFormField<String>(
                initialValue: selectedIssue,
                dropdownColor: ctx.colSurface2,
                decoration: const InputDecoration(labelText: 'Issue Type'),
                items: _issues
                    .map((i) => DropdownMenuItem(
                          value: i,
                          child: Text(i,
                              style:
                                  TextStyle(color: ctx.colTextPrimary)),
                        ))
                    .toList(),
                onChanged: (v) => ss(() => selectedIssue = v!),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.search_rounded,
                      color: AppColors.ipmColor, size: 16),
                  label: Text('Identify with Wizard',
                      style: AppTypography.labelLarge(ctx)
                          .copyWith(color: AppColors.ipmColor)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.ipmColor, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: () async {
                    final result = await DeficiencyWizardSheet.show(ctx);
                    if (result != null) {
                      ss(() {
                        selectedIssue = result.issueName;
                        if (contentCtrl.text.trim().isEmpty) {
                          contentCtrl.text = result.content;
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ── Feeding form ──────────────────────
            if (selectedCat == NoteCategory.feeding) ...[
              const _MiniLabel(text: 'Feeding Log (optional fields)'),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                Expanded(
                    child: _MiniField(
                        ctrl: waterVolCtrl,
                        label: 'Volume (L)',
                        keyboard: TextInputType.number)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _MiniField(
                        ctrl: productCtrl,
                        label: 'Product',
                        keyboard: TextInputType.text)),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                Expanded(
                    child: _MiniField(
                        ctrl: phInCtrl,
                        label: 'pH In',
                        keyboard: TextInputType.number)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _MiniField(
                        ctrl: ecCtrl,
                        label: 'EC',
                        keyboard: TextInputType.number)),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                Expanded(
                    child: _MiniField(
                        ctrl: nCtrl,
                        label: 'N',
                        keyboard: TextInputType.number)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _MiniField(
                        ctrl: pCtrl,
                        label: 'P',
                        keyboard: TextInputType.number)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _MiniField(
                        ctrl: kCtrl,
                        label: 'K',
                        keyboard: TextInputType.number)),
              ]),
              const SizedBox(height: AppSpacing.xs),
              _MiniField(
                  ctrl: amendmentsCtrl,
                  label: 'Amendments / notes',
                  keyboard: TextInputType.text),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ── Watering form ─────────────────────
            if (selectedCat == NoteCategory.watering) ...[
              const _MiniLabel(text: 'Watering Log (optional fields)'),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                Expanded(
                    child: _MiniField(
                        ctrl: wVolCtrl,
                        label: 'Volume (L)',
                        keyboard: TextInputType.number)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _MiniField(
                        ctrl: wPhCtrl,
                        label: 'pH In',
                        keyboard: TextInputType.number)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _MiniField(
                        ctrl: runoffCtrl,
                        label: 'Runoff pH',
                        keyboard: TextInputType.number)),
              ]),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ── IPM form ──────────────────────────
            if (selectedCat == NoteCategory.ipm) ...[
              const _MiniLabel(text: 'IPM Log (optional fields)'),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                Expanded(
                    child: _MiniField(
                        ctrl: ipmProductCtrl,
                        label: 'Product',
                        keyboard: TextInputType.text)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _MiniField(
                        ctrl: pestCtrl,
                        label: 'Target pest',
                        keyboard: TextInputType.text)),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: ipmMethod,
                    dropdownColor: ctx.colSurface2,
                    decoration: const InputDecoration(labelText: 'Method'),
                    items: const [
                      DropdownMenuItem(value: 'spray', child: Text('Spray')),
                      DropdownMenuItem(
                          value: 'drench', child: Text('Drench')),
                      DropdownMenuItem(
                          value: 'foliar', child: Text('Foliar')),
                    ],
                    onChanged: (v) => ss(() => ipmMethod = v!),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _MiniField(
                        ctrl: dilutionCtrl,
                        label: 'Dilution ratio',
                        keyboard: TextInputType.number)),
              ]),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ── Training form ─────────────────────
            if (selectedCat == NoteCategory.training) ...[
              const _MiniLabel(text: 'Training Technique'),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: selectedTrainingTechnique,
                dropdownColor: ctx.colSurface2,
                decoration: const InputDecoration(labelText: 'Technique'),
                items: [
                  'LST',
                  'Topping',
                  'FIMming',
                  'Defoliation',
                  'Super Cropping',
                  'SCROG',
                  'Tying / Staking',
                  'Other',
                ]
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t,
                              style:
                                  TextStyle(color: ctx.colTextPrimary)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    ss(() => selectedTrainingTechnique = v!),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ── Transplant form ───────────────────
            if (selectedCat == NoteCategory.transplant) ...[
              const _MiniLabel(text: 'New pot size'),
              const SizedBox(height: AppSpacing.xs),
              if (plant.potSizeLitres != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    'Current: ${potLabel(plant.potSizeLitres!)}',
                    style: AppTypography.bodySmall(ctx)
                        .copyWith(color: ctx.colTextMuted),
                  ),
                ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: {
                  1.0: '1 L',
                  3.0: '3 L',
                  5.0: '5 L',
                  10.0: '10 L',
                  15.0: '15 L',
                  20.0: '20 L',
                  25.0: '25 L+',
                }.entries.map((e) {
                  final sel = newPotSize == e.key;
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: sel,
                    onSelected: (_) =>
                        ss(() => newPotSize = sel ? null : e.key),
                    selectedColor: AppColors.growing,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: sel ? Colors.black : ctx.colTextSecondary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ── Measurement form ──────────────────
            if (selectedCat == NoteCategory.measurement) ...[
              const _MiniLabel(text: 'Height measurement'),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: heightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: ctx.colTextPrimary),
                decoration: const InputDecoration(
                  labelText: 'Plant height (cm)',
                  hintText: '45.0',
                  suffixText: 'cm',
                  prefixIcon: Icon(Icons.straighten_rounded, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ── Note text ─────────────────────────
            TextField(
              controller: contentCtrl,
              maxLines: 3,
              autofocus: prefillContent.isEmpty,
              style: TextStyle(color: ctx.colTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Write your observation…',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Photos ────────────────────────────
            PhotoAttachmentPicker(
              photoPaths: photoPaths,
              onPhotoAdded: (p) => ss(() => photoPaths.add(p)),
              onPhotoRemoved: (p) => ss(() => photoPaths.remove(p)),
              onPhotoReplaced: (old, neu) => ss(() {
                final idx = photoPaths.indexOf(old);
                if (idx != -1) photoPaths[idx] = neu;
              }),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── F7 — Voice notes ──────────────────
            VoiceNoteAttachment(
              audioPaths: audioPaths,
              onAudioAdded: (f) => ss(() => audioPaths.add(f)),
              onAudioRemoved: (f) => ss(() => audioPaths.remove(f)),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── F8 — Tags ─────────────────────────
            TagEditor(
              tags: tags,
              onTagsChanged: (next) => ss(() {
                tags
                  ..clear()
                  ..addAll(next);
              }),
              suggestions: allKnownTags(repo),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Save ──────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.growing,
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
                  final heightValue = double.tryParse(heightCtrl.text);
                  // Validation policy (per user feedback): only the
                  // free-form Observation category requires the content
                  // field to be filled in.  Every other category exists
                  // to capture *data* (watering volume, feeding EC,
                  // training technique, etc.), so the observation note
                  // is a nice-to-have rather than a barrier to logging.
                  //
                  // When the content field is empty for a non-observation
                  // category, we auto-fill it with a category-appropriate
                  // one-liner so the note still reads sensibly on the
                  // timeline and in search.  Measurement + Transplant
                  // also keep their existing per-field requirements
                  // (height value / new pot size) because those *are*
                  // the data the category was designed to capture.
                  final trimmedContent = contentCtrl.text.trim();
                  if (selectedCat == NoteCategory.measurement) {
                    if (heightValue == null) return;
                    if (trimmedContent.isEmpty) {
                      contentCtrl.text =
                          'Height: ${heightValue.toStringAsFixed(1)} cm';
                    }
                  } else if (selectedCat == NoteCategory.transplant) {
                    if (newPotSize == null) return;
                    if (trimmedContent.isEmpty) {
                      contentCtrl.text =
                          'Transplanted to ${potLabel(newPotSize!)} pot';
                    }
                  } else if (selectedCat == NoteCategory.observation) {
                    // Observation is the *only* category that gates on
                    // a non-empty note.
                    if (trimmedContent.isEmpty) return;
                  } else if (trimmedContent.isEmpty) {
                    // Auto-summary for the data-driven categories so
                    // the timeline never shows a blank row.
                    contentCtrl.text = _autoSummary(
                      selectedCat,
                      issueName: selectedIssue,
                      trainingTechnique: selectedTrainingTechnique,
                      wateringVolume: double.tryParse(wVolCtrl.text),
                      feedingProduct: productCtrl.text.trim(),
                      feedingVolume: double.tryParse(waterVolCtrl.text),
                      ipmProduct: ipmProductCtrl.text.trim(),
                      ipmTarget: pestCtrl.text.trim(),
                    );
                  }

                  FeedingDetails? feeding;
                  if (selectedCat == NoteCategory.feeding) {
                    feeding = FeedingDetails(
                      waterVolumeLitres:
                          double.tryParse(waterVolCtrl.text),
                      phIn: double.tryParse(phInCtrl.text),
                      ecIn: double.tryParse(ecCtrl.text),
                      nitrogen: double.tryParse(nCtrl.text),
                      phosphorus: double.tryParse(pCtrl.text),
                      potassium: double.tryParse(kCtrl.text),
                      productName: productCtrl.text.trim().isEmpty
                          ? null
                          : productCtrl.text.trim(),
                      amendments: amendmentsCtrl.text.trim().isEmpty
                          ? null
                          : amendmentsCtrl.text.trim(),
                    );
                  }

                  WateringDetails? watering;
                  if (selectedCat == NoteCategory.watering) {
                    watering = WateringDetails(
                      volumeLitres: double.tryParse(wVolCtrl.text),
                      phIn: double.tryParse(wPhCtrl.text),
                      runoffPh: double.tryParse(runoffCtrl.text),
                    );
                  }

                  IpmDetails? ipm;
                  if (selectedCat == NoteCategory.ipm) {
                    ipm = IpmDetails(
                      product: ipmProductCtrl.text.trim().isEmpty
                          ? null
                          : ipmProductCtrl.text.trim(),
                      targetPest: pestCtrl.text.trim().isEmpty
                          ? null
                          : pestCtrl.text.trim(),
                      method: ipmMethod,
                      dilutionRatio: double.tryParse(dilutionCtrl.text),
                    );
                  }

                  // Bug fix (see top of show()): build entities,
                  // pop with them as the result, persist in .then().
                  final note = PlantNote(
                    id: repo.newId(),
                    plantId: plant.id,
                    createdAt: DateTime.now(),
                    content: contentCtrl.text.trim(),
                    category: selectedCat,
                    issueName: selectedCat == NoteCategory.issue
                        ? selectedIssue
                        : selectedCat == NoteCategory.training
                            ? selectedTrainingTechnique
                            : null,
                    photoUrls: List.from(photoPaths),
                    feedingDetails: feeding,
                    wateringDetails: watering,
                    ipmDetails: ipm,
                    heightCm: double.tryParse(heightCtrl.text),
                    newPotSizeLitres: selectedCat == NoteCategory.transplant
                        ? newPotSize
                        : null,
                    audioUrls: List.from(audioPaths),
                    tags: List.from(tags),
                  );
                  // Transplant: keep the plant's current pot size in sync.
                  Plant? plantPatch;
                  if (selectedCat == NoteCategory.transplant &&
                      newPotSize != null) {
                    plantPatch =
                        plant.copyWith(potSizeLitres: newPotSize);
                  }
                  Navigator.pop(ctx, (note: note, plantPatch: plantPatch));
                },
                child: const Text('Save Note'),
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
    ).then((result) {
      // Bug fix v6 (true root cause, confirmed by crash log):
      // disposing TextEditingControllers synchronously inside
      // .then() races with FocusManager's pending focus-blur
      // microtask.  When the modal's TextField loses focus during
      // keyboard takedown, EditableTextState._handleFocusChanged
      // fires AFTER .then() and tries to clearComposing() on a
      // controller we just disposed -- the resulting assertion
      // cascaded into _dependents.isEmpty on the Overlay.
      //
      // Defer dispose by 500 ms so the focus blur + keyboard
      // dismissal + platform-channel acks all complete first.
      Future.delayed(const Duration(milliseconds: 500), () {
        contentCtrl.dispose();
        waterVolCtrl.dispose();
        phInCtrl.dispose();
        ecCtrl.dispose();
        nCtrl.dispose();
        pCtrl.dispose();
        kCtrl.dispose();
        productCtrl.dispose();
        amendmentsCtrl.dispose();
        wVolCtrl.dispose();
        wPhCtrl.dispose();
        runoffCtrl.dispose();
        ipmProductCtrl.dispose();
        pestCtrl.dispose();
        dilutionCtrl.dispose();
        heightCtrl.dispose();
      });
      if (result == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        repo.addNote(result.note);
        if (result.plantPatch != null) {
          repo.updatePlant(result.plantPatch!);
        }
      });
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal compact form helpers
// ─────────────────────────────────────────────────────────────────────────────

/// One-line summary used when the user saves a non-observation note
/// without typing into the content field.  Keeps the timeline / search
/// preview readable even though the data lives in the structured
/// detail blobs (FeedingDetails / WateringDetails / IpmDetails).
String _autoSummary(
  NoteCategory category, {
  required String issueName,
  required String trainingTechnique,
  double? wateringVolume,
  String feedingProduct = '',
  double? feedingVolume,
  String ipmProduct = '',
  String ipmTarget = '',
}) {
  switch (category) {
    case NoteCategory.watering:
      if (wateringVolume != null && wateringVolume > 0) {
        return 'Watered · ${wateringVolume.toStringAsFixed(1)} L';
      }
      return 'Watered';
    case NoteCategory.feeding:
      final bits = <String>[
        'Fed',
        if (feedingProduct.isNotEmpty) feedingProduct,
        if (feedingVolume != null && feedingVolume > 0)
          '${feedingVolume.toStringAsFixed(1)} L',
      ];
      return bits.join(' · ');
    case NoteCategory.ipm:
      final bits = <String>[
        'IPM',
        if (ipmProduct.isNotEmpty) ipmProduct,
        if (ipmTarget.isNotEmpty) 'vs $ipmTarget',
      ];
      return bits.join(' · ');
    case NoteCategory.training:
      return trainingTechnique;
    case NoteCategory.issue:
      return 'Issue: $issueName';
    case NoteCategory.milestone:
      return 'Milestone';
    case NoteCategory.other:
      return 'Note';
    // Measurement / Transplant have their own auto-fills handled at
    // the call site and so never reach this switch.  Observation
    // doesn't auto-fill at all (it's required).
    case NoteCategory.measurement:
    case NoteCategory.transplant:
    case NoteCategory.observation:
      return '';
  }
}

/// Section-label text used above each category-specific form group.
/// Promoted to a widget so it can be `const`'d at most call sites.
class _MiniLabel extends StatelessWidget {
  final String text;
  const _MiniLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTypography.bodySmall(context)
          .copyWith(color: context.colTextMuted));
}

/// Compact single-line input used inside the per-category form rows
/// (Feeding / Watering / IPM / Training).  Dense, fixed-height,
/// surface-3 fill so multiple fields fit comfortably in a Row.
class _MiniField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType keyboard;

  const _MiniField({
    required this.ctrl,
    required this.label,
    required this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: TextStyle(color: context.colTextPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
        filled: true,
        fillColor: context.colSurface3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
