import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/strain_library.dart';
import '../l10n/app_localizations.dart';
import '../models/harvest_log.dart';
import '../models/strain.dart';
import '../repository/grow_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/terpene_colors.dart';
import '../widgets/app_toast.dart';
import '../widgets/empty_state.dart';
import '../widgets/empty_state_art.dart';
import '../widgets/strain_preview_sheet.dart';
import 'strain_detail_screen.dart';

// ── Top-level terpene list (most common across the full library) ──────────────

const _kTopTerpenes = [
  'myrcene',
  'caryophyllene',
  'limonene',
  'linalool',
  'terpinolene',
  'pinene',
  'ocimene',
  'humulene',
];

// P2.5 — Terpene colour map moved to `lib/theme/terpene_colors.dart`
// as the single source of truth.  Was previously duplicated here and
// in strain_detail_screen.dart + widgets/strain_preview_sheet.dart.

class StrainLibraryScreen extends StatefulWidget {
  const StrainLibraryScreen({super.key});

  @override
  State<StrainLibraryScreen> createState() => _StrainLibraryScreenState();
}

class _StrainLibraryScreenState extends State<StrainLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // ── Catalog filter state ──────────────────────────────────────────────────

  String _catalogSearch   = '';
  String _catalogTypeFilter = 'All'; // All | Indica | Sativa | Hybrid | Auto | Landrace
  // Advanced filters
  String _sortBy          = 'name';  // 'name' | 'thc' | 'flowerTime'
  String _terpeneFilter   = '';      // '' = any
  String _feedingFilter   = '';      // '' = any
  String _thcFilter       = '';      // '' | '<20' | '20-25' | '25+'
  bool   _richDataOnly    = false;
  bool   _showAdvFilters  = false;

  static const _typeFilters = [
    'All',
    'Indica',
    'Sativa',
    'Hybrid',
    'Auto',
    'Landrace',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    // P1.1 — Guard with indexIsChanging so the screen rebuilds only
    // when the user lands on a new tab, not on every frame of the
    // swipe-tween animation.  TabController.addListener fires for the
    // entire animation arc (60-120 ticks per swipe); without the
    // guard, the whole strain grid (~150 cards) rebuilt every frame.
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Computed filter count (excludes sort) ─────────────────────────────────

  int get _activeFilterCount {
    var n = 0;
    if (_terpeneFilter.isNotEmpty) n++;
    if (_feedingFilter.isNotEmpty) n++;
    if (_thcFilter.isNotEmpty) n++;
    if (_richDataOnly) n++;
    return n;
  }

  bool get _hasActiveFilters =>
      _activeFilterCount > 0 || _sortBy != 'name';

  void _clearAdvancedFilters() => setState(() {
        _terpeneFilter  = '';
        _feedingFilter  = '';
        _thcFilter      = '';
        _richDataOnly   = false;
        _sortBy         = 'name';
      });

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _typeColor(String type) {
    switch (type) {
      case 'Indica':  return AppColors.curing;
      case 'Sativa':  return AppColors.harvested;
      default:        return AppColors.growing;
    }
  }

  bool _matchesThcFilter(BuiltInStrain s) {
    final max = s.thcPctMax;
    if (max == null) return false;
    return switch (_thcFilter) {
      '<20'   => max < 20,
      '20-25' => max >= 20 && max <= 25,
      '25+'   => max > 25,
      _       => true,
    };
  }

  List<BuiltInStrain> _filteredCatalog() {
    final q = _catalogSearch.toLowerCase();
    var results = kStrainLibrary.where((s) {
      final matchesSearch = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          (s.lineage?.toLowerCase().contains(q) ?? false) ||
          (s.breeder?.toLowerCase().contains(q) ?? false);
      // Filter buckets:
      //   * All           → no type filter applied
      //   * Auto          → only autoflowers (any indica/sativa/hybrid)
      //   * Landrace      → only landraces (any indica/sativa/hybrid)
      //   * Indica/Sativa/Hybrid → photoperiods of that type only
      final matchesType = _catalogTypeFilter == 'All' ||
          (_catalogTypeFilter == 'Auto' && s.isAutoflower) ||
          (_catalogTypeFilter == 'Landrace' && s.isLandrace) ||
          (!s.isAutoflower && s.type == _catalogTypeFilter);
      final matchesTerpene =
          _terpeneFilter.isEmpty || s.terpenes.contains(_terpeneFilter);
      final matchesFeeding =
          _feedingFilter.isEmpty || s.feedingIntensity == _feedingFilter;
      final matchesThc =
          _thcFilter.isEmpty || _matchesThcFilter(s);
      final matchesRichData = !_richDataOnly || s.vegTargets != null;
      return matchesSearch &&
          matchesType &&
          matchesTerpene &&
          matchesFeeding &&
          matchesThc &&
          matchesRichData;
    }).toList();

    switch (_sortBy) {
      case 'thc':
        results.sort(
            (a, b) => (b.thcPctMax ?? -1).compareTo(a.thcPctMax ?? -1));
      case 'flowerTime':
        results.sort((a, b) => a.flowerDays.compareTo(b.flowerDays));
      default:
        results.sort((a, b) => a.name.compareTo(b.name));
    }
    return results;
  }

  bool _isSaved(GrowRepository repo, BuiltInStrain built) =>
      repo.strains
          .any((s) => s.name.toLowerCase() == built.name.toLowerCase());

  void _saveStrain(
      BuildContext context, GrowRepository repo, BuiltInStrain built) {
    if (_isSaved(repo, built)) return;
    repo.addStrain(Strain(
      id: repo.newId(),
      name: built.name,
      genetics: built.lineage ?? '',
      type: built.type,
      isAutoflower: built.isAutoflower,
      breeder: built.breeder,
      expectedFlowerDays: built.flowerDays,
      flowerWeeksMin: built.flowerWeeksMin,
      flowerWeeksMax: built.flowerWeeksMax,
      stretchFactor: built.stretchFactor,
      heightCmMin: built.heightCmMin,
      heightCmMax: built.heightCmMax,
      yieldGPerM2Min: built.yieldGPerM2Min,
      yieldGPerM2Max: built.yieldGPerM2Max,
      vegTargets: built.vegTargets,
      earlyFlowerTargets: built.earlyFlowerTargets,
      lateFlowerTargets: built.lateFlowerTargets,
      feedingIntensity: built.feedingIntensity,
      phMin: built.phMin,
      phMax: built.phMax,
      ecVegMin: built.ecVegMin,
      ecVegMax: built.ecVegMax,
      ecFlowerMin: built.ecFlowerMin,
      ecFlowerMax: built.ecFlowerMax,
      recommendedTraining: built.training,
      thcPctMin: built.thcPctMin,
      thcPctMax: built.thcPctMax,
      cbdPctMin: built.cbdPctMin,
      cbdPctMax: built.cbdPctMax,
      terpenes: built.terpenes,
      cureWeeksMin: built.cureWeeksMin,
      cureWeeksMax: built.cureWeeksMax,
      createdAt: DateTime.now(),
    ));
    AppToast.show(context, '${built.name} saved to My Library');
  }

  // ── Add custom strain dialog ──────────────────────────────────────────────

  void _showAddStrainDialog(BuildContext context, GrowRepository repo) {
    final nameCtrl      = TextEditingController();
    final geneticsCtrl  = TextEditingController();
    final flowerDaysCtrl = TextEditingController();
    final yieldCtrl     = TextEditingController();
    final notesCtrl     = TextEditingController();
    String selectedType = 'Hybrid';
    bool isAutoflower   = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.pagePadding,
            right: AppSpacing.pagePadding,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: context.colBorderFaint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.science_rounded,
                        color: AppColors.secondary, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text('Add Strain',
                      style: AppTypography.headlineMedium(context)),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _field(context, nameCtrl, 'Strain Name *'),
                const SizedBox(height: AppSpacing.sm),
                _field(context, geneticsCtrl, 'Genetics (e.g. OG Kush x Haze)'),
                const SizedBox(height: AppSpacing.sm),
                Text('Type', style: AppTypography.bodySmall(context)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  children: ['Indica', 'Sativa', 'Hybrid'].map((t) {
                    final selected = selectedType == t;
                    final color = _typeColor(t);
                    return ChoiceChip(
                      label: Text(t),
                      selected: selected,
                      onSelected: (_) => ss(() => selectedType = t),
                      selectedColor: color,
                      labelStyle: TextStyle(
                        color: selected ? Colors.black : context.colTextSecondary,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Switch(
                    value: isAutoflower,
                    onChanged: (v) => ss(() => isAutoflower = v),
                    activeThumbColor: AppColors.drying,
                    activeTrackColor: AppColors.drying.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Autoflower',
                      style: AppTypography.bodyMedium(context)),
                ]),
                const SizedBox(height: AppSpacing.xs),
                _field(
                  context, flowerDaysCtrl,
                  isAutoflower ? 'Seed-to-harvest days' : 'Expected flower days',
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.sm),
                _field(context, yieldCtrl, 'Expected Yield % (optional)',
                    keyboard: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: AppSpacing.sm),
                _field(context, notesCtrl, 'Notes (optional)', maxLines: 3),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      repo.addStrain(Strain(
                        id: repo.newId(),
                        name: nameCtrl.text.trim(),
                        genetics: geneticsCtrl.text.trim(),
                        type: selectedType,
                        isAutoflower: isAutoflower,
                        expectedFlowerDays:
                            int.tryParse(flowerDaysCtrl.text),
                        expectedYieldPercent:
                            double.tryParse(yieldCtrl.text),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                        createdAt: DateTime.now(),
                      ));
                      Navigator.pop(ctx);
                    },
                    child: Text('Add Strain',
                        style: AppTypography.labelLarge(context)
                            .copyWith(color: Colors.black, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      geneticsCtrl.dispose();
      flowerDaysCtrl.dispose();
      yieldCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  Widget _field(
    BuildContext context,
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: TextStyle(color: context.colTextPrimary),
      decoration: InputDecoration(labelText: label),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text('🧬 Strain Library',
            style: AppTypography.headlineLarge(context)
                .copyWith(color: AppColors.primary)),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'My Library'),
            Tab(text: 'Catalog'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: null,
          indicatorColor: AppColors.primary,
        ),
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              heroTag: 'strain_library_fab',
              onPressed: () => _showAddStrainDialog(context, repo),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              elevation: 0,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).strainsEmptyAddAction,
                  style: AppTypography.labelLarge(context)
                      .copyWith(color: Colors.black)),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _MyLibraryTab(
            repo: repo,
            typeColor: _typeColor,
            onAddStrain: () => _showAddStrainDialog(context, repo),
          ),
          _CatalogTab(
            repo: repo,
            search: _catalogSearch,
            typeFilter: _catalogTypeFilter,
            typeFilters: _typeFilters,
            filteredStrains: _filteredCatalog(),
            totalCount: kStrainLibrary.length,
            typeColor: _typeColor,
            isSaved: _isSaved,
            onSave: _saveStrain,
            onSearchChanged: (v) => setState(() => _catalogSearch = v),
            onTypeFilter: (v) => setState(() => _catalogTypeFilter = v),
            // Advanced filter state
            sortBy: _sortBy,
            terpeneFilter: _terpeneFilter,
            feedingFilter: _feedingFilter,
            thcFilter: _thcFilter,
            richDataOnly: _richDataOnly,
            showAdvFilters: _showAdvFilters,
            activeFilterCount: _activeFilterCount,
            hasActiveFilters: _hasActiveFilters,
            onSortChanged: (v) => setState(() => _sortBy = v),
            onTerpeneChanged: (v) => setState(() => _terpeneFilter = v),
            onFeedingChanged: (v) => setState(() => _feedingFilter = v),
            onThcChanged: (v) => setState(() => _thcFilter = v),
            onRichDataToggle: (v) => setState(() => _richDataOnly = v),
            onToggleAdvFilters: () =>
                setState(() => _showAdvFilters = !_showAdvFilters),
            onClearFilters: _clearAdvancedFilters,
          ),
        ],
      ),
    );
  }
}

