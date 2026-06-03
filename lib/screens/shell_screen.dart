import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/environment_log.dart';
import '../models/grow_space.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../repository/grow_repository.dart';
import '../services/notification_service.dart';
import '../services/telemetry_consent_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/temp_format.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/demo_banner.dart';
import '../widgets/strain_autocomplete_field.dart';
import '../widgets/telemetry_consent_sheet.dart';
import 'dashboard_screen.dart';
import 'expense_tracker_screen.dart';
import 'harvest_archive_screen.dart';
import 'home_screen.dart';
import 'strain_library_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with TickerProviderStateMixin {
  int _index = 0;
  bool _fabOpen = false;
  late AnimationController _fabController;
  late Animation<double> _fabScale;
  late Animation<double> _fabRotate;

  // Cached repo reference — used to guard against duplicate listener registration
  // in didChangeDependencies (which can be called multiple times).
  GrowRepository? _repo;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fabScale =
        CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack);
    _fabRotate = Tween<double>(begin: 0, end: 0.375).animate(
        CurvedAnimation(parent: _fabController, curve: Curves.easeInOut));

    // SR6 — first-launch telemetry consent prompt.  Defer to the
    // post-frame callback so the shell has fully mounted before we
    // push a bottom sheet on top.  The service flag is checked on
    // every shell open, but the sheet only fires when the user has
    // never been asked — once they grant or decline (or dismiss), the
    // state persists and this branch becomes a no-op forever after.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final consent = context.read<TelemetryConsentService>();
      if (consent.isInitialised && !consent.hasBeenAsked) {
        TelemetryConsentSheet.show(context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guard: only (re-)register the listener when the repo instance changes.
    // didChangeDependencies can be called multiple times (e.g. on InheritedWidget
    // updates) so naively calling addListener here would stack up duplicates.
    final repo = context.read<GrowRepository>();
    if (repo != _repo) {
      _repo?.storageError.removeListener(_onStorageError);
      _repo = repo;
      _repo!.storageError.addListener(_onStorageError);
    }
  }

  void _onStorageError() {
    final msg = _repo?.storageError.value;
    if (msg == null || !mounted) return;
    AppToast.show(
      context,
      msg,
      type: ToastType.error,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    // Use cached _repo so dispose() doesn't need BuildContext (which is unsafe
    // to call context.read on after the widget is removed from the tree).
    _repo?.storageError.removeListener(_onStorageError);
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() => _fabOpen = !_fabOpen);
    _fabOpen ? _fabController.forward() : _fabController.reverse();
  }

  void _closeFab() {
    if (_fabOpen) {
      setState(() => _fabOpen = false);
      _fabController.reverse();
    }
  }

  List<_FabAction> _fabActions(GrowRepository repo) {
    final l = AppLocalizations.of(context);
    return [
        _FabAction(
          icon: Icons.add_business,
          label: l.fabAddSpace,
          color: AppColors.primary,
          onTap: () {
            _closeFab();
            _showAddSpaceSheet(context, repo);
          },
        ),
        _FabAction(
          icon: Icons.eco,
          label: l.fabAddPlant,
          color: AppColors.growing,
          onTap: () {
            _closeFab();
            if (repo.growSpaces.isEmpty) {
              AppToast.show(
                context,
                'Create a grow space first',
                type: ToastType.info,
              );
              return;
            }
            _showAddPlantSheet(context, repo);
          },
        ),
        _FabAction(
          icon: Icons.thermostat,
          label: l.fabLogEnvironment,
          color: AppColors.drying,
          onTap: () {
            _closeFab();
            _showBatchEnvSheet(context, repo);
          },
        ),
        _FabAction(
          icon: Icons.note_add,
          label: l.fabQuickNote,
          color: AppColors.secondary,
          onTap: () {
            _closeFab();
            _showQuickNoteSheet(context, repo);
          },
        ),
        _FabAction(
          icon: Icons.receipt_long_rounded,
          label: 'Log Expense',
          color: AppColors.harvested,
          onTap: () {
            _closeFab();
            AddExpenseSheet.show(context);
          },
        ),
      ];
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();

    return GestureDetector(
      onTap: _closeFab,
      child: Scaffold(
        body: Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: KultivarApp.isDemoModeNotifier,
              builder: (_, isDemo, __) =>
                  isDemo ? const DemoBanner() : const SizedBox.shrink(),
            ),
            Expanded(
              // Bug fix v3: PR #12 dropped Settings (6 -> 6 tabs) but
              // "Analytics" still wraps to two lines on S22.  Drop
              // Notes too (down to 5 tabs).  Notes is now reachable
              // via the pen icon in the Home AppBar.
              child: IndexedStack(
                index: _index,
                children: const [
                  HomeScreen(),
                  DashboardScreen(),
                  HarvestArchiveScreen(),
                  StrainLibraryScreen(),
                  ExpenseTrackerScreen(),
                ],
              ),
            ),
          ],
        ),

        // ── FAB hub ─────────────────────────
        // Hide the global FAB on tabs that have their own primary
        // action so the two buttons don't collide.  Costs (4) has its
        // own "Log Expense" CTA inside the screen; Strains (3)
        // intentionally doesn't need the add-anything hub.
        //
        // (Bug fix v3: re-indexed after Notes was dropped from the
        // bottom nav -- Strains 4->3, Costs 5->4.)
        floatingActionButton: (_index == 3 || _index == 4)
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ..._fabActions(repo).reversed.map((action) {
                    return ScaleTransition(
                      scale: _fabScale,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _fabOpen ? 1 : 0,
                              child: Container(
                                margin:
                                    const EdgeInsets.only(right: AppSpacing.sm),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colSurface2,
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSm),
                                  border: Border.all(color: context.colBorder),
                                ),
                                child: Text(action.label,
                                    style: AppTypography.labelLarge(context)
                                        .copyWith(
                                            color: context.colTextPrimary)),
                              ),
                            ),
                            FloatingActionButton.small(
                              heroTag: action.label,
                              backgroundColor: action.color,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              onPressed: () {
                                if (_fabOpen) action.onTap();
                              },
                              child: Icon(action.icon, size: 20),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  RotationTransition(
                    turns: _fabRotate,
                    child: FloatingActionButton(
                      heroTag: 'main_fab',
                      onPressed: _toggleFab,
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      child: const Icon(Icons.add, size: 28),
                    ),
                  ),
                ],
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        // ── Bottom nav ──────────────────────
        //
        // Settings is no longer a tab here -- it lives on the gear
        // icon in the Home AppBar instead (real-device fix v2).
        bottomNavigationBar: _BottomNav(
          index: _index,
          onTap: (i) {
            _closeFab();
            setState(() => _index = i);
          },
        ),
      ),
    );
  }

  // ── Action sheets ─────────────────────────────

  void _showAddSpaceSheet(BuildContext context, GrowRepository repo) {
    final nameCtrl = TextEditingController();
    String type = 'Indoor Tent';
    // Bug fix v3: PR #12 used Navigator.pop + addPostFrameCallback,
    // but the callback fires on the *next* frame (~16ms) while the
    // modal pop animation takes ~250ms (15 frames).  notifyListeners
    // still fired into the modal's still-live element tree and
    // triggered the _dependents.isEmpty assertion.
    //
    // The canonical Flutter pattern: pass the entity through
    // Navigator.pop's result, handle the mutation in the modal's
    // .then() callback.  That callback fires only AFTER the route
    // is fully popped and removed from the tree -- so there is no
    // overlap between the modal tear-down and the parent rebuild
    // caused by notifyListeners.
    showModalBottomSheet<GrowSpace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AppSheet(
          title: AppLocalizations.of(ctx).fabSheetAddSpaceTitle,
          subtitle: AppLocalizations.of(ctx).fabSheetAddSpaceSubtitle,
          icon: Icons.add_home_work_rounded,
          iconColor: AppColors.secondary,
          children: [
            _input(nameCtrl, 'Space Name *'),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Indoor Tent',
                'Flower Room',
                'Veg Room',
                'Greenhouse',
                'Outdoor',
                'Dry Room',
                'Other',
              ].map((t) {
                final sel = type == t;
                return ChoiceChip(
                  label: Text(t),
                  selected: sel,
                  onSelected: (_) => ss(() => type = t),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      color: sel ? Colors.black : context.colTextSecondary),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            _primaryButton(
              label: AppLocalizations.of(ctx).fabSheetAddSpaceCreate,
              onTap: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  GrowSpace(
                    id: repo.newId(),
                    name: nameCtrl.text.trim(),
                    type: type,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ).then((space) {
      // Bug fix v6 (true root cause -- confirmed by crash log):
      // disposing the TextEditingController synchronously inside
      // .then() races with FocusManager's pending focus-blur
      // microtask.  When the modal's TextField loses focus during
      // keyboard takedown, EditableTextState._handleFocusChanged
      // fires AFTER .then() and tries to clearComposing() on a
      // controller we already disposed -- the assertion that
      // followed cascaded into the _dependents.isEmpty crash on
      // the Overlay's next deactivation pass.
      //
      // Defer dispose by 500 ms so the focus blur + keyboard
      // dismissal + any platform-channel acks have all completed
      // before we tear the controller down.
      Future.delayed(const Duration(milliseconds: 500), nameCtrl.dispose);
      if (space == null) return;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => repo.addGrowSpace(space));
    });
  }

  void _showAddPlantSheet(BuildContext context, GrowRepository repo) {
    // Bug fix v3: pop-with-result pattern -- see _showAddSpaceSheet.
    final nameCtrl = TextEditingController();
    String spaceId = repo.growSpaces.first.id;
    String strainText = '';
    bool isClone = false;
    bool isAutoflower = false;
    DateTime startDate = DateTime.now();
    DateTime? targetHarvestDate;
    String? medium;
    String? lightType;
    double? potSizeLitres;
    String? motherPlantId;

    showModalBottomSheet<Plant>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AppSheet(
          title: AppLocalizations.of(ctx).fabSheetAddPlantTitle,
          subtitle: AppLocalizations.of(ctx).fabSheetAddPlantSubtitle,
          icon: Icons.eco_rounded,
          iconColor: AppColors.growing,
          children: [
            _input(nameCtrl, 'Plant Name *'),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: spaceId,
              dropdownColor: context.colSurface2,
              decoration: const InputDecoration(labelText: 'Grow Space'),
              items: repo.growSpaces
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name,
                            style:
                                TextStyle(color: context.colTextPrimary)),
                      ))
                  .toList(),
              onChanged: (v) => ss(() => spaceId = v!),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Strain autocomplete
            StrainAutocompleteField(
              onTextChanged: (v) => strainText = v,
              onStrainSelected: (strain) => ss(() {
                strainText = strain.name;
                isAutoflower = strain.isAutoflower;
                // Autos: auto-suggest harvest date from seed.
                // Photos: leave blank — veg length is unknown.
                if (strain.isAutoflower) {
                  targetHarvestDate =
                      startDate.add(Duration(days: strain.flowerDays));
                }
              }),
            ),

            const SizedBox(height: AppSpacing.sm),

// Autoflower / photoperiod
            Row(children: [
              Text('Genetics:', style: AppTypography.bodyMedium(context)),
              const SizedBox(width: AppSpacing.md),
              _toggleChip('Photoperiod', !isAutoflower, AppColors.growing,
                  () => ss(() => isAutoflower = false)),
              const SizedBox(width: AppSpacing.xs),
              _toggleChip('Autoflower', isAutoflower, AppColors.drying,
                  () => ss(() => isAutoflower = true)),
            ]),
            const SizedBox(height: AppSpacing.xs),

            // Clone / seed
            Row(children: [
              Text('Origin:', style: AppTypography.bodyMedium(context)),
              const SizedBox(width: AppSpacing.md),
              _toggleChip('🌱 Seed', !isClone, AppColors.growing,
                  () => ss(() { isClone = false; motherPlantId = null; })),
              const SizedBox(width: AppSpacing.xs),
              _toggleChip('🌿 Clone', isClone, AppColors.secondary,
                  () => ss(() => isClone = true)),
            ]),

            // Mother plant dropdown (only when clone is selected)
            if (isClone && repo.plants.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: motherPlantId,
                dropdownColor: context.colSurface2,
                decoration: const InputDecoration(
                  labelText: 'Mother Plant (optional)',
                  prefixIcon: Icon(Icons.account_tree_rounded, size: 18),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text('— No mother selected —',
                        style: TextStyle(color: context.colTextMuted)),
                  ),
                  ...repo.plants
                      .where((p) => p.status == PlantStatus.growing ||
                          p.status == PlantStatus.harvested)
                      .map((p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Text('${p.name} (${p.strain})',
                                style: TextStyle(
                                    color: context.colTextPrimary)),
                          )),
                ],
                onChanged: (v) => ss(() => motherPlantId = v),
              ),
            ],

            const SizedBox(height: AppSpacing.sm),

            // ── Medium ─────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Medium:',
                      style: AppTypography.bodyMedium(context)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: {
                      'soil': 'Soil',
                      'coco': 'Coco',
                      'hydro': 'Hydro',
                      'living_soil': 'Living Soil',
                      'other': 'Other',
                    }.entries.map((e) {
                      final sel = medium == e.key;
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: sel,
                        // Tap again to deselect.
                        onSelected: (_) =>
                            ss(() => medium = sel ? null : e.key),
                        selectedColor: AppColors.secondary,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: sel
                              ? Colors.white
                              : context.colTextSecondary,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Light type ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Light:',
                      style: AppTypography.bodyMedium(context)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: {
                      'led': 'LED',
                      'hps': 'HPS',
                      'cmh': 'CMH',
                      'fluorescent': 'Fluoro',
                      'outdoor': 'Outdoor',
                      'other': 'Other',
                    }.entries.map((e) {
                      final sel = lightType == e.key;
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: sel,
                        onSelected: (_) =>
                            ss(() => lightType = sel ? null : e.key),
                        selectedColor: AppColors.drying,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: sel
                              ? Colors.black
                              : context.colTextSecondary,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Pot size ────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child:
                      Text('Pot:', style: AppTypography.bodyMedium(context)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Wrap(
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
                      final sel = potSizeLitres == e.key;
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: sel,
                        onSelected: (_) =>
                            ss(() => potSizeLitres = sel ? null : e.key),
                        selectedColor: AppColors.growing,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: sel ? Colors.black : context.colTextSecondary,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: startDate,
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365 * 3)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) ss(() => startDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: context.colSurface3,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: context.colBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Start: ${startDate.toLocal().toString().split(' ')[0]}',
                      style: AppTypography.bodyMedium(context)
                          .copyWith(color: AppColors.primary),
                    ),
                    const Icon(Icons.calendar_today,
                        color: AppColors.primary, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now().add(const Duration(days: 70)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  ss(() => targetHarvestDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: context.colSurface3,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: context.colBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      targetHarvestDate != null
                          ? 'Target: ${targetHarvestDate!.toLocal().toString().split(' ')[0]}'
                          : 'Target harvest date (optional)',
                      style: AppTypography.bodyMedium(context).copyWith(
                        color: targetHarvestDate != null
                            ? AppColors.primary
                            : context.colTextMuted,
                      ),
                    ),
                    const Icon(Icons.calendar_today,
                        color: AppColors.primary, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _primaryButton(
              label: AppLocalizations.of(ctx).fabAddPlant,
              onTap: () {
                if (nameCtrl.text.trim().isEmpty) return;
                // Bug fix v3: see _showAddSpaceSheet for the canonical
                // pop-with-result pattern.
                final plant = Plant(
                  id: repo.newId(),
                  name: nameCtrl.text.trim(),
                  strain: strainText.trim().isEmpty
                      ? 'Unknown'
                      : strainText.trim(),
                  startDate: startDate,
                  targetHarvestDate: targetHarvestDate,
                  growSpaceId: spaceId,
                  isClone: isClone,
                  isAutoflower: isAutoflower,
                  medium: medium,
                  lightType: lightType,
                  potSizeLitres: potSizeLitres,
                  motherPlantId: isClone ? motherPlantId : null,
                );
                Navigator.pop(ctx, plant);
              },
            ),
          ],
        ),
      ),
    ).then((plant) {
      // Bug fix v6 -- see _showAddSpaceSheet.
      Future.delayed(const Duration(milliseconds: 500), nameCtrl.dispose);
      if (plant == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        repo.addPlant(plant);
        if (plant.targetHarvestDate != null &&
            KultivarApp.notifTargetHarvestEnabled.value) {
          unawaited(NotificationService().scheduleHarvestReminder(
            plantId: plant.id,
            plantName: plant.name,
            targetDate: plant.targetHarvestDate!,
          ));
        }
      });
    });
  }

  void _showBatchEnvSheet(BuildContext context, GrowRepository repo) {
    final tempCtrl = TextEditingController();
    final humCtrl = TextEditingController();
    // All spaces are pre-selected; user can deselect ones that are offline.
    final selectedIds =
        Set<String>.from(repo.growSpaces.map((s) => s.id));

    showModalBottomSheet<List<EnvironmentLog>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AppSheet(
          title: AppLocalizations.of(ctx).fabSheetLogEnvTitle,
          subtitle: AppLocalizations.of(ctx).fabSheetLogEnvSubtitle,
          icon: Icons.thermostat_rounded,
          iconColor: AppColors.water,
          children: [
            // ── Space checklist ───────────────────
            ...repo.growSpaces.map((space) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(space.name,
                      style: AppTypography.bodyMedium(ctx)),
                  value: selectedIds.contains(space.id),
                  activeColor: AppColors.primary,
                  onChanged: (v) => ss(() {
                    if (v == true) {
                      selectedIds.add(space.id);
                    } else {
                      selectedIds.remove(space.id);
                    }
                  }),
                )),
            const SizedBox(height: AppSpacing.md),

            _input(tempCtrl, tempUnitLabel,
                keyboard:
                    const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: AppSpacing.md),
            _input(humCtrl, 'Humidity (%)',
                keyboard:
                    const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: AppSpacing.lg),
            _primaryButton(
              label: 'Log to ${selectedIds.length} Space${selectedIds.length == 1 ? '' : 's'}',
              color: AppColors.drying,
              onTap: () {
                if (selectedIds.isEmpty) return;
                final rawTemp = double.tryParse(tempCtrl.text);
                final hum = double.tryParse(humCtrl.text);
                if (rawTemp == null && hum == null) return;
                // Bug fix v3: see _showAddSpaceSheet.  Build the
                // entire batch of logs up-front, pass them back as
                // the pop result, and persist after the modal is
                // fully gone.
                final now = DateTime.now();
                final storageTemp =
                    rawTemp != null ? toStorageTemp(rawTemp) : null;
                final logs = selectedIds
                    .map((spaceId) => EnvironmentLog(
                          id: repo.newId(),
                          growSpaceId: spaceId,
                          recordedAt: now,
                          temperature: storageTemp,
                          humidity: hum,
                        ))
                    .toList();
                Navigator.pop(ctx, logs);
              },
            ),
          ],
        ),
      ),
    ).then((logs) {
      // Bug fix v6 -- see _showAddSpaceSheet.
      Future.delayed(const Duration(milliseconds: 500), () {
        tempCtrl.dispose();
        humCtrl.dispose();
      });
      if (logs == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final log in logs) {
          repo.addEnvironmentLog(log);
        }
      });
    });
  }

  void _showQuickNoteSheet(BuildContext context, GrowRepository repo) {
    final contentCtrl = TextEditingController();
    String? plantId;
    NoteCategory category = NoteCategory.observation;

    showModalBottomSheet<PlantNote>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AppSheet(
          title: AppLocalizations.of(ctx).fabSheetQuickNoteTitle,
          subtitle: AppLocalizations.of(ctx).fabSheetQuickNoteSubtitle,
          icon: Icons.edit_note_rounded,
          iconColor: AppColors.primary,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: plantId,
              dropdownColor: context.colSurface2,
              decoration: const InputDecoration(labelText: 'Plant'),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text('— Select plant —',
                        style: TextStyle(color: context.colTextMuted))),
                ...repo.plants.where((p) => !p.isArchived).map((p) =>
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name,
                          style: TextStyle(color: context.colTextPrimary)),
                    )),
              ],
              onChanged: (v) => ss(() => plantId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: NoteCategory.values.map((c) {
                final sel = category == c;
                return FilterChip(
                  label: Text(c.name.toUpperCase(),
                      style: AppTypography.labelSmall(context).copyWith(
                          color: sel ? Colors.white : context.colTextMuted)),
                  selected: sel,
                  onSelected: (_) => ss(() => category = c),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              autofocus: true,
              style: TextStyle(color: context.colTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'What do you want to record?',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _primaryButton(
              label: AppLocalizations.of(ctx).fabSheetSaveNote,
              color: AppColors.secondary,
              onTap: () {
                if (plantId == null) {
                  AppToast.show(
                    ctx,
                    'Please select a plant first',
                    type: ToastType.info,
                  );
                  return;
                }
                if (contentCtrl.text.trim().isEmpty) {
                  AppToast.show(
                    ctx,
                    'Note cannot be empty',
                    type: ToastType.info,
                  );
                  return;
                }
                // Bug fix v3: see _showAddSpaceSheet.
                Navigator.pop(
                  ctx,
                  PlantNote(
                    id: repo.newId(),
                    plantId: plantId!,
                    createdAt: DateTime.now(),
                    content: contentCtrl.text.trim(),
                    category: category,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ).then((note) {
      // Bug fix v6 -- see _showAddSpaceSheet.
      Future.delayed(const Duration(milliseconds: 500), contentCtrl.dispose);
      if (note == null) return;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => repo.addNote(note));
    });
  }

  // ── Shared helpers ────────────────────────────

  Widget _input(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: TextStyle(color: context.colTextPrimary),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _toggleChip(
    String label,
    bool selected,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : context.colSurface3,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: selected ? color : context.colBorder),
        ),
        child: Text(label,
            style: AppTypography.labelLarge(context)
                .copyWith(color: selected ? color : context.colTextMuted)),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.primary,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label,
            style: AppTypography.labelLarge(context)
                .copyWith(color: Colors.black, fontSize: 15)),
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int index;
  final void Function(int) onTap;

  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // F11 — resolve once per build; cheaper than `.of(context)` per tab.
    final l = AppLocalizations.of(context);
    // Bug fix v3:  PR #12 dropped Settings (7 -> 6 tabs).  At 6 tabs
    // and ~60 dp per slot, "Analytics" (9 chars) still wraps to
    // "Analytic | s" on S22 because BottomNav uses padded font sizes.
    // Drop Notes too (down to 5 tabs at ~72 dp/slot) -- comfortably
    // accommodates the longest English label.  Notes is now reached
    // via the pen icon on the Home AppBar.
    //
    // Indices after this change:
    //   0 Home, 1 Analytics, 2 Archive, 3 Strains, 4 Costs.
    return Container(
      decoration: BoxDecoration(
        color: context.colSurface1,
        border: Border(top: BorderSide(color: context.colBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: _navItem(context, 0,
                    (c) => Icon(Icons.home_rounded, size: 22, color: c),
                    l.navHome),
              ),
              Expanded(
                child: _navItem(
                    context,
                    1,
                    (c) => FaIcon(FontAwesomeIcons.chartLine,
                        size: 19, color: c),
                    l.navAnalytics),
              ),
              Expanded(
                child: _navItem(
                    context,
                    2,
                    (c) => Icon(Icons.archive_rounded, size: 22, color: c),
                    l.navArchive),
              ),
              Expanded(
                child: _navItem(
                    context,
                    3,
                    (c) => Icon(Icons.science_rounded, size: 22, color: c),
                    l.navStrains),
              ),
              Expanded(
                child: _navItem(
                    context,
                    4,
                    (c) =>
                        Icon(Icons.receipt_long_rounded, size: 22, color: c),
                    l.navCosts),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int i,
    Widget Function(Color color) iconBuilder,
    String label,
  ) {
    final selected = i == index;
    final color = selected ? AppColors.primary : context.colTextMuted;
    return Semantics(
      // A9 — primary navigation tabs.  Role + selected state are
      // explicit so TalkBack/VoiceOver announces "Home tab, selected"
      // vs "Home tab" instead of just reading the bare label.
      // `container: true` boxes the icon + label so the row is one
      // focusable node rather than two.
      container: true,
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        // The inner Text duplicates the label we just declared on the
        // parent — exclude it so TalkBack doesn't announce it twice.
        child: GestureDetector(
          onTap: () => onTap(i),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconBuilder(color),
            const SizedBox(height: 3),
            Text(label,
                style: AppTypography.labelSmall(context).copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                )),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

// ── FAB action model ──────────────────────────────

class _FabAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FabAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
