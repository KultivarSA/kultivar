import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ── Public result ─────────────────────────────────────────────────────────────

class WizardResult {
  final String issueName;
  final String content;
  const WizardResult({required this.issueName, required this.content});
}

// ── Internal data model ───────────────────────────────────────────────────────

class _Diagnosis {
  final String name;
  final String description;
  final String fix;
  final Color color;
  final IconData icon;
  const _Diagnosis({
    required this.name,
    required this.description,
    required this.fix,
    required this.color,
    required this.icon,
  });

  String get noteContent => '$description Fix: $fix';
}

class _Location {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  const _Location(
      {required this.id,
      required this.label,
      required this.subtitle,
      required this.icon});
}

class _Symptom {
  final String label;
  final String locationId;
  final _Diagnosis diagnosis;
  const _Symptom(
      {required this.label,
      required this.locationId,
      required this.diagnosis});
}

// ── Diagnosis database ────────────────────────────────────────────────────────

const _nDef = _Diagnosis(
  name: 'Nitrogen Deficiency',
  description:
      'Lower/older leaves turn yellow and eventually drop. Yellowing progresses upward as deficiency worsens.',
  fix: 'Feed with a nitrogen-rich nutrient solution. Check pH (6.0–7.0 soil / 5.5–6.5 hydro).',
  color: AppColors.drying,
  icon: Icons.eco_rounded,
);
const _mgDef = _Diagnosis(
  name: 'Magnesium Deficiency',
  description:
      'Interveinal chlorosis on older leaves — veins stay green while tissue between them yellows.',
  fix: 'Foliar-spray Epsom salt (1 tsp/L) or add Cal-Mag to feed. Check pH.',
  color: AppColors.secondary,
  icon: Icons.circle_outlined,
);
const _pDef = _Diagnosis(
  name: 'Phosphorus Deficiency',
  description:
      'Purple or dark-red discolouration on leaf undersides and stems. Older leaves affected first.',
  fix: 'Use a phosphorus-boosting additive. Ensure root zone temperature > 15 °C. Lower pH to 6.0.',
  color: AppColors.danger,
  icon: Icons.warning_amber_rounded,
);
const _kDef = _Diagnosis(
  name: 'Potassium Deficiency',
  description:
      'Leaf edges and tips turn brown and crispy. Symptoms start on older leaves and work inward.',
  fix: 'Add potassium silicate or a bloom booster high in K. Flush then re-feed at correct pH.',
  color: AppColors.harvested,
  icon: Icons.local_fire_department_rounded,
);
const _caDef = _Diagnosis(
  name: 'Calcium Deficiency',
  description:
      'Brown spots and dead patches on new upper growth. Margins may curl slightly.',
  fix: 'Add Cal-Mag supplement. Raise pH slightly (6.2–6.8 in soil). Check watering frequency.',
  color: AppColors.info,
  icon: Icons.grain_rounded,
);
const _feDef = _Diagnosis(
  name: 'Iron Deficiency',
  description:
      'Bright yellow interveinal chlorosis on newest upper leaves; veins remain distinctly green.',
  fix: 'Lower pH to 6.0–6.5 to unlock iron. Add chelated iron or Cal-Mag. Check for root issues.',
  color: AppColors.drying,
  icon: Icons.circle_outlined,
);
const _sDef = _Diagnosis(
  name: 'Sulfur Deficiency',
  description: 'Uniform pale yellowing of newer leaves starting at the top of the plant.',
  fix: 'Add a sulfur-containing nutrient (e.g. magnesium sulfate / Epsom). Check pH 6.0–7.0.',
  color: AppColors.growing,
  icon: Icons.eco_rounded,
);
const _bDef = _Diagnosis(
  name: 'Boron / Zinc Deficiency',
  description: 'New growth is twisted, deformed, or unusually small. Tips may die back.',
  fix: 'Use a micro-nutrient supplement containing B and Zn. Flush first if over-watered.',
  color: AppColors.training,
  icon: Icons.rotate_left_rounded,
);
const _heatStress = _Diagnosis(
  name: 'Heat Stress',
  description: 'Upper leaves taco or cup upward, edges may show slight bleaching near the light.',
  fix: 'Increase light-to-canopy distance. Improve ventilation / lower room temp below 28 °C.',
  color: AppColors.danger,
  icon: Icons.wb_sunny_rounded,
);
const _nutBurn = _Diagnosis(
  name: 'Nutrient Burn',
  description: 'Brown, crispy tips on leaf margins — especially on upper and middle canopy.',
  fix: 'Flush with plain pH-adjusted water. Reduce nutrient concentration by 25–30%.',
  color: AppColors.harvested,
  icon: Icons.local_fire_department_rounded,
);
const _overWater = _Diagnosis(
  name: 'Overwatering',
  description: 'Leaves droop downward (claw), soil stays perpetually wet, possible yellowing.',
  fix: 'Allow soil to dry out between waterings (lift-test). Improve drainage.',
  color: AppColors.water,
  icon: Icons.water_drop_rounded,
);
const _rootRot = _Diagnosis(
  name: 'Root Rot',
  description:
      'Plant wilts even when soil is wet. Roots appear dark and slimy with a foul odour.',
  fix: 'Apply beneficial bacteria (Hydroguard / Great White). Improve drainage and O₂.',
  color: AppColors.danger,
  icon: Icons.warning_rounded,
);
const _spiderMites = _Diagnosis(
  name: 'Spider Mites',
  description: 'Tiny pale/yellow stippling (dots) on leaf surface; fine webbing under leaves.',
  fix: 'Apply neem oil or predatory mites. Increase humidity > 60%. Quarantine affected plants.',
  color: AppColors.ipmColor,
  icon: Icons.bug_report_rounded,
);
const _pm = _Diagnosis(
  name: 'Powdery Mildew',
  description: 'White powdery coating on leaf surfaces; spreads rapidly in humid, stagnant air.',
  fix: 'Spray potassium bicarbonate or diluted hydrogen peroxide. Improve airflow. Reduce humidity.',
  color: AppColors.textMuted,
  icon: Icons.cloud_outlined,
);
const _funGnats = _Diagnosis(
  name: 'Fungus Gnats',
  description: 'Small flies around topsoil; larvae damage roots causing wilting and slow growth.',
  fix: 'Apply Bacillus thuringiensis (BTi), sticky yellow traps. Let top soil dry out.',
  color: AppColors.ipmColor,
  icon: Icons.pest_control_rounded,
);