// ── My Library tab ────────────────────────────────────────────────────────────

class _MyLibraryTab extends StatelessWidget {
  final GrowRepository repo;
  final Color Function(String) typeColor;
  /// UX3 — fired from the empty-state CTA so beginners who don't notice
  /// the FAB still have a clear "add your first strain" affordance.
  final VoidCallback onAddStrain;

  const _MyLibraryTab({
    required this.repo,
    required this.typeColor,
    required this.onAddStrain,
  });

  @override
  Widget build(BuildContext context) {
    final strains = [...repo.strains]..sort((a, b) => a.name.compareTo(b.name));

    final logByPlantId = <String, HarvestLog>{
      for (final log in repo.harvestLogs) log.plantId: log,
    };

    final Map<String, double> strainAvgYields = {};
    for (final strain in strains) {
      final weights = repo.plants
          .where((p) => p.strainId == strain.id)
          .map((p) => (logByPlantId[p.id]?.dryWeight ?? p.dryWeight))
          .whereType<double>()
          .toList();
      if (weights.isNotEmpty) {
        strainAvgYields[strain.id] =
            weights.reduce((a, b) => a + b) / weights.length;
      }
    }

    if (strains.isEmpty) {
      final l = AppLocalizations.of(context);
      return EmptyState(
        art: EmptyArt.strain,
        title: l.strainsEmptyTitle,
        subtitle: l.strainsEmptyBody,
        // UX3 — give beginners a primary CTA right in the empty state;
        // the FAB still works but isn't always obvious before any
        // content has loaded.
        actionLabel: l.strainsEmptyAddAction,
        onAction: onAddStrain,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      itemCount: strains.length,
      itemBuilder: (_, i) {
        final strain = strains[i];
        final color = typeColor(strain.type);
        final plantCount =
            repo.plants.where((p) => p.strainId == strain.id).length;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StrainDetailScreen(strain: strain),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colSurface1,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(Icons.science_rounded, color: color, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strain.name,
                          style: AppTypography.labelLarge(context)),
                      if (strain.genetics.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(strain.genetics,
                            style: AppTypography.bodySmall(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: 6,
                        children: [
                          _chip(context, strain.type, color),
                          if (strain.isAutoflower)
                            _chip(context, 'Auto', AppColors.drying),
                          if (strain.flowerTimeLabel != 'Unknown')
                            _chip(context, strain.flowerTimeLabel,
                                context.colTextMuted),
                          if (plantCount > 0)
                            _chip(
                              context,
                              '$plantCount plant${plantCount == 1 ? '' : 's'}',
                              AppColors.growing,
                            ),
                          if (strainAvgYields.containsKey(strain.id))
                            _chip(
                              context,
                              'Avg ${strainAvgYields[strain.id]!.toStringAsFixed(1)}g',
                              AppColors.harvested,
                            ),
                          if (strain.thcLabel != null)
                            _chip(context, 'THC ${strain.thcLabel!}',
                                AppColors.secondary),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: context.colTextMuted, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(label,
          style: AppTypography.labelSmall(context).copyWith(color: color)),
    );
  }
}

// ── Catalog tab ───────────────────────────────────────────────────────────────

class _CatalogTab extends StatelessWidget {
  final GrowRepository repo;
  final String search;
  final String typeFilter;
  final List<String> typeFilters;
  final List<BuiltInStrain> filteredStrains;
  final int totalCount;
  final Color Function(String) typeColor;
  final bool Function(GrowRepository, BuiltInStrain) isSaved;
  final void Function(BuildContext, GrowRepository, BuiltInStrain) onSave;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onTypeFilter;

  // Advanced filter state
  final String sortBy;
  final String terpeneFilter;
  final String feedingFilter;
  final String thcFilter;
  final bool richDataOnly;
  final bool showAdvFilters;
  final int activeFilterCount;
  final bool hasActiveFilters;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onTerpeneChanged;
  final ValueChanged<String> onFeedingChanged;
  final ValueChanged<String> onThcChanged;
  final ValueChanged<bool> onRichDataToggle;
  final VoidCallback onToggleAdvFilters;
  final VoidCallback onClearFilters;

  const _CatalogTab({
    required this.repo,
    required this.search,
    required this.typeFilter,
    required this.typeFilters,
    required this.filteredStrains,
    required this.totalCount,
    required this.typeColor,
    required this.isSaved,
    required this.onSave,
    required this.onSearchChanged,
    required this.onTypeFilter,
    required this.sortBy,
    required this.terpeneFilter,
    required this.feedingFilter,
    required this.thcFilter,
    required this.richDataOnly,
    required this.showAdvFilters,
    required this.activeFilterCount,
    required this.hasActiveFilters,
    required this.onSortChanged,
    required this.onTerpeneChanged,
    required this.onFeedingChanged,
    required this.onThcChanged,
    required this.onRichDataToggle,
    required this.onToggleAdvFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header: search + type chips + advanced toggle ─────────────────────
        Container(
          color: context.colSurface2,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.sm,
            AppSpacing.pagePadding,
            AppSpacing.sm,
          ),
          child: Column(
            children: [
              // Search row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: onSearchChanged,
                      style: TextStyle(color: context.colTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search $totalCount strains…',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: context.colSurface3,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Filters toggle button
                  GestureDetector(
                    onTap: onToggleAdvFilters,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: showAdvFilters || hasActiveFilters
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : context.colSurface3,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: showAdvFilters || hasActiveFilters
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : context.colBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: showAdvFilters || hasActiveFilters
                                ? AppColors.primary
                                : context.colTextMuted,
                          ),
                          if (activeFilterCount > 0) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$activeFilterCount',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Type filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: typeFilters.map((f) {
                    final selected = typeFilter == f;
                    final color = f == 'All'
                        ? AppColors.primary
                        : f == 'Auto'
                            ? AppColors.drying
                            : typeColor(f);
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: FilterChip(
                        label: Text(f),
                        selected: selected,
                        onSelected: (_) => onTypeFilter(f),
                        selectedColor: color.withValues(alpha: 0.18),
                        checkmarkColor: color,
                        labelStyle: AppTypography.labelSmall(context).copyWith(
                          color: selected ? color : context.colTextSecondary,
                        ),
                        side: BorderSide(
                          color: selected
                              ? color.withValues(alpha: 0.5)
                              : context.colBorder,
                        ),
                        backgroundColor: context.colSurface1,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Advanced filter panel (collapsible) ─────────────────────────
              if (showAdvFilters) ...[
                const SizedBox(height: AppSpacing.sm),
                _AdvancedFilterPanel(
                  sortBy: sortBy,
                  terpeneFilter: terpeneFilter,
                  feedingFilter: feedingFilter,
                  thcFilter: thcFilter,
                  richDataOnly: richDataOnly,
                  hasActiveFilters: hasActiveFilters,
                  onSortChanged: onSortChanged,
                  onTerpeneChanged: onTerpeneChanged,
                  onFeedingChanged: onFeedingChanged,
                  onThcChanged: onThcChanged,
                  onRichDataToggle: onRichDataToggle,
                  onClearFilters: onClearFilters,
                ),
              ],
            ],
          ),
        ),

        // ── Strain list ───────────────────────────────────────────────────────
        Expanded(
          child: filteredStrains.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 48, color: context.colTextMuted),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                          AppLocalizations.of(context).strainsFilteredEmpty,
                          style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton(
                        onPressed: onClearFilters,
                        child: Text(
                            AppLocalizations.of(context).strainsClearFilters),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding,
                    AppSpacing.sm,
                    AppSpacing.pagePadding,
                    AppSpacing.pagePadding,
                  ),
                  itemCount: filteredStrains.length,
                  itemBuilder: (_, i) =>
                      _catalogTile(context, filteredStrains[i]),
                ),
        ),
      ],
    );
  }

  Widget _catalogTile(BuildContext context, BuiltInStrain strain) {
    final color = typeColor(strain.type);
    final saved = isSaved(repo, strain);
    final hasRich = strain.vegTargets != null;

    // Render the flowering window in *days* across the board for
    // consistency.  Some catalog entries only carry the week range
    // (`flowerWeeksMin/Max`), in which case we multiply by 7 — but the
    // unit stays "d" everywhere so users aren't toggling between
    // wks/days mentally as they scroll the catalog.
    final daysLabel = strain.isAutoflower
        ? '~${strain.flowerDays}d seed→harvest'
        : (strain.flowerWeeksMin != null &&
                strain.flowerWeeksMax != null)
            ? '${strain.flowerWeeksMin! * 7}–${strain.flowerWeeksMax! * 7}d flower'
            : '~${strain.flowerDays}d flower';

    final thcLabel = strain.thcPctMin != null && strain.thcPctMax != null
        ? 'THC ${strain.thcPctMin!.toStringAsFixed(0)}–${strain.thcPctMax!.toStringAsFixed(0)}%'
        : null;

    return GestureDetector(
      onTap: () => StrainPreviewSheet.show(
        context,
        strain,
        isSaved: saved,
        onSave: saved ? null : () => onSave(context, repo, strain),
      ),
      onLongPress: () => StrainPreviewSheet.show(
        context,
        strain,
        isSaved: saved,
        onSave: saved ? null : () => onSave(context, repo, strain),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: saved
                ? AppColors.growing.withValues(alpha: 0.4)
                : color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            // Icon + rich-data dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(Icons.science_rounded,
                      color: color, size: 20),
                ),
                if (hasRich)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.colSurface1, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),

            // Name + badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strain.name,
                      style: AppTypography.labelLarge(context)),
                  if (strain.breeder != null) ...[
                    const SizedBox(height: 1),
                    Text(strain.breeder!,
                        style: AppTypography.bodySmall(context).copyWith(
                            color: context.colTextMuted, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: AppSpacing.xxs),
                  Wrap(
                    spacing: 5,
                    runSpacing: 3,
                    children: [
                      _badge(context, strain.type, color),
                      if (strain.isAutoflower)
                        _badge(context, 'Auto', AppColors.drying),
                      _badge(context, daysLabel, context.colTextMuted),
                      if (thcLabel != null)
                        _badge(context, thcLabel, AppColors.secondary),
                    ],
                  ),
                ],
              ),
            ),

            // Save button
            const SizedBox(width: AppSpacing.sm),
            saved
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.growing.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded,
                            color: AppColors.growing, size: 14),
                        const SizedBox(width: AppSpacing.xxs),
                        Text('Saved',
                            style: AppTypography.labelSmall(context)
                                .copyWith(color: AppColors.growing)),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: () => onSave(context, repo, strain),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull),
                        border: Border.all(
                          color:
                              AppColors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              color: AppColors.primary, size: 14),
                          const SizedBox(width: AppSpacing.xxs),
                          Text('Save',
                              style: AppTypography.labelSmall(context)
                                  .copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(label,
          style: AppTypography.labelSmall(context)
              .copyWith(color: color, fontSize: 10)),
    );
  }
}

