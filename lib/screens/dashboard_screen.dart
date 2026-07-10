import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../config/subscription_tier_config.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/grow_space.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../models/time_window.dart';
import '../repository/grow_repository.dart';
import '../services/analytics_service.dart';
import '../services/hive_service.dart';
import '../services/insight_notification_bridge.dart';
import '../services/local_crash_log.dart';
import '../services/subscription_service.dart';
import '../services/ui_preferences_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/analytics_time_series.dart';
import '../utils/confidence_band_engine.dart';
import '../utils/csv_export_service.dart';
import '../utils/forecast_engine.dart';
import '../utils/insight_engine.dart';
import '../utils/issue_analytics.dart';
import '../utils/quality_analytics.dart';
import '../utils/rolling_average.dart';
import '../utils/temp_format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/insights_feed.dart';
import '../widgets/multi_line_chart.dart';
import '../widgets/pro_gate.dart';
import '../widgets/time_window_selector.dart';
import 'calendar_screen.dart';
import 'cross_grow_comparison_screen.dart';
import 'environment_log_screen.dart';
import 'plant_list_screen.dart';
import 'plant_notes_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── State ───────────────────────────────────

  // Bug fix: in demo mode the seeded run history spans ~140 days
  // (6 completed harvests dated 28, 50, 72, 95, 115, 140 days ago).
  // The previous default of `last30` only contained the most recent
  // harvest so the dry-weight trend chart looked empty -- a problem
  // both for first-impressions and for Play Store screenshots.
  // Open the window to "all" while demo is active; real users on a
  // fresh install still get the sensible 30-day default below.
  TimeWindow _window = KultivarApp.isDemoModeNotifier.value
      ? TimeWindow.all
      : TimeWindow.last30;
  bool _smoothingEnabled = true;
  bool _showConfidenceBands = true;

  final Set<String> _hiddenSeries = {};

  SeriesPoint? _hoverPoint;
  ConfidenceBand? _hoverBand;

  // ── Lifecycle ───────────────────────────────

  @override
  void initState() {
    super.initState();

    UiPreferencesService.loadShowBands().then((value) {
      if (!mounted) return;
      setState(() => _showConfidenceBands = value);
    });

    // Listen for demo-mode flips that happen AFTER initState.
    // Critical: ShellScreen uses an IndexedStack which eagerly
    // builds all 5 tabs at app start, so DashboardScreen's
    // initState runs BEFORE the user taps "Explore with sample
    // data".  Without this listener, the screenshot-friendly
    // `all` window default in the field initializer never fires
    // because `isDemoModeNotifier.value` was still false when
    // the field was set.
    KultivarApp.isDemoModeNotifier.addListener(_onDemoModeChanged);

    // Only honour the saved time-window preference outside demo mode.
    // In demo mode we always force `all` so the seeded history is
    // visible -- screenshot-friendly and avoids a confusing empty
    // chart on first preview.
    if (!KultivarApp.isDemoModeNotifier.value) {
      UiPreferencesService.loadTimeWindow().then((value) {
        if (!mounted) return;
        setState(() => _window = value);
      });
    }

    _loadHiddenSeries();
  }

  @override
  void dispose() {
    KultivarApp.isDemoModeNotifier.removeListener(_onDemoModeChanged);
    super.dispose();
  }

  // Hash key of the last chart inputs we logged.  Avoids appending
  // a fresh diagnostic dump on every rebuild while the user is still
  // looking at the same chart configuration.
  String? _lastLoggedChartKey;

  void _maybeLogChartSnapshot(
    TimeWindow window,
    List<SeriesPoint> raw,
    List<SeriesPoint> display,
  ) {
    final key = '${window.name}|$_smoothingEnabled|'
        '$_showConfidenceBands|${_hiddenSeries.toList().join(",")}|'
        '${raw.length}|${display.length}';
    if (key == _lastLoggedChartKey) return;
    _lastLoggedChartKey = key;
    LocalCrashLog.info(
      'dashboard.chart',
      'window=${window.name} '
          'smoothing=$_smoothingEnabled bands=$_showConfidenceBands '
          'hidden=${_hiddenSeries.join(",")} '
          'demo=${KultivarApp.isDemoModeNotifier.value}\n'
          'raw.count=${raw.length} '
          'raw.values=[${raw.take(20).map((p) => '${p.series}:${p.value.toStringAsFixed(1)}@${p.date.toIso8601String().substring(0, 10)}').join(", ")}]\n'
          'display.count=${display.length} '
          'display.values=[${display.take(20).map((p) => '${p.series}:${p.value.toStringAsFixed(1)}').join(", ")}]',
    );
  }

  void _onDemoModeChanged() {
    if (!mounted) return;
    if (KultivarApp.isDemoModeNotifier.value &&
        _window != TimeWindow.all) {
      // Demo just turned on -- expand the window so the seeded
      // 140-day run history is visible on the trend chart.
      setState(() => _window = TimeWindow.all);
    } else if (!KultivarApp.isDemoModeNotifier.value &&
        _window == TimeWindow.all) {
      // Demo just turned off (user tapped Clear & Start Fresh).
      // Snap back to the saved preference (or last30 if none) so
      // the real-user view isn't polluted by the demo's wide
      // window choice.
      UiPreferencesService.loadTimeWindow().then((value) {
        if (!mounted) return;
        setState(() => _window = value);
      });
    }
  }

  Future<void> _loadHiddenSeries() async {
    final saved = await UiPreferencesService.loadHiddenSeries();
    if (mounted) {
      setState(() {
        _hiddenSeries
          ..clear()
          ..addAll(saved);
      });
    }
  }

  Future<void> _saveHiddenSeries() async {
    await UiPreferencesService.saveHiddenSeries(_hiddenSeries.toList());
  }

  void _showBatchEnvDialog(BuildContext context, GrowRepository repo) {
    final tempController = TextEditingController();
    final humidityController = TextEditingController();
    final notesController = TextEditingController();

    // Bug fix v8 (Marco's persistent Log-Env crash): this sheet was the
    // ONLY entry point still using the original synchronous
    // repo.addBatchEnvironmentLog + Navigator.pop pattern that every
    // other FAB sheet was migrated away from in PR #18.  That's why
    // PR #6/7/13/15/17/18 didn't fix the crash he kept hitting: he
    // taps the "Log all spaces" thermostat icon on the Analytics
    // AppBar, not the FAB-hub Log Environment.
    //
    // Pop with a payload, persist + dispose in Future.delayed(500ms).
    showModalBottomSheet<({double? temperature, double? humidity, String? notes})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) {
          final canLog =
              double.tryParse(tempController.text) != null ||
              double.tryParse(humidityController.text) != null;

          return AppSheet(
            title: 'Log All Spaces',
            subtitle:
                'Applied to ${repo.growSpaces.length} '
                '${repo.growSpaces.length == 1 ? 'space' : 'spaces'}',
            icon: Icons.broadcast_on_personal_rounded,
            iconColor: AppColors.primary,
            children: [
              TextField(
                controller: tempController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: ctx.colTextPrimary),
                decoration: InputDecoration(
                  labelText: tempUnitLabel,
                  prefixIcon:
                      const Icon(Icons.thermostat_rounded, size: 18),
                ),
                onChanged: (_) => ss(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: humidityController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: ctx.colTextPrimary),
                decoration: const InputDecoration(
                  labelText: 'Humidity (%)',
                  prefixIcon: Icon(Icons.water_drop_rounded, size: 18),
                ),
                onChanged: (_) => ss(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: notesController,
                style: TextStyle(color: ctx.colTextPrimary),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_rounded, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sensors_rounded, size: 17),
                  label: Text(
                      'Log to ${repo.growSpaces.length} '
                      '${repo.growSpaces.length == 1 ? 'Space' : 'Spaces'}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canLog ? AppColors.primary : ctx.colSurface3,
                    foregroundColor:
                        canLog ? Colors.black : ctx.colTextMuted,
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
                  onPressed: canLog
                      ? () {
                          final rawTemp =
                              double.tryParse(tempController.text);
                          final humidity =
                              double.tryParse(humidityController.text);
                          final trimmedNotes =
                              notesController.text.trim();
                          Navigator.pop(ctx, (
                            temperature: rawTemp != null
                                ? toStorageTemp(rawTemp)
                                : null,
                            humidity: humidity,
                            notes:
                                trimmedNotes.isEmpty ? null : trimmedNotes,
                          ));
                        }
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm)),
                  child: Text('Cancel',
                      style: AppTypography.labelLarge(ctx).copyWith(
                        color: ctx.colTextSecondary,
                        fontSize: 15,
                      )),
                ),
              ),
            ],
          );
        },
      ),
    ).then((payload) {
      // Bug fix v8 -- single delayed window for dispose + persist +
      // toast.  See the comment at the top of _showBatchEnvDialog.
      Future.delayed(const Duration(milliseconds: 500), () {
        tempController.dispose();
        humidityController.dispose();
        notesController.dispose();
        if (payload == null) return;
        final spaceCount = repo.growSpaces.length;
        repo.addBatchEnvironmentLog(
          temperature: payload.temperature,
          humidity: payload.humidity,
          notes: payload.notes,
        );
        if (!context.mounted) return;
        AppToast.show(
          context,
          'Logged to $spaceCount ${spaceCount == 1 ? 'space' : 'spaces'}',
          type: ToastType.success,
        );
      });
    });
  }
  // ── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();
    final analytics = context.watch<AnalyticsService>();

    // ── Free-tier history clamp ────────────────
    // context.select so a live tier change (purchase, restore, expiry
    // pushed by the CustomerInfoUpdateListener) rebuilds the gates.
    // Demo mode is exempt: it forces TimeWindow.all so the seeded
    // 140-day sample history stays visible (screenshot flow above).
    final tier =
        context.select<SubscriptionService, SubscriptionTier>((s) => s.tier);
    final isDemo = KultivarApp.isDemoModeNotifier.value;
    final effectiveWindow =
        isDemo ? _window : FreeTierGate.clampTimeWindow(tier, _window);
    final lockedWindows =
        isDemo ? const <TimeWindow>{} : FreeTierGate.lockedTimeWindows(tier);

    // ── Dashboard stats (STEP 4) ───────────────
    final plants = repo.plants;

    final int totalPlants = plants.length;
    final int growing =
        plants.where((p) => p.status == PlantStatus.growing).length;
    final int drying =
        plants.where((p) => p.status == PlantStatus.drying).length;
    final int curing =
        plants.where((p) => p.status == PlantStatus.curing).length;
    final int removed =
        plants.where((p) => p.status == PlantStatus.removed).length;
    final int spaces = repo.growSpaces.length;
    final int completed =
        plants.where((p) => p.status == PlantStatus.completed).length;

    // ── Per-strain analytics ──────────────────
    // Group completed harvest logs by strain (only logs with a dryWeight).
    final Map<String, List<HarvestLog>> logsByStrain = {};
    for (final log in repo.harvestLogs) {
      if (log.dryWeight != null) {
        logsByStrain.putIfAbsent(log.strain, () => []).add(log);
      }
    }
    // Build per-strain stats sorted by avg dry weight descending.
    final strainStats = logsByStrain.entries.map((e) {
      final logs = e.value;
      final avgDry =
          logs.map((l) => l.dryWeight!).reduce((a, b) => a + b) / logs.length;
      // Average quality rating (only logs with a rating).
      final ratedLogs =
          logs.where((l) => l.qualityRating != null).toList();
      final avgRating = ratedLogs.isEmpty
          ? null
          : ratedLogs.map((l) => l.qualityRating!).reduce((a, b) => a + b) /
              ratedLogs.length;
      // Average grow duration: days from plant start to harvest.
      // Uses the repo's O(1) plant-by-ID map (see P3) — was previously a
      // linear scan per harvest log × twice per dashboard rebuild.
      final byId = repo.plantsById;
      final durLogs =
          logs.where((l) => byId.containsKey(l.plantId)).toList();
      final avgDays = durLogs.isEmpty
          ? null
          : durLogs
                  .map((l) {
                    final plant = byId[l.plantId]!;
                    return l.harvestedDate.difference(plant.startDate).inDays;
                  })
                  .reduce((a, b) => a + b) /
              durLogs.length;
      // Coefficient of variation (stddev / mean) for yield consistency.
      // CV ≤ 0.15 → consistent; CV ≥ 0.35 → variable.
      double? cv;
      if (logs.length >= 2 && avgDry > 0) {
        final weights = logs.map((l) => l.dryWeight!).toList();
        final variance = weights
                .map((w) => (w - avgDry) * (w - avgDry))
                .reduce((a, b) => a + b) /
            weights.length;
        cv = math.sqrt(variance) / avgDry;
      }

      // Phenotype breakdown — only when ≥ 2 distinct tagged phenos exist.
      Map<String, double>? phenoBreakdown;
      final taggedLogs = logs.where((l) => l.phenotypeTag != null).toList();
      final tagGroups = <String, List<double>>{};
      for (final l in taggedLogs) {
        tagGroups.putIfAbsent(l.phenotypeTag!, () => []).add(l.dryWeight!);
      }
      if (tagGroups.length >= 2) {
        phenoBreakdown = {
          for (final entry in tagGroups.entries)
            entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length,
        };
        // Sort by average weight descending.
        phenoBreakdown = Map.fromEntries(
          phenoBreakdown.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
        );
      }

      return _StrainStat(
        strain: e.key,
        count: logs.length,
        avgDryWeight: avgDry,
        avgRating: avgRating,
        avgDays: avgDays,
        cv: cv,
        phenoBreakdown: phenoBreakdown,
      );
    }).toList()
      ..sort((a, b) => b.avgDryWeight.compareTo(a.avgDryWeight));

    // ── Training analytics ────────────────────
    final trainingNotes = repo.notes
        .where((n) =>
            n.category == NoteCategory.training &&
            n.trainingDetails != null)
        .toList();

    // Technique frequency — how many events per technique across all plants.
    final Map<String, int> techniqueFrequency = {};
    for (final note in trainingNotes) {
      final label = note.trainingDetails!.technique.label;
      techniqueFrequency[label] = (techniqueFrequency[label] ?? 0) + 1;
    }
    final sortedTechniqueFreq = techniqueFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Trained vs untrained yield comparison.
    final trainedPlantIds =
        trainingNotes.map((n) => n.plantId).toSet();
    final trainedLogs = repo.harvestLogs
        .where((l) =>
            l.dryWeight != null && trainedPlantIds.contains(l.plantId))
        .toList();
    final untrainedLogs = repo.harvestLogs
        .where((l) =>
            l.dryWeight != null && !trainedPlantIds.contains(l.plantId))
        .toList();
    final trainedAvg = trainedLogs.isEmpty
        ? null
        : trainedLogs
                .map((l) => l.dryWeight!)
                .reduce((a, b) => a + b) /
            trainedLogs.length;
    final untrainedAvg = untrainedLogs.isEmpty
        ? null
        : untrainedLogs
                .map((l) => l.dryWeight!)
                .reduce((a, b) => a + b) /
            untrainedLogs.length;

    // ── Issue pattern analysis ────────────────
    final issuePatterns =
        computeIssuePatterns(repo.plants, repo.notes);

    // ── Quality correlations ──────────────────
    final qualityCorrelations = computeQualityCorrelations(
      repo.plants,
      repo.harvestLogs,
      noCorrelationFallback:
          AppLocalizations.of(context).analyticsNoStrongCorrelation,
    );

    // ── Build yield series ────────────────────
    final rawSeries = buildYieldSeries(
        repo.plants, repo.growSpaces, effectiveWindow, repo.harvestLogs);

    final smoothedSeries = applyRollingAverage(rawSeries, windowSize: 3);

    final displaySeries = _smoothingEnabled ? smoothedSeries : rawSeries;

    // Bug fix v?: dry-weight chart renders as a tiny sliver at x=0
    // despite the data path looking correct.  Dump the chart inputs
    // to the local crash log so the next Share Diagnostics tap
    // surfaces the actual values.  Throttled to one dump per chart
    // input combination (window/smoothing/bands/hidden) so a normal
    // browsing session doesn't bloat the log.
    _maybeLogChartSnapshot(effectiveWindow, rawSeries, displaySeries);

    // ── Per-space forecasts ───────────────────
    // Group display series by space name, then build a forecast for each
    // series that has ≥ 5 data points.
    final seriesBySpace = <String, List<SeriesPoint>>{};
    for (final p in displaySeries) {
      seriesBySpace.putIfAbsent(p.series, () => []).add(p);
    }
    final forecasts = <String, ForecastResult>{};
    seriesBySpace.forEach((spaceName, pts) {
      final result = buildForecast(pts);
      if (result != null) forecasts[spaceName] = result;
    });

    // ── Insights ─────────────────────────────
    final insights = generateInsights(
      displaySeries.map((p) => p.value).toList(),
      rawSeries.map((p) => p.value).toList(),
    );

    // ── Milestone annotations ────────────────
    final annotations = repo.notes
        .where((n) => n.category == NoteCategory.milestone)
        .map((n) => ChartAnnotation(n.createdAt, n.content))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.insights_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.xs),
            Text(AppLocalizations.of(context).analyticsTitle,
                style: AppTypography.headlineLarge(context)
                    .copyWith(color: AppColors.primary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.thermostat),
            tooltip: 'Log all spaces',
            onPressed: () => _showBatchEnvDialog(context, repo),
          ),
          // Bug fix v4: Calendar + Notes moved here from the Home
          // AppBar (Marco flagged Home as too crowded; Analytics has
          // clear room next to the existing Log + More-menu buttons).
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Calendar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CalendarScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 17),
            tooltip: AppLocalizations.of(context).navNotes,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PlantNotesTab(),
              ),
            ),
          ),
          PopupMenuButton<_DashAction>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More actions',
            onSelected: (action) async {
              switch (action) {
                case _DashAction.export:
                  // CSV export is a paid feature (Lifetime + Pro).
                  if (!context
                      .read<SubscriptionService>()
                      .hasUnlimitedFeatures) {
                    await showPaywall(context);
                    return;
                  }
                  await CsvExportService.exportHarvestLogs(
                    repo.harvestLogs,
                    repo.plants,
                  );
                case _DashAction.history:
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EnvironmentLogScreen(),
                    ),
                  );
                case _DashAction.compare:
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CrossGrowComparisonScreen(),
                    ),
                  );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _DashAction.export,
                child: ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: Row(
                    children: [
                      Text(AppLocalizations.of(context).dashboardExportCsv),
                      if (!tier.hasUnlimitedFeatures) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const ProBadge(),
                      ],
                    ],
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: _DashAction.history,
                child: ListTile(
                  leading: Icon(Icons.history_rounded),
                  title: Text('Env Log History'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: _DashAction.compare,
                child: ListTile(
                  leading: Icon(Icons.compare_arrows_rounded),
                  title: Text('Compare Grows'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Time window ─────────────────────
            TimeWindowSelector(
              selected: effectiveWindow,
              locked: lockedWindows,
              onLockedTap: () => showPaywall(context),
              onChanged: (w) {
                setState(() => _window = w);
                UiPreferencesService.saveTimeWindow(w);
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // ── 7-day care strip ─────────────────
            if (repo.growSpaces.any((s) =>
                s.wateringEnabled || s.feedingEnabled || s.ipmEnabled)) ...[
              _SpaceCareStrip(
                spaces: repo.growSpaces,
                plants: repo.plants,
                notes: repo.notes,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Quick-log card ───────────────────
            if (repo.growSpaces.isNotEmpty)
              _QuickLogCard(repo: repo),

            if (repo.growSpaces.isNotEmpty)
              const SizedBox(height: AppSpacing.sectionGap),

            // ── Overview stats ──────────────────
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Text(AppLocalizations.of(context).analyticsOverview,
                    style: AppTypography.headlineSmall(context)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              children: [
                DashboardStatCard(
                  label: 'Spaces',
                  value: spaces.toString(),
                  color: AppColors.secondary,
                  onTap: () {},
                ),
                DashboardStatCard(
                  label: 'Plants',
                  value: totalPlants.toString(),
                  color: AppColors.primary,
                  onTap: () => _openPlantList(
                    context,
                    'All Plants',
                    (_) => true,
                  ),
                ),
                if (growing > 0)
                  DashboardStatCard(
                    label: 'Growing',
                    value: growing.toString(),
                    color: AppColors.growing,
                    onTap: () => _openPlantList(
                      context,
                      'Growing Plants',
                      (p) => p.status == PlantStatus.growing,
                    ),
                  ),
                if (drying > 0)
                  DashboardStatCard(
                    label: 'Drying',
                    value: drying.toString(),
                    color: AppColors.drying,
                    onTap: () => _openPlantList(
                      context,
                      'Drying Plants',
                      (p) => p.status == PlantStatus.drying,
                    ),
                  ),
                if (curing > 0)
                  DashboardStatCard(
                    label: 'Curing',
                    value: curing.toString(),
                    color: AppColors.curing,
                    onTap: () => _openPlantList(
                      context,
                      'Curing Plants',
                      (p) => p.status == PlantStatus.curing,
                    ),
                  ),
                if (completed > 0)
                  DashboardStatCard(
                    label: 'Completed',
                    value: completed.toString(),
                    color: AppColors.completed,
                    onTap: () => _openPlantList(
                      context,
                      'Completed Plants',
                      (p) => p.status == PlantStatus.completed,
                    ),
                  ),
                if (removed > 0)
                  DashboardStatCard(
                    label: 'Removed',
                    value: removed.toString(),
                    color: AppColors.removed,
                    onTap: () => _openPlantList(
                      context,
                      'Removed / Culled Plants',
                      (p) => p.status == PlantStatus.removed,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.sectionGap),

            // ── Yield Trend header + toggle chips ─
            // Bug fix v4: in Zulu the chart title becomes long
            // ("Ithrendi yesisindo esomileyo (g)"), pushing the
            // Smooth / Bands toggle chips off-screen.  Wrap the
            // title in Flexible+ellipsis so it gives way before
            // the chips overflow.
            Row(
              children: [
                const Icon(Icons.show_chart_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).analyticsDryWeightTrend,
                    style: AppTypography.headlineSmall(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _ChartToggleChip(
                  label: AppLocalizations.of(context).analyticsChartSmooth,
                  active: _smoothingEnabled,
                  onTap: () => setState(() => _smoothingEnabled = !_smoothingEnabled),
                ),
                const SizedBox(width: AppSpacing.xs),
                _ChartToggleChip(
                  label: AppLocalizations.of(context).analyticsChartBands,
                  active: _showConfidenceBands,
                  onTap: () {
                    setState(
                        () => _showConfidenceBands = !_showConfidenceBands);
                    UiPreferencesService.saveShowBands(_showConfidenceBands);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Chart ──────────────────────────
            if (repo.harvestLogs.isEmpty)
              _AnalyticsEmptyState(
                hasSpaces: repo.growSpaces.isNotEmpty,
                hasPlants: repo.plants.isNotEmpty,
                hasHarvests: false,
              )
            else if (rawSeries.isEmpty)
              // Harvest logs exist but none fall in the selected time window.
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 36, color: context.colTextMuted),
                    const SizedBox(height: AppSpacing.sm),
                    Text(AppLocalizations.of(context).analyticsNoDataInWindow,
                        style: AppTypography.headlineSmall(context)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'No harvests recorded in this period. '
                      'Try a wider time range.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium(context),
                    ),
                  ],
                ),
              )
            else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: MultiLineChart(
                key: ValueKey(
                  '$effectiveWindow$_smoothingEnabled$_showConfidenceBands'
                  '${_hiddenSeries.join()}',
                ),
                series: displaySeries,
                hiddenSeries: _hiddenSeries,
                showConfidenceBands: _showConfidenceBands,
                annotations: annotations,
                selectedPoint: _hoverPoint,
                forecasts: forecasts,
                onPointTap: (point, band) {
                  setState(() {
                    _hoverPoint = point;
                    _hoverBand = band;
                  });
                },
              ),
            ),

            // ── Tooltip ─────────────────────────
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _hoverPoint == null ? 0 : 1,
              child: _hoverPoint == null
                  ? const SizedBox.shrink()
                  : Card(
                      color: context.colSurface2,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Text(
                          _hoverBand != null
                              ? '${_hoverPoint!.series}\n'
                                  '${_hoverPoint!.value.toStringAsFixed(1)} g dry\n'
                                  'Rolling range: ${_hoverBand!.min.toStringAsFixed(1)}–'
                                  '${_hoverBand!.max.toStringAsFixed(1)} g'
                              : '${_hoverPoint!.series}\n'
                                  '${_hoverPoint!.value.toStringAsFixed(1)} g dry',
                          style: AppTypography.bodyMedium(context),
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Legend toggles ──────────────────
            //
            // The default FilterChip label colour drops to a very low
            // contrast in dark mode when the chip is unselected — a
            // user reported the space names under the Dry Weight Trend
            // chart were near-invisible.  Pin the label style to the
            // theme's textPrimary (visible) and textMuted (clearly
            // de-emphasised but still legible) for the two states.
            Wrap(
              spacing: 8,
              children: repo.growSpaces.map((space) {
                final hidden = _hiddenSeries.contains(space.name);
                return FilterChip(
                  label: Text(
                    space.name,
                    style: AppTypography.labelLarge(context).copyWith(
                      color: hidden
                          ? context.colTextMuted
                          : context.colTextPrimary,
                      fontWeight: hidden ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  selected: !hidden,
                  onSelected: (v) async {
                    setState(() {
                      v
                          ? _hiddenSeries.remove(space.name)
                          : _hiddenSeries.add(space.name);
                    });
                    await _saveHiddenSeries();
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.sectionGap),

            // ── Insights ────────────────────────
            InsightsFeed(
              insights: insights,
              timeWindowLabel: effectiveWindow.label == 'All'
                  ? 'All time'
                  : 'Last ${effectiveWindow.label}',
              onNotify: (msg) async {
                AppToast.show(context, msg, type: ToastType.info);
                // Use firstOrNull — insights may have refreshed (time window
                // change) between the callback being scheduled and firing.
                final insight =
                    insights.where((i) => i.message == msg).firstOrNull;
                if (insight != null) {
                  await InsightNotificationBridge.markAsSeen(insight);
                }
              },
            ),

            // ── Strain Breakdown ─────────────────
            if (strainStats.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sectionGap),
              Row(
                children: [
                  const Icon(Icons.science_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text(AppLocalizations.of(context).analyticsStrainBreakdown,
                      style: AppTypography.headlineSmall(context)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _strainBreakdownTable(context, strainStats),
            ],

            // ── Quality Insights ─────────────────
            if (qualityCorrelations.hasData) ...[
              const SizedBox(height: AppSpacing.sectionGap),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.harvested, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text(AppLocalizations.of(context).analyticsQualityInsights,
                      style: AppTypography.headlineSmall(context)),
                  const Spacer(),
                  Text(
                    '${qualityCorrelations.totalRatedHarvests} rated harvests'
                    '${qualityCorrelations.overallAvgRating != null ? ' · avg ${qualityCorrelations.overallAvgRating!.toStringAsFixed(1)}★' : ''}',
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colTextMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _qualityInsightsCard(context, qualityCorrelations),
            ],

            // ── Issue Patterns ───────────────────
            if (issuePatterns.hasData) ...[
              const SizedBox(height: AppSpacing.sectionGap),
              Row(
                children: [
                  const Icon(Icons.warning_rounded,
                      color: AppColors.danger, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text(AppLocalizations.of(context).analyticsIssuePatterns,
                      style: AppTypography.headlineSmall(context)),
                  const Spacer(),
                  Text(
                    '${issuePatterns.totalIssues} issues · '
                    '${issuePatterns.plantsWithIssues} '
                    '${issuePatterns.plantsWithIssues == 1 ? 'plant' : 'plants'}',
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colTextMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _issuePatternsCard(context, issuePatterns),
            ],

            // ── Training Analytics ───────────────
            if (trainingNotes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sectionGap),
              Row(
                children: [
                  const Icon(Icons.content_cut_rounded,
                      color: AppColors.training, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text(AppLocalizations.of(context).analyticsTrainingAnalytics,
                      style: AppTypography.headlineSmall(context)),
                  const Spacer(),
                  Text(
                    '${trainingNotes.length} event${trainingNotes.length == 1 ? '' : 's'}'
                    ' · ${trainedPlantIds.length} plant${trainedPlantIds.length == 1 ? '' : 's'}',
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colTextMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _trainingAnalyticsCard(
                context,
                sortedTechniqueFreq: sortedTechniqueFreq,
                trainedAvg: trainedAvg,
                untrainedAvg: untrainedAvg,
                trainedCount: trainedLogs.length,
                untrainedCount: untrainedLogs.length,
              ),
            ],

            // ── Lifetime Stats ───────────────────
            if (repo.harvestLogs.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sectionGap),
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: AppColors.harvested, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text(AppLocalizations.of(context).analyticsLifetimeStats,
                      style: AppTypography.headlineSmall(context)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _lifetimeStatsGrid(context, analytics),
            ],

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  // ── Issue patterns card ────────────────────────

  Widget _issuePatternsCard(
      BuildContext context, IssuePatternSummary summary) {
    final maxCount =
        summary.phases.isEmpty ? 1 : summary.phases.first.issueCount;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Worst-phase callout banner
          if (summary.worstPhase != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusLg)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _issueCallout(summary),
                      style: AppTypography.bodySmall(context).copyWith(
                          color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.colBorder),
          ],

          // Phase rows
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: summary.phases.asMap().entries.map((entry) {
                final idx = entry.key;
                final phase = entry.value;
                final barFrac =
                    maxCount > 0 ? phase.issueCount / maxCount : 0.0;
                final isWorst = idx == 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              phase.phaseName,
                              style: AppTypography.labelLarge(context)
                                  .copyWith(
                                color: isWorst
                                    ? AppColors.danger
                                    : context.colTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '${phase.issueCount} '
                            '${phase.issueCount == 1 ? 'issue' : 'issues'}'
                            ' · ${phase.affectedPlants} '
                            '${phase.affectedPlants == 1 ? 'plant' : 'plants'}',
                            style: AppTypography.bodySmall(context).copyWith(
                                color: context.colTextMuted, fontSize: 11),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      // Bar
                      LayoutBuilder(builder: (ctx, constraints) {
                        return Stack(children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: context.colSurface3,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull),
                            ),
                          ),
                          Container(
                            height: 6,
                            width: constraints.maxWidth * barFrac,
                            decoration: BoxDecoration(
                              color: isWorst
                                  ? AppColors.danger
                                  : AppColors.warning
                                      .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull),
                            ),
                          ),
                        ]);
                      }),

                      // Top issue label
                      if (phase.topIssueName != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Most common: ${phase.topIssueName}'
                          '${phase.topIssueCount > 1 ? ' (×${phase.topIssueCount})' : ''}',
                          style: AppTypography.bodySmall(context).copyWith(
                              color: context.colTextMuted, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _issueCallout(IssuePatternSummary summary) {
    final worst = summary.worstPhase!;
    final base =
        '${worst.phaseName} is your highest-risk stage — '
        '${worst.issueCount} '
        '${worst.issueCount == 1 ? 'issue' : 'issues'} logged '
        'across ${worst.affectedPlants} '
        '${worst.affectedPlants == 1 ? 'plant' : 'plants'}.';
    if (worst.topIssueName != null) {
      return '$base Most frequent: ${worst.topIssueName}.';
    }
    return base;
  }

  // ── Quality insights card ──────────────────────

  Widget _qualityInsightsCard(
      BuildContext context, QualityCorrelationSummary q) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plain-language findings
          if (q.insights.isNotEmpty) ...[
            ...q.insights.map((insight) {
              final color = insight.polarity == QualityInsightPolarity.positive
                  ? AppColors.growing
                  : insight.polarity == QualityInsightPolarity.negative
                      ? AppColors.danger
                      : context.colTextSecondary;
              final icon = insight.polarity == QualityInsightPolarity.positive
                  ? Icons.trending_up_rounded
                  : insight.polarity == QualityInsightPolarity.negative
                      ? Icons.trending_down_rounded
                      : Icons.info_outline_rounded;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(insight.message,
                          style: AppTypography.bodySmall(context)
                              .copyWith(color: color)),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Cure duration buckets
          if (q.hasCureCorrelation) ...[
            if (q.insights.isNotEmpty)
              Divider(color: context.colBorder),
            const SizedBox(height: AppSpacing.xs),
            Row(children: [
              const Icon(Icons.inventory_2_rounded,
                  size: 13, color: AppColors.curing),
              const SizedBox(width: AppSpacing.xxs),
              Text('Cure Duration vs Quality',
                  style: AppTypography.labelSmall(context).copyWith(
                      color: context.colTextMuted,
                      fontSize: 11,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            _ratingBucketRow(context, q.cureBuckets),
          ],

          // Dry duration buckets
          if (q.hasDryCorrelation) ...[
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              const Icon(Icons.air_rounded,
                  size: 13, color: AppColors.drying),
              const SizedBox(width: AppSpacing.xxs),
              Text('Dry Duration vs Quality',
                  style: AppTypography.labelSmall(context).copyWith(
                      color: context.colTextMuted,
                      fontSize: 11,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            _ratingBucketRow(context, q.dryBuckets),
          ],
        ],
      ),
    );
  }

  Widget _ratingBucketRow(
      BuildContext context, List<QualityBucket> buckets) {
    final maxRating = buckets
        .map((b) => b.avgRating)
        .reduce((a, b) => a > b ? a : b);

    return Row(
      children: buckets.map((bucket) {
        final frac = maxRating > 0 ? bucket.avgRating / 5.0 : 0.0;
        final isTop = bucket.avgRating == maxRating && buckets.length > 1;
        final color = isTop ? AppColors.growing : context.colTextSecondary;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Column(
              children: [
                // Bar
                LayoutBuilder(builder: (ctx, constraints) {
                  return Column(
                    children: [
                      Container(
                        height: 48 * frac.clamp(0.1, 1.0),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isTop ? 0.25 : 0.12),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          border: isTop
                              ? Border.all(
                                  color: color.withValues(alpha: 0.5))
                              : null,
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: AppSpacing.xxs),
                // Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 11, color: AppColors.harvested),
                    const SizedBox(width: 2),
                    Text(
                      bucket.avgRating.toStringAsFixed(1),
                      style: AppTypography.labelSmall(context).copyWith(
                          color: color,
                          fontSize: 11,
                          fontWeight:
                              isTop ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  bucket.label,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 9),
                ),
                Text(
                  '(${bucket.count})',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted, fontSize: 9),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Consistency badge ──────────────────────────

  Widget _consistencyBadge(BuildContext context, bool isConsistent) {
    final color =
        isConsistent ? AppColors.growing : AppColors.warning;
    final label = isConsistent ? 'Consistent' : 'Variable';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(context).copyWith(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Training analytics card ────────────────────

  Widget _trainingAnalyticsCard(
    BuildContext context, {
    required List<MapEntry<String, int>> sortedTechniqueFreq,
    required double? trainedAvg,
    required double? untrainedAvg,
    required int trainedCount,
    required int untrainedCount,
  }) {
    final maxFreq = sortedTechniqueFreq.isEmpty
        ? 1
        : sortedTechniqueFreq.first.value;
    final top = sortedTechniqueFreq.take(6).toList();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Technique frequency bars ──────────────
          Text(
            'Technique Usage',
            style: AppTypography.labelLarge(context)
                .copyWith(color: context.colTextMuted, fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...top.map((entry) {
            final frac = entry.value / maxFreq;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      entry.key,
                      style: AppTypography.bodySmall(context).copyWith(
                        fontSize: 12,
                        color: context.colTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Stack(
                      children: [
                        // Track
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.training
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
                          ),
                        ),
                        // Fill
                        FractionallySizedBox(
                          widthFactor: frac,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.training,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${entry.value}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.training,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),

          // ── Trained vs untrained yield comparison ──
          if (trainedAvg != null &&
              untrainedAvg != null &&
              trainedCount >= 2 &&
              untrainedCount >= 2) ...[
            const SizedBox(height: AppSpacing.sm),
            // A4 — theme-aware divider so the bumped dark-mode
            // borderFaint doesn't bleed into light-mode rendering.
            Divider(height: 1, color: context.colBorderFaint),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Trained vs Untrained Yield',
              style: AppTypography.labelLarge(context)
                  .copyWith(color: context.colTextMuted, fontSize: 11),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _yieldCompareBar(
                    context,
                    label: 'Trained',
                    avg: trainedAvg,
                    count: trainedCount,
                    color: AppColors.training,
                    maxAvg:
                        trainedAvg > untrainedAvg ? trainedAvg : untrainedAvg,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _yieldCompareBar(
                    context,
                    label: 'Untrained',
                    avg: untrainedAvg,
                    count: untrainedCount,
                    color: context.colTextMuted,
                    maxAvg:
                        trainedAvg > untrainedAvg ? trainedAvg : untrainedAvg,
                  ),
                ),
              ],
            ),
            if (trainedAvg > untrainedAvg) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.training.withValues(alpha: 0.07),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                      color:
                          AppColors.training.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up_rounded,
                        size: 14, color: AppColors.training),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Trained plants yield '
                        '${((trainedAvg - untrainedAvg) / untrainedAvg * 100).toStringAsFixed(0)}% '
                        'more on average',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: AppColors.training,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (trainedAvg != null && untrainedAvg == null) ...[
            // Only trained plants have data — show a note
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: context.colBorderFaint),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Avg yield from trained plants: '
              '${trainedAvg.toStringAsFixed(1)} g  '
              '($trainedCount harvest${trainedCount == 1 ? '' : 's'})',
              style: AppTypography.bodySmall(context)
                  .copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _yieldCompareBar(
    BuildContext context, {
    required String label,
    required double avg,
    required int count,
    required Color color,
    required double maxAvg,
  }) {
    final frac = maxAvg > 0 ? (avg / maxAvg).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.bodySmall(context).copyWith(fontSize: 11)),
        const SizedBox(height: AppSpacing.xxs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 10,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${avg.toStringAsFixed(1)} g  ·  $count harvest${count == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Lifetime stats grid ────────────────────────

  Widget _lifetimeStatsGrid(
      BuildContext context, AnalyticsService analytics) {
    final avgYield = analytics.averageYield();
    final avgDrying = analytics.averageDryingTime();
    final totalWeight = analytics.totalHarvestedWeight();

    final dryingDays = avgDrying.inDays;
    final dryingLabel = dryingDays == 0
        ? '—'
        : dryingDays == 1
            ? '1 day'
            : '$dryingDays days';

    // Bug fix v2: default childAspectRatio of 1.0 (square cells)
    // wasn't enough vertical room for value (26 sp bold) + 8 px gap
    // + label (which wraps to 2 lines for "Avg Dry Time" at 3-col
    // S22 width).  Result was "BOTTOM OVERFLOWED BY 20 PIXELS".
    // 0.85 gives ~19 px more height per cell — covers the gap.
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.85,
      children: [
        DashboardStatCard(
          label: 'Total Yield',
          value: totalWeight > 0
              ? '${totalWeight.toStringAsFixed(1)}g'
              : '—',
          color: AppColors.harvested,
          onTap: () {},
        ),
        DashboardStatCard(
          label: 'Avg Dry (g)',
          value: avgYield > 0
              ? '${avgYield.toStringAsFixed(1)} g'
              : '—',
          color: AppColors.primary,
          onTap: () {},
        ),
        DashboardStatCard(
          label: 'Avg Dry Time',
          value: dryingLabel,
          color: AppColors.drying,
          onTap: () {},
        ),
      ],
    );
  }

  // ── Strain breakdown table ──────────────────────

  Widget _strainBreakdownTable(
      BuildContext context, List<_StrainStat> stats) {
    // Max dry weight for proportional bar rendering.
    final maxDry = stats.map((s) => s.avgDryWeight).reduce(
        (a, b) => a > b ? a : b);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // ── Column headers ──────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text('Strain',
                      style: AppTypography.labelSmall(context)
                          .copyWith(color: context.colTextMuted, fontSize: 10)),
                ),
                SizedBox(
                  width: 52,
                  child: Text('Avg (g)',
                      textAlign: TextAlign.right,
                      style: AppTypography.labelSmall(context)
                          .copyWith(color: context.colTextMuted, fontSize: 10)),
                ),
                SizedBox(
                  width: 48,
                  child: Text('Days',
                      textAlign: TextAlign.right,
                      style: AppTypography.labelSmall(context)
                          .copyWith(color: context.colTextMuted, fontSize: 10)),
                ),
                SizedBox(
                  width: 56,
                  child: Text('Rating',
                      textAlign: TextAlign.right,
                      style: AppTypography.labelSmall(context)
                          .copyWith(color: context.colTextMuted, fontSize: 10)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colBorder),
          // ── Rows ────────────────────────────
          ...stats.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final barFrac = maxDry > 0 ? s.avgDryWeight / maxDry : 0.0;
            return Column(
              children: [
                if (idx > 0) Divider(height: 1, color: context.colBorder),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.strain,
                                        style: AppTypography.labelLarge(context)
                                            .copyWith(fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (s.isConsistent) ...[
                                      const SizedBox(width: AppSpacing.xxs),
                                      _consistencyBadge(
                                          context, true),
                                    ] else if (s.isVariable) ...[
                                      const SizedBox(width: AppSpacing.xxs),
                                      _consistencyBadge(
                                          context, false),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${s.count} harvest${s.count == 1 ? '' : 's'}',
                                  style: AppTypography.labelSmall(context)
                                      .copyWith(
                                          color: context.colTextMuted,
                                          fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              s.avgDryWeight.toStringAsFixed(1),
                              textAlign: TextAlign.right,
                              style: AppTypography.labelLarge(context)
                                  .copyWith(
                                      color: AppColors.primary, fontSize: 12),
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              s.avgDays != null
                                  ? s.avgDays!.round().toString()
                                  : '—',
                              textAlign: TextAlign.right,
                              style: AppTypography.bodySmall(context)
                                  .copyWith(fontSize: 12),
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: s.avgRating != null
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 12,
                                          color: AppColors.harvested),
                                      const SizedBox(width: 2),
                                      Text(
                                        s.avgRating!.toStringAsFixed(1),
                                        style: AppTypography.bodySmall(context)
                                            .copyWith(fontSize: 12),
                                      ),
                                    ],
                                  )
                                : Text('—',
                                    textAlign: TextAlign.right,
                                    style: AppTypography.bodySmall(context)
                                        .copyWith(fontSize: 12)),
                          ),
                        ],
                      ),
                      // Proportional yield bar
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                        child: LinearProgressIndicator(
                          value: barFrac,
                          minHeight: 4,
                          backgroundColor: context.colSurface3,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                        ),
                      ),

                      // ── Pheno breakdown (shown when ≥ 2 tagged phenos) ──
                      if (s.phenoBreakdown != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        ...s.phenoBreakdown!.entries.map((pheno) {
                          final phenoFrac = maxDry > 0
                              ? pheno.value / maxDry
                              : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(
                                top: 4, left: 12),
                            child: Row(
                              children: [
                                // Indentation line
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: AppColors.training
                                      .withValues(alpha: 0.3),
                                  margin: const EdgeInsets.only(right: AppSpacing.xs),
                                ),
                                const Icon(Icons.biotech_rounded,
                                    size: 10,
                                    color: AppColors.training),
                                const SizedBox(width: AppSpacing.xxs),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pheno.key,
                                        style: AppTypography.labelSmall(
                                                context)
                                            .copyWith(
                                          color: AppColors.training,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            AppSpacing.radiusFull),
                                        child: LinearProgressIndicator(
                                          value: phenoFrac,
                                          minHeight: 3,
                                          backgroundColor:
                                              context.colSurface3,
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                      Color>(
                                                  AppColors.training),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${pheno.value.toStringAsFixed(1)}g',
                                    textAlign: TextAlign.right,
                                    style: AppTypography.labelSmall(context)
                                        .copyWith(
                                      color: AppColors.training,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Navigation helper ──────────────────────
  void _openPlantList(
    BuildContext context,
    String title,
    bool Function(Plant) filter,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantListScreen(
          title: title,
          filter: filter,
        ),
      ),
    );
  }
}

// ── Analytics empty state ──────────────────────────

class _AnalyticsEmptyState extends StatelessWidget {
  final bool hasSpaces;
  final bool hasPlants;
  final bool hasHarvests;

  const _AnalyticsEmptyState({
    required this.hasSpaces,
    required this.hasPlants,
    required this.hasHarvests,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusLg)),
              border: Border(
                  bottom: BorderSide(color: context.colBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.insights_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Yield analytics',
                          style: AppTypography.headlineSmall(context)),
                      Text(
                        'Your charts will appear here after your first harvest.',
                        style: AppTypography.bodySmall(context)
                            .copyWith(color: context.colTextMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Progress steps ───────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your progress',
                    style: AppTypography.labelLarge(context)
                        .copyWith(color: context.colTextMuted, fontSize: 11)),
                const SizedBox(height: AppSpacing.sm),
                _Step(
                  number: 1,
                  label: 'Create a grow space',
                  done: hasSpaces,
                ),
                _Step(
                  number: 2,
                  label: 'Add your first plant',
                  done: hasPlants,
                  hint: hasSpaces && !hasPlants
                      ? 'Tap + → Add Plant'
                      : null,
                ),
                _Step(
                  number: 3,
                  label: 'Harvest & record dry weight',
                  done: hasHarvests,
                  hint: hasPlants && !hasHarvests
                      ? 'Open a plant → mark as Harvested'
                      : null,
                ),
                const _Step(
                  number: 4,
                  label: 'Complete the cure cycle',
                  done: false,
                  isLast: true,
                ),
              ],
            ),
          ),

          // ── What unlocks ─────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colSurface2,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: context.colBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'After your first cure you unlock:',
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: context.colTextMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                const _UnlockChip(
                    icon: Icons.bar_chart_rounded,
                    label: 'Yield trend chart',
                    color: AppColors.primary),
                const _UnlockChip(
                    icon: Icons.science_rounded,
                    label: 'Strain leaderboard',
                    color: AppColors.harvested),
                const _UnlockChip(
                    icon: Icons.compare_arrows_rounded,
                    label: 'Cross-grow comparison',
                    color: AppColors.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String label;
  final bool done;
  final String? hint;
  final bool isLast;

  const _Step({
    required this.number,
    required this.label,
    required this.done,
    this.hint,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line + circle
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppColors.growing.withValues(alpha: 0.15)
                        : context.colSurface2,
                    border: Border.all(
                        color: done
                            ? AppColors.growing
                            : context.colBorder,
                        width: done ? 1.5 : 1),
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check_rounded,
                            size: 13, color: AppColors.growing)
                        : Text('$number',
                            style: AppTypography.labelSmall(context)
                                .copyWith(
                                    color: context.colTextMuted,
                                    fontSize: 10)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: context.colBorder,
                      margin:
                          const EdgeInsets.symmetric(vertical: 2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Label + hint
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: isLast ? 0 : AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: done
                          ? AppColors.growing
                          : context.colTextPrimary,
                      decoration: done
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor:
                          AppColors.growing.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.arrow_forward_rounded,
                            size: 10, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(
                          hint!,
                          style: AppTypography.bodySmall(context)
                              .copyWith(
                                  color: AppColors.primary,
                                  fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _UnlockChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextPrimary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── 7-day space care strip ─────────────────────────

/// A compact horizontal strip showing care events due in the next 7 days,
/// grouped by grow space. Overdue events are clamped to today's column.
class _SpaceCareStrip extends StatelessWidget {
  final List<GrowSpace> spaces;
  final List<Plant> plants;
  final List<PlantNote> notes;

  const _SpaceCareStrip({
    required this.spaces,
    required this.plants,
    required this.notes,
  });

  // ── Helpers ───────────────────────────────────

  /// Returns the date when care of [category] is next due for [space].
  /// Looks at all watering/feeding/IPM notes logged for any growing plant
  /// in the space to find the most recent care event.
  DateTime? _nextDue(GrowSpace space, NoteCategory category, int intervalDays) {
    final activePlants = plants
        .where((p) =>
            p.growSpaceId == space.id && p.status == PlantStatus.growing)
        .toList();
    if (activePlants.isEmpty) return null;

    final plantIds = activePlants.map((p) => p.id).toSet();
    final relevant = notes
        .where((n) => plantIds.contains(n.plantId) && n.category == category)
        .toList();

    final DateTime baseline;
    if (relevant.isEmpty) {
      // No care notes yet — use earliest plant start date as reference.
      baseline = activePlants
          .map((p) => p.startDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
    } else {
      baseline = relevant
          .map((n) => n.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }
    return baseline.add(Duration(days: intervalDays));
  }

  /// Builds the list of (space, category, color) events that fall on [day].
  /// Overdue events (due < today) are shown on today.
  List<({GrowSpace space, NoteCategory category, Color color})> _eventsForDay(
      DateTime day, bool isToday) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final events =
        <({GrowSpace space, NoteCategory category, Color color})>[];

    for (final space in spaces) {
      if (space.wateringEnabled) {
        final due = _nextDue(space, NoteCategory.watering,
            space.wateringIntervalDays);
        if (due != null) {
          final dueDay = DateTime(due.year, due.month, due.day);
          final isOverdue = dueDay.isBefore(todayStart);
          if ((isToday && isOverdue) ||
              (!dueDay.isBefore(dayStart) && dueDay.isBefore(dayEnd))) {
            events.add((
              space: space,
              category: NoteCategory.watering,
              color: AppColors.water,
            ));
          }
        }
      }
      if (space.feedingEnabled) {
        final due = _nextDue(
            space, NoteCategory.feeding, space.feedingIntervalDays);
        if (due != null) {
          final dueDay = DateTime(due.year, due.month, due.day);
          final isOverdue = dueDay.isBefore(todayStart);
          if ((isToday && isOverdue) ||
              (!dueDay.isBefore(dayStart) && dueDay.isBefore(dayEnd))) {
            events.add((
              space: space,
              category: NoteCategory.feeding,
              color: AppColors.curing,
            ));
          }
        }
      }
      if (space.ipmEnabled) {
        final due =
            _nextDue(space, NoteCategory.ipm, space.ipmIntervalDays);
        if (due != null) {
          final dueDay = DateTime(due.year, due.month, due.day);
          final isOverdue = dueDay.isBefore(todayStart);
          if ((isToday && isOverdue) ||
              (!dueDay.isBefore(dayStart) && dueDay.isBefore(dayEnd))) {
            events.add((
              space: space,
              category: NoteCategory.ipm,
              color: AppColors.ipmColor,
            ));
          }
        }
      }
    }
    return events;
  }

  void _showDaySheet(
    BuildContext context,
    DateTime day,
    List<({GrowSpace space, NoteCategory category, Color color})> events,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AppSheet(
        title: _dayFull(day),
        children: [
          if (events.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'Nothing scheduled.',
                style: AppTypography.bodyMedium(context)
                    .copyWith(color: context.colTextMuted),
              ),
            )
          else
            ...events.map((e) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: e.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(e.space.name,
                          style: AppTypography.labelLarge(context)),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '· ${_categoryLabel(e.category)}',
                        style: AppTypography.bodySmall(context)
                            .copyWith(color: context.colTextMuted),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  String _categoryLabel(NoteCategory cat) {
    switch (cat) {
      case NoteCategory.watering:
        return 'Watering';
      case NoteCategory.feeding:
        return 'Feeding';
      case NoteCategory.ipm:
        return 'IPM check';
      default:
        return cat.name;
    }
  }

  String _dayFull(DateTime d) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today — ${months[d.month]} ${d.day}';
    }
    return '${days[d.weekday - 1]}, ${months[d.month]} ${d.day}';
  }

  String _dayAbbr(DateTime d) {
    const abbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return abbr[d.weekday - 1];
  }

  // ── Build ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
        7, (i) => DateTime(today.year, today.month, today.day + i));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.event_repeat_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(AppLocalizations.of(context).analyticsCareSchedule,
                  style: AppTypography.headlineSmall(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Day columns
          Row(
            children: days.asMap().entries.map((entry) {
              final i = entry.key;
              final day = entry.value;
              final isToday = i == 0;
              final events = _eventsForDay(day, isToday);
              final hasEvents = events.isNotEmpty;
              final visible = events.take(3).toList();
              final overflow = events.length - 3;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _showDaySheet(context, day, events),
                  child: Container(
                    margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : context.colSurface2,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: isToday
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : context.colBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Day abbr
                        Text(
                          isToday ? 'Today' : _dayAbbr(day),
                          style: AppTypography.labelSmall(context).copyWith(
                            color: isToday
                                ? AppColors.primary
                                : context.colTextMuted,
                            fontSize: 9,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        // Date number
                        Text(
                          '${day.day}',
                          style: AppTypography.labelLarge(context).copyWith(
                            color: isToday
                                ? AppColors.primary
                                : context.colTextPrimary,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // Event dots
                        if (hasEvents) ...[
                          ...visible.map((e) => Container(
                                width: 8,
                                height: 8,
                                margin:
                                    const EdgeInsets.only(bottom: 2),
                                decoration: BoxDecoration(
                                  color: e.color,
                                  shape: BoxShape.circle,
                                ),
                              )),
                          if (overflow > 0)
                            Text(
                              '+$overflow',
                              style: AppTypography.labelSmall(context)
                                  .copyWith(
                                      fontSize: 8,
                                      color: context.colTextMuted),
                            ),
                        ] else
                          // Empty placeholder keeps column height uniform
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Legend
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            children: [
              _legendDot(context, AppColors.water, 'Water'),
              _legendDot(context, AppColors.curing, 'Feed'),
              _legendDot(context, AppColors.ipmColor, 'IPM'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(label,
            style: AppTypography.bodySmall(context)
                .copyWith(fontSize: 11, color: context.colTextMuted)),
      ],
    );
  }
}

// ── Quick-log card ─────────────────────────────────

class _QuickLogCard extends StatefulWidget {
  final GrowRepository repo;
  const _QuickLogCard({required this.repo});

  @override
  State<_QuickLogCard> createState() => _QuickLogCardState();
}

class _QuickLogCardState extends State<_QuickLogCard> {
  late final TextEditingController _tempCtrl;
  late final TextEditingController _humCtrl;
  bool _logging = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from the most recent environment log across all spaces.
    final allLogs = HiveService.allEnvironmentLogs()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final latest = allLogs.isNotEmpty ? allLogs.first : null;

    _tempCtrl = TextEditingController(
      text: latest?.temperature != null
          ? fromStorageTemp(latest!.temperature!).toStringAsFixed(1)
          : '',
    );
    _humCtrl = TextEditingController(
      text: latest?.humidity != null
          ? latest!.humidity!.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _tempCtrl.dispose();
    _humCtrl.dispose();
    super.dispose();
  }

  String _lastLoggedLabel() {
    final allLogs = HiveService.allEnvironmentLogs();
    if (allLogs.isEmpty) return 'No logs yet';
    allLogs.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final diff = DateTime.now().difference(allLogs.first.recordedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _submit(BuildContext context) {
    final rawTemp = double.tryParse(_tempCtrl.text);
    final humidity = double.tryParse(_humCtrl.text);
    if (rawTemp == null && humidity == null) return;

    setState(() => _logging = true);
    widget.repo.addBatchEnvironmentLog(
      temperature: rawTemp != null ? toStorageTemp(rawTemp) : null,
      humidity: humidity,
    );

    AppToast.show(
      context,
      'Logged to ${widget.repo.growSpaces.length} '
      '${widget.repo.growSpaces.length == 1 ? 'space' : 'spaces'}',
      type: ToastType.success,
    );
    setState(() => _logging = false);
  }

  @override
  Widget build(BuildContext context) {
    final spaceCount = widget.repo.growSpaces.length;
    final canLog = double.tryParse(_tempCtrl.text) != null ||
        double.tryParse(_humCtrl.text) != null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.sensors_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).analyticsQuickLog,
                      style: AppTypography.labelLarge(context),
                    ),
                    Text(
                      '$spaceCount ${spaceCount == 1 ? 'space' : 'spaces'} · ${_lastLoggedLabel()}',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Inline fields ───────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tempCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.colTextPrimary),
                  decoration: InputDecoration(
                    labelText: tempUnitLabel,
                    isDense: true,
                    prefixIcon: const Icon(Icons.thermostat_rounded, size: 16),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _humCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.colTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Humidity (%)',
                    isDense: true,
                    prefixIcon: Icon(Icons.water_drop_rounded, size: 16),
                    contentPadding: EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Submit button ───────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _logging
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.broadcast_on_personal_rounded, size: 16),
              label: Text(
                'Log to $spaceCount ${spaceCount == 1 ? 'Space' : 'Spaces'}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canLog ? AppColors.primary : context.colSurface3,
                foregroundColor: canLog ? Colors.black : context.colTextMuted,
                padding: const EdgeInsets.symmetric(vertical: 11),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                textStyle: AppTypography.labelLarge(context)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              onPressed: canLog && !_logging ? () => _submit(context) : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard action enum ──────────────────────────

enum _DashAction { export, history, compare }

// ── Chart toggle chip ──────────────────────────────

class _ChartToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ChartToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.15)
              : context.colSurface2,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: active
                ? AppColors.primary.withValues(alpha: 0.5)
                : context.colBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall(context).copyWith(
            color: active ? AppColors.primary : context.colTextMuted,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ── Strain stat data class ─────────────────────────

class _StrainStat {
  final String strain;
  final int count;
  final double avgDryWeight;
  final double? avgRating;
  final double? avgDays;

  /// Coefficient of variation (stddev / mean). Null when count < 2.
  final double? cv;

  /// Per-phenotype breakdown — only present when ≥ 2 distinct tagged phenos exist.
  /// Key = phenotypeTag, value = average dry weight for that pheno.
  final Map<String, double>? phenoBreakdown;

  const _StrainStat({
    required this.strain,
    required this.count,
    required this.avgDryWeight,
    this.avgRating,
    this.avgDays,
    this.cv,
    this.phenoBreakdown,
  });

  /// True when yields are highly consistent (CV ≤ 15 %).
  bool get isConsistent => cv != null && cv! <= 0.15;

  /// True when yields are highly variable (CV ≥ 35 %).
  bool get isVariable => cv != null && cv! >= 0.35;
}