// ── Location definitions ──────────────────────────────────────────────────────

const _locations = [
  _Location(
    id: 'lower',
    label: 'Lower / older leaves',
    subtitle: 'Symptoms on the bottom of the plant',
    icon: Icons.arrow_downward_rounded,
  ),
  _Location(
    id: 'upper',
    label: 'Upper / newer leaves',
    subtitle: 'Symptoms on new growth near the top',
    icon: Icons.arrow_upward_rounded,
  ),
  _Location(
    id: 'edges',
    label: 'Leaf edges & tips',
    subtitle: 'Brown, crispy or curling margins',
    icon: Icons.crop_rounded,
  ),
  _Location(
    id: 'spots',
    label: 'Spots or patches',
    subtitle: 'Distinct spots, dots or powdery coating',
    icon: Icons.blur_on_rounded,
  ),
  _Location(
    id: 'whole',
    label: 'Whole plant / all leaves',
    subtitle: 'Drooping, wilting or widespread change',
    icon: Icons.nature_rounded,
  ),
];

// ── Symptom list ──────────────────────────────────────────────────────────────

const _symptoms = [
  // ── Lower leaves
  _Symptom(
    label: 'Yellowing overall',
    locationId: 'lower',
    diagnosis: _nDef,
  ),
  _Symptom(
    label: 'Yellow between veins, green veins stay',
    locationId: 'lower',
    diagnosis: _mgDef,
  ),
  _Symptom(
    label: 'Purple / dark-red undersides or stems',
    locationId: 'lower',
    diagnosis: _pDef,
  ),
  _Symptom(
    label: 'Brown patches or dead spots',
    locationId: 'lower',
    diagnosis: _kDef,
  ),
  // ── Upper leaves
  _Symptom(
    label: 'Yellow between veins (veins still green)',
    locationId: 'upper',
    diagnosis: _feDef,
  ),
  _Symptom(
    label: 'Uniform pale / light yellow',
    locationId: 'upper',
    diagnosis: _sDef,
  ),
  _Symptom(
    label: 'Brown spots or dead patches',
    locationId: 'upper',
    diagnosis: _caDef,
  ),
  _Symptom(
    label: 'Twisted, small or deformed leaves',
    locationId: 'upper',
    diagnosis: _bDef,
  ),
  _Symptom(
    label: 'Leaves curling upward (taco / cupping)',
    locationId: 'upper',
    diagnosis: _heatStress,
  ),
  // ── Edges
  _Symptom(
    label: 'Brown crispy tips',
    locationId: 'edges',
    diagnosis: _nutBurn,
  ),
  _Symptom(
    label: 'Brown or burnt margins (not just tips)',
    locationId: 'edges',
    diagnosis: _kDef,
  ),
  _Symptom(
    label: 'Edges curling down (claw)',
    locationId: 'edges',
    diagnosis: _overWater,
  ),
  // ── Spots
  _Symptom(
    label: 'White powdery coating',
    locationId: 'spots',
    diagnosis: _pm,
  ),
  _Symptom(
    label: 'Tiny yellow / white dots (stippling)',
    locationId: 'spots',
    diagnosis: _spiderMites,
  ),
  _Symptom(
    label: 'Brown or rust-coloured spots',
    locationId: 'spots',
    diagnosis: _caDef,
  ),
  // ── Whole plant
  _Symptom(
    label: 'Drooping / clawing despite wet soil',
    locationId: 'whole',
    diagnosis: _overWater,
  ),
  _Symptom(
    label: 'Wilting with dark / slimy roots',
    locationId: 'whole',
    diagnosis: _rootRot,
  ),
  _Symptom(
    label: 'Small flies around soil surface',
    locationId: 'whole',
    diagnosis: _funGnats,
  ),
  _Symptom(
    label: 'Pale / light green overall (all leaves)',
    locationId: 'whole',
    diagnosis: _nDef,
  ),
];

