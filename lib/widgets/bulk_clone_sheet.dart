import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/subscription_tier_config.dart';
import '../l10n/app_localizations.dart';
import '../models/grow_space.dart';
import '../models/plant.dart';
import '../repository/grow_repository.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_sheet.dart';
import 'app_toast.dart';
import 'pro_gate.dart';

/// F4 — Bulk-clone sheet.
///
/// Lets a grower take N cuttings from a mother in a single action.  Each
/// new plant is created with `isClone: true`, `motherPlantId: mother.id`
/// and (by default) the mother's medium / light / pot size copied across
/// so they appear correctly grouped in analytics.
///
/// Naming convention: `"{Mother} Clone {n}"`.  When the mother already
/// has existing clones, numbering picks up above the highest existing
/// index so the user never collides with a previous batch.
class BulkCloneSheet {
  BulkCloneSheet._();

  static Future<void> show(BuildContext context, {required Plant mother}) {
    // Bug fix: pop-with-result pattern -- see add_note_sheet.dart.
    // Capture repo before showing modal so we avoid context across
    // the async gap (only the toast uses context, guarded).
    final repo = context.read<GrowRepository>();
    return showModalBottomSheet<List<Plant>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BulkCloneSheetBody(mother: mother),
    ).then((clones) {
      if (clones == null || clones.isEmpty) return;
      // Bug fix v7 -- see batch_care_sheet.dart.
      Future.delayed(const Duration(milliseconds: 500), () {
        for (final clone in clones) {
          repo.addPlant(clone);
        }
        if (!context.mounted) return;
        AppToast.show(
          context,
          '${clones.length} clone${clones.length == 1 ? '' : 's'} '
              'created from ${mother.name}',
          type: ToastType.success,
        );
      });
    });
  }
}

class _BulkCloneSheetBody extends StatefulWidget {
  final Plant mother;
  const _BulkCloneSheetBody({required this.mother});

  @override
  State<_BulkCloneSheetBody> createState() => _BulkCloneSheetBodyState();
}

class _BulkCloneSheetBodyState extends State<_BulkCloneSheetBody> {
  int _count = 4;
  bool _copyAttributes = true;
  DateTime _startDate = DateTime.now();
  String? _spaceId;
  late int _startIndex;

  static const int _maxClones = 24;

  @override
  void initState() {
    super.initState();
    _spaceId = widget.mother.growSpaceId;
    _startIndex = _computeStartIndex(context);
  }

  /// Look at existing clones of this mother, parse trailing "Clone N"
  /// indexes from their names, and return the next free number.  Falls
  /// back to 1 when no existing clones match the convention.
  int _computeStartIndex(BuildContext context) {
    final repo = context.read<GrowRepository>();
    final pattern = RegExp(r'Clone\s+(\d+)\s*$');
    var highest = 0;
    for (final p in repo.plants) {
      if (p.motherPlantId != widget.mother.id) continue;
      final m = pattern.firstMatch(p.name);
      if (m == null) continue;
      final n = int.tryParse(m.group(1)!) ?? 0;
      if (n > highest) highest = n;
    }
    return highest + 1;
  }

  String _nameFor(int idx) => '${widget.mother.name} Clone $idx';

  // ── Build ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();
    final mediaQuery = MediaQuery.of(context);

    // Free-tier plant cap: clones are new plants, so the batch must fit
    // inside the remaining slots.  Watched (not read) so a purchase made
    // from the banner's paywall unlocks the button without reopening.
    final tier =
        context.select<SubscriptionService, SubscriptionTier>((s) => s.tier);
    final capBlocked =
        !FreeTierGate.canAddPlants(tier, repo.plants, count: _count);