// ── Advanced filter panel ─────────────────────────────────────────────────────

class _AdvancedFilterPanel extends StatelessWidget {
  final String sortBy;
  final String terpeneFilter;
  final String feedingFilter;
  final String thcFilter;
  final bool richDataOnly;
  final bool hasActiveFilters;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onTerpeneChanged;
  final ValueChanged<String> onFeedingChanged;
  final ValueChanged<String> onThcChanged;
  final ValueChanged<bool> onRichDataToggle;
  final VoidCallback onClearFilters;

  const _AdvancedFilterPanel({
    required this.sortBy,
    required this.terpeneFilter,
    required this.feedingFilter,
    required this.thcFilter,
    required this.richDataOnly,
    required this.hasActiveFilters,
    required this.onSortChanged,
    required this.onTerpeneChanged,
    required this.onFeedingChanged,
    required this.onThcChanged,
    required this.onRichDataToggle,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colSurface3,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.colBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sort ──────────────────────────────────────────────────────────
          _filterLabel(context, 'Sort by'),
          const SizedBox(height: AppSpacing.xxs),
          _chipRow(context, {
            'name': 'A–Z',
            'thc': 'THC% ↓',
            'flowerTime': 'Flower Time ↑',
          }, sortBy, onSortChanged, AppColors.primary),
          const SizedBox(height: AppSpacing.sm),

          // ── THC% ──────────────────────────────────────────────────────────
          _filterLabel(context, 'THC%'),
          const SizedBox(height: AppSpacing.xxs),
          _chipRow(context, {
            '': 'Any',
            '<20': '< 20%',
            '20-25': '20–25%',
            '25+': '25%+',
          }, thcFilter, onThcChanged, AppColors.secondary),
          const SizedBox(height: AppSpacing.sm),

          // ── Feeding ───────────────────────────────────────────────────────
          _filterLabel(context, 'Feeding'),
          const SizedBox(height: AppSpacing.xxs),
          _chipRow(context, {
            '': 'Any',
            'light': 'Light',
            'medium': 'Medium',
            'heavy': 'Heavy',
          }, feedingFilter, onFeedingChanged, AppColors.growing),
          const SizedBox(height: AppSpacing.sm),

          // ── Terpene ───────────────────────────────────────────────────────
          _filterLabel(context, 'Terpene'),
          const SizedBox(height: AppSpacing.xxs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _terpChip(context, '', 'Any', null),
                ...(_kTopTerpenes.map(
                  (t) => _terpChip(
                    context,
                    t,
                    t[0].toUpperCase() + t.substring(1),
                    kTerpeneColors[t],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Rich data only toggle ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Full grow data only',
                        style: AppTypography.labelSmall(context)
                            .copyWith(fontSize: 11)),
                    Text('Show strains with phase targets & feeding',
                        style: AppTypography.bodySmall(context).copyWith(
                            color: context.colTextMuted, fontSize: 9)),
                  ],
                ),
              ),
              Switch(
                value: richDataOnly,
                onChanged: onRichDataToggle,
                activeTrackColor:
                    AppColors.primary.withValues(alpha: 0.4),
                activeThumbColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),

          // ── Clear ─────────────────────────────────────────────────────────
          if (hasActiveFilters) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onClearFilters,
                child: Text(
                  'Clear all filters',
                  style: AppTypography.labelSmall(context).copyWith(
                      color: AppColors.primary, fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterLabel(BuildContext context, String label) {
    return Text(label,
        style: AppTypography.labelSmall(context)
            .copyWith(color: context.colTextMuted, fontSize: 10));
  }

  Widget _chipRow(
    BuildContext context,
    Map<String, String> options,
    String current,
    ValueChanged<String> onChanged,
    Color activeColor,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.entries.map((e) {
          final selected = e.key == current;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withValues(alpha: 0.15)
                      : context.colSurface1,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: selected
                        ? activeColor.withValues(alpha: 0.5)
                        : context.colBorder,
                  ),
                ),
                child: Text(e.value,
                    style: AppTypography.labelSmall(context).copyWith(
                        color: selected ? activeColor : context.colTextSecondary,
                        fontSize: 11)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _terpChip(
      BuildContext context, String value, String label, Color? color) {
    final selected = terpeneFilter == value;
    final c = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => onTerpeneChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.15) : context.colSurface1,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color:
                  selected ? c.withValues(alpha: 0.5) : context.colBorder,
            ),
          ),
          child: Text(label,
              style: AppTypography.labelSmall(context).copyWith(
                  color: selected ? c : context.colTextSecondary,
                  fontSize: 11)),
        ),
      ),
    );
  }
}