// ── Sheet widget ──────────────────────────────────────────────────────────────

/// 3-step wizard that guides the user to a diagnosis.
/// Pops with a [WizardResult] when the user taps "Use This Diagnosis",
/// or with `null` if cancelled.
class DeficiencyWizardSheet extends StatefulWidget {
  const DeficiencyWizardSheet({super.key});

  /// Convenience launcher — returns null if user dismissed without selecting.
  static Future<WizardResult?> show(BuildContext context) {
    return showModalBottomSheet<WizardResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DeficiencyWizardSheet(),
    );
  }

  @override
  State<DeficiencyWizardSheet> createState() => _DeficiencyWizardSheetState();
}

class _DeficiencyWizardSheetState extends State<DeficiencyWizardSheet> {
  final _pageCtrl = PageController();
  int _step = 0;

  _Location? _selectedLocation;
  _Symptom? _selectedSymptom;

  List<_Symptom> get _filteredSymptoms => _selectedLocation == null
      ? const []
      : _symptoms
          .where((s) => s.locationId == _selectedLocation!.id)
          .toList();

  void _goTo(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: Column(
        children: [
          // ── Drag handle ───────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: AppSpacing.md),
              decoration: BoxDecoration(
                color: context.colBorderFaint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── Header ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding, AppSpacing.md,
                AppSpacing.pagePadding, 0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.ipmColor.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.search_rounded,
                      color: AppColors.ipmColor, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Issue Identifier',
                          style: AppTypography.headlineMedium(context)),
                      Text('Step ${_step + 1} of 3',
                          style: AppTypography.bodySmall(context)
                              .copyWith(color: context.colTextMuted)),
                    ],
                  ),
                ),
                if (_step > 0)
                  TextButton.icon(
                    onPressed: () => _goTo(_step - 1),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 14),
                    label: const Text('Back'),
                    style: TextButton.styleFrom(
                        foregroundColor: context.colTextSecondary),
                  ),
              ],
            ),
          ),
          // ── Progress bar ──────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding,
                vertical: AppSpacing.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_step + 1) / 3,
                backgroundColor: context.colSurface3,
                color: AppColors.ipmColor,
                minHeight: 4,
              ),
            ),
          ),
          // ── Pages ─────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _LocationPage(
                  locations: _locations,
                  selected: _selectedLocation,
                  onSelect: (loc) {
                    setState(() {
                      _selectedLocation = loc;
                      _selectedSymptom = null;
                    });
                    _goTo(1);
                  },
                ),
                _SymptomPage(
                  symptoms: _filteredSymptoms,
                  selected: _selectedSymptom,
                  onSelect: (sym) {
                    setState(() => _selectedSymptom = sym);
                    _goTo(2);
                  },
                ),
                _DiagnosisPage(
                  diagnosis: _selectedSymptom?.diagnosis,
                  onUse: (result) => Navigator.pop(context, result),
                  onRetry: () => _goTo(0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 1 — Location ─────────────────────────────────────────────────────────

class _LocationPage extends StatelessWidget {
  final List<_Location> locations;
  final _Location? selected;
  final void Function(_Location) onSelect;

  const _LocationPage({
    required this.locations,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        Text(
          'Where are the symptoms?',
          style: AppTypography.headlineSmall(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Select the area of the plant showing signs.',
          style: AppTypography.bodySmall(context)
              .copyWith(color: context.colTextMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        ...locations.map(
          (loc) => _OptionCard(
            icon: loc.icon,
            title: loc.label,
            subtitle: loc.subtitle,
            selected: selected?.id == loc.id,
            color: AppColors.ipmColor,
            onTap: () => onSelect(loc),
          ),
        ),
      ],
    );
  }
}

// ── Page 2 — Symptom ──────────────────────────────────────────────────────────

class _SymptomPage extends StatelessWidget {
  final List<_Symptom> symptoms;
  final _Symptom? selected;
  final void Function(_Symptom) onSelect;

  const _SymptomPage({
    required this.symptoms,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        Text(
          'What do they look like?',
          style: AppTypography.headlineSmall(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pick the description that best matches.',
          style: AppTypography.bodySmall(context)
              .copyWith(color: context.colTextMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        if (symptoms.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text('No symptoms available for this location.',
                  style: AppTypography.bodyMedium(context)
                      .copyWith(color: context.colTextMuted),
                  textAlign: TextAlign.center),
            ),
          )
        else
          ...symptoms.map(
            (sym) => _OptionCard(
              icon: sym.diagnosis.icon,
              title: sym.label,
              subtitle: sym.diagnosis.name,
              selected: selected?.label == sym.label,
              color: sym.diagnosis.color,
              onTap: () => onSelect(sym),
            ),
          ),
      ],
    );
  }
}

// ── Page 3 — Diagnosis ────────────────────────────────────────────────────────

class _DiagnosisPage extends StatelessWidget {
  final _Diagnosis? diagnosis;
  final void Function(WizardResult) onUse;
  final VoidCallback onRetry;

  const _DiagnosisPage({
    required this.diagnosis,
    required this.onUse,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final d = diagnosis;
    if (d == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.help_outline_rounded, size: 48, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text('No diagnosis found.',
                  style: AppTypography.headlineSmall(context)),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: onRetry, child: const Text('Start Over')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Likely Diagnosis',
              style: AppTypography.headlineSmall(context)),
          const SizedBox(height: AppSpacing.md),

          // ── Diagnosis card ───────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: d.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: d.color.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: d.color.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(d.icon, color: d.color, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(d.name,
                          style: AppTypography.headlineMedium(context)
                              .copyWith(color: d.color)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('SYMPTOMS',
                    style: AppTypography.labelSmall(context)
                        .copyWith(color: context.colTextMuted, letterSpacing: 0.8)),
                const SizedBox(height: AppSpacing.xs),
                Text(d.description,
                    style: AppTypography.bodyMedium(context)
                        .copyWith(color: context.colTextPrimary)),
                const SizedBox(height: AppSpacing.md),
                Text('RECOMMENDED FIX',
                    style: AppTypography.labelSmall(context)
                        .copyWith(color: context.colTextMuted, letterSpacing: 0.8)),
                const SizedBox(height: AppSpacing.xs),
                Text(d.fix,
                    style: AppTypography.bodyMedium(context)
                        .copyWith(color: context.colTextSecondary)),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Use button ────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Use This Diagnosis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: d.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              onPressed: () => onUse(
                WizardResult(
                  issueName: d.name,
                  content: d.description,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Different Symptoms'),
              onPressed: onRetry,
              style: TextButton.styleFrom(
                  foregroundColor: context.colTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable option card ──────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : context.colSurface2,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected ? color : context.colBorderFaint,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (selected ? color : context.colTextMuted)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon,
                  color: selected ? color : context.colTextMuted, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.labelLarge(context).copyWith(
                          color: selected ? color : context.colTextPrimary)),
                  Text(subtitle,
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextMuted, fontSize: 11)),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: selected ? color : context.colTextMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