    return AppSheet(
      title: 'Take Clones',
      subtitle:
          'Create multiple cuttings from ${widget.mother.name} in one step',
      icon: Icons.content_cut_rounded,
      iconColor: AppColors.training,
      children: [
        // ── Mother summary card ─────────────────
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.training.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border:
                Border.all(color: AppColors.training.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_tree_rounded,
                  size: 18, color: AppColors.training),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.mother.name,
                        style: AppTypography.labelLarge(context)),
                    Text(
                      'Mother · ${widget.mother.strain}',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextMuted),
                    ),
                  ],
                ),
              ),
              if (_startIndex > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.growing.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    'Next: #$_startIndex',
                    style: AppTypography.labelSmall(context)
                        .copyWith(color: AppColors.growing),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Count stepper ─────────────────────────
        Row(
          children: [
            Text('How many clones?',
                style: AppTypography.labelLarge(context)),
            const Spacer(),
            _StepperButton(
              icon: Icons.remove_rounded,
              enabled: _count > 1,
              onTap: () => setState(() => _count = (_count - 1).clamp(1, _maxClones)),
            ),
            Container(
              width: 44,
              alignment: Alignment.center,
              child: Text(
                '$_count',
                style: AppTypography.headlineMedium(context),
              ),
            ),
            _StepperButton(
              icon: Icons.add_rounded,
              enabled: _count < _maxClones,
              onTap: () => setState(() => _count = (_count + 1).clamp(1, _maxClones)),
            ),
          ],
        ),

        // Quick-pick chips for common counts.
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [2, 4, 6, 8, 12].map((n) {
              final sel = n == _count;
              return ChoiceChip(
                label: Text('$n'),
                selected: sel,
                onSelected: (_) => setState(() => _count = n),
                selectedColor: AppColors.training,
                labelStyle: TextStyle(
                  color: sel ? Colors.white : context.colTextSecondary,
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Naming preview ────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: context.colSurface3,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: context.colBorderFaint),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Will create:',
                style: AppTypography.labelSmall(context)
                    .copyWith(color: context.colTextMuted),
              ),
              const SizedBox(height: 2),
              Text(
                _previewNames(),
                style: AppTypography.bodySmall(context),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Space picker ─────────────────────────
        DropdownButtonFormField<String>(
          initialValue: _spaceId,
          dropdownColor: context.colSurface2,
          decoration: const InputDecoration(labelText: 'Grow Space'),
          items: repo.growSpaces
              .map((s) => DropdownMenuItem<String>(
                    value: s.id,
                    child: Text(s.name,
                        style: TextStyle(color: context.colTextPrimary)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _spaceId = v),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Copy mother attributes toggle ────────
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.training,
          title: Text('Copy from mother',
              style: AppTypography.labelLarge(context)),
          subtitle: Text(
            'Medium, light type, pot size, autoflower flag',
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextMuted),
          ),
          value: _copyAttributes,
          onChanged: (v) => setState(() => _copyAttributes = v),
        ),

        // ── Start date picker ────────────────────
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (picked != null) setState(() => _startDate = picked);
          },
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colSurface3,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: context.colBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Start date: '
                  '${_startDate.toLocal().toString().split(' ')[0]}',
                  style: AppTypography.bodyMedium(context)
                      .copyWith(color: AppColors.primary),
                ),
                const Icon(Icons.calendar_today,
                    color: AppColors.primary, size: 16),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        if (capBlocked) ...[
          ProLimitBanner(
            message: AppLocalizations.of(context)
                .freeTierCloneBatchMessage(FreeTierLimits.maxActivePlants),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.content_cut_rounded, size: 18),
            label: Text('Create $_count clone${_count == 1 ? '' : 's'}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.training,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _spaceId == null || capBlocked
                ? null
                : () => _create(context, repo),
          ),
        ),

        // Bottom padding so the keyboard-aware sheet leaves the button
        // comfortably above the home indicator on iOS.
        SizedBox(height: mediaQuery.viewPadding.bottom),
      ],
    );
  }

  String _previewNames() {
    if (_count == 1) return _nameFor(_startIndex);
    if (_count <= 3) {
      return List.generate(_count, (i) => _nameFor(_startIndex + i))
          .join(' · ');
    }
    return '${_nameFor(_startIndex)}  …  '
        '${_nameFor(_startIndex + _count - 1)}';
  }

  void _create(BuildContext context, GrowRepository repo) {
    final m = widget.mother;
    final spaceId = _spaceId;
    if (spaceId == null) return;
    // Re-check the free-tier cap at commit time — the button is disabled
    // when blocked, but plants could have been added while the sheet sat
    // open (e.g. another device restoring a backup).
    final tier = context.read<SubscriptionService>().tier;
    if (!FreeTierGate.canAddPlants(tier, repo.plants, count: _count)) {
      showPaywall(context);
      return;
    }
    // Guard: the user could have picked a stale space ID if the space was
    // deleted in another tab while the sheet was open.
    final spaceExists = repo.growSpaces.any((s) => s.id == spaceId);
    if (!spaceExists) {
      AppToast.show(context, 'Grow space no longer exists',
          type: ToastType.error);
      return;
    }

    // Bug fix: build the clones, pop with them as result, persist
    // in show().then() so notifyListeners doesn't fire mid-pop.
    final clones = [
      for (var i = 0; i < _count; i++)
        Plant(
          id: repo.newId(),
          name: _nameFor(_startIndex + i),
          strain: m.strain,
          strainId: m.strainId,
          startDate: _startDate,
          growSpaceId: spaceId,
          isClone: true,
          isAutoflower: _copyAttributes ? m.isAutoflower : false,
          medium: _copyAttributes ? m.medium : null,
          lightType: _copyAttributes ? m.lightType : null,
          potSizeLitres: _copyAttributes ? m.potSizeLitres : null,
          phenotypeTag: m.phenotypeTag,
          motherPlantId: m.id,
          // Care reminders default off — the user can enable per-plant
          // afterwards if they want.  Inheriting them would create N×3
          // scheduled notifications instantly which is rarely desired.
        ),
    ];

    Navigator.pop(context, clones);
  }
}

// ── Small stepper button ───────────────────────────

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled ? AppColors.training : context.colTextMuted;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.training.withValues(alpha: 0.12)
              : context.colSurface3,
          shape: BoxShape.circle,
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: c),
      ),
    );
  }
}

// Pulled in to silence the unused-import warning if/when this file is
// trimmed; GrowSpace import is consumed by the dropdown's value type.
// ignore: unused_element
GrowSpace? _kSilenceUnused;
