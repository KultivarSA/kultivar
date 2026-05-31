import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/grow_space.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../models/strain_community_stats.dart';
import '../repository/grow_repository.dart';
import '../services/community_service.dart';
import '../services/currency_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../widgets/app_sheet.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/empty_state_art.dart';
import '../widgets/harvest_quality_sheet.dart';
import '../widgets/undo_overlay.dart';
import 'expense_tracker_screen.dart';
import 'grow_session_report_screen.dart';
import 'plant_detail_screen.dart';

class HarvestArchiveScreen extends StatefulWidget {
  final bool showRemovedOnly;
  final DateTime? initialStartDate;
  final String? initialGrowSpaceName;

  const HarvestArchiveScreen({
    super.key,
    this.showRemovedOnly = false,
    this.initialStartDate,
    this.initialGrowSpaceName,
  });

  @override
  State<HarvestArchiveScreen> createState() => _HarvestArchiveScreenState();
}

class _HarvestArchiveScreenState extends State<HarvestArchiveScreen> {
  // 'all' | 'month' | 'year'
  late String _dateFilter;
  late String? _filterSpaceId;

  // ── Community stats cache ─────────────────────
  //
  // Key present + value non-null  → fetched, has data
  // Key present + value null      → fetched, no community data
  // Key absent                    → not yet fetched
  final Map<String, StrainCommunityStats?> _statsCache = {};
  final Set<String> _fetchingStrains = {};

  /// Ensures community stats are fetched for every strain in [names].
  /// Skips strains already cached or currently in-flight.
  void _fetchStatsForStrains(Set<String> names) {
    for (final name in names) {
      if (name.isEmpty) continue;
      if (_statsCache.containsKey(name)) continue;
      if (_fetchingStrains.contains(name)) continue;
      _fetchingStrains.add(name);
      CommunityService.fetchStats(name).then((stats) {
        if (!mounted) return;
        setState(() {
          _statsCache[name] = stats;
          _fetchingStrains.remove(name);
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Seed from injected values so drilldown-from-dashboard still works.
    final now = DateTime.now();
    if (widget.initialStartDate != null) {
      final d = widget.initialStartDate!;
      if (d.year == now.year && d.month == now.month && d.day == 1) {
        _dateFilter = 'month';
      } else if (d.year == now.year && d.month == 1 && d.day == 1) {
        _dateFilter = 'year';
      } else {
        _dateFilter = 'all';
      }
    } else {
      _dateFilter = 'all';
    }
    _filterSpaceId = null; // space filter is always start from "all"
  }

  DateTime? get _activeStartDate {
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'year':
        return DateTime(now.year, 1, 1);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();

    // Single O(plants) pass — reused by all lookups below.
    final plantById = {for (final p in repo.plants) p.id: p};

    final logs = repo.harvestLogs.where((log) {
      final plant = plantById[log.plantId];
      if (plant == null) return false;
      if (widget.showRemovedOnly && plant.status != PlantStatus.removed) {
        return false;
      }
      final start = _activeStartDate;
      if (start != null && log.harvestedDate.isBefore(start)) {
        return false;
      }
      if (_filterSpaceId != null && plant.growSpaceId != _filterSpaceId) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.harvestedDate.compareTo(a.harvestedDate));

    // Lazily fetch community stats for all visible strains (deduplicated).
    // addPostFrameCallback avoids scheduling async work mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchStatsForStrains(
          logs.map((l) => l.strain).where((s) => s.isNotEmpty).toSet(),
        );
      }
    });

    final harvestedLogs = logs.where((log) {
      final plant = plantById[log.plantId];
      return plant != null &&
          plant.status != PlantStatus.removed &&
          (plant.status == PlantStatus.curing ||
              plant.status == PlantStatus.completed ||
              plant.status == PlantStatus.drying ||
              plant.isArchived);
    }).toList();

    final removedLogs = logs.where((log) {
      final plant = plantById[log.plantId];
      return plant != null && plant.status == PlantStatus.removed;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded,
                color: AppColors.harvested, size: 22),
            const SizedBox(width: AppSpacing.xs),
            Text(
              AppLocalizations.of(context).archiveTitle,
              style: AppTypography.headlineLarge(context)
                  .copyWith(color: AppColors.harvested),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date & space filter chips ──────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Row(
              children: [
                _filterChip(context, AppLocalizations.of(context).archiveFilterAll, 'all'),
                const SizedBox(width: AppSpacing.xs),
                _filterChip(context, AppLocalizations.of(context).archiveFilterMonth, 'month'),
                const SizedBox(width: AppSpacing.xs),
                _filterChip(context, AppLocalizations.of(context).archiveFilterYear, 'year'),
                // Space chips — one per space with plants in the archive.
                ...repo.growSpaces.map((s) {
                  final hasLogs = logs.any((l) {
                    final p = plantById[l.plantId];
                    return p?.growSpaceId == s.id;
                  }) ||
                      _filterSpaceId == s.id;
                  if (!hasLogs && _filterSpaceId != s.id) {
                    return const SizedBox.shrink();
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: AppSpacing.xs),
                      _spaceChip(context, s),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Expanded(
            child: logs.isEmpty
                ? repo.harvestLogs.isEmpty
                    ? EmptyState(
                        art: EmptyArt.archive,
                        // Archive screen brand colour is the harvested
                        // gold — keep the illustration tinted to match.
                        accent: AppColors.harvested,
                        title: AppLocalizations.of(context)
                            .archiveEmptyNoHarvestsTitle,
                        subtitle: AppLocalizations.of(context)
                            .archiveEmptyNoHarvestsBody,
                      )
                    : EmptyState(
                        art: EmptyArt.search,
                        accent: AppColors.harvested,
                        title: AppLocalizations.of(context)
                            .archiveEmptyNoMatchTitle,
                        subtitle: AppLocalizations.of(context)
                            .archiveEmptyNoMatchBody,
                        actionLabel: AppLocalizations.of(context)
                            .archiveEmptyNoMatchAction,
                        onAction: () => setState(() {
                          _dateFilter = 'all';
                          _filterSpaceId = null;
                        }),
                      )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      0,
                      AppSpacing.pagePadding,
                      AppSpacing.pagePadding,
                    ),
                    children: [
                if (harvestedLogs.isNotEmpty) ...[
                  _sectionHeader(context,
                      AppLocalizations.of(context).archiveSectionHarvested,
                      icon: Icons.verified_rounded,
                      iconColor: AppColors.growing),
                  ...harvestedLogs.map(
                    (log) => _archiveTile(
                      context, log, repo, plantById,
                      communityStats: _statsCache[log.strain],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (removedLogs.isNotEmpty) ...[
                  _sectionHeader(context,
                      AppLocalizations.of(context).archiveSectionRemoved,
                      icon: Icons.cancel_rounded,
                      iconColor: AppColors.danger),
                  ...removedLogs.map(
                    (log) => _archiveTile(
                      context, log, repo, plantById,
                      isRemoved: true,
                      communityStats: _statsCache[log.strain],
                    ),
                  ),
                ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Filter chip helpers ───────────────────────

  Widget _filterChip(BuildContext context, String label, String mode) {
    final selected = _dateFilter == mode && _filterSpaceId == null;
    return GestureDetector(
      onTap: () => setState(() {
        _dateFilter = mode;
        _filterSpaceId = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.harvested : context.colSurface3,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
              color: selected
                  ? AppColors.harvested
                  : context.colBorder),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge(context).copyWith(
            color: selected ? Colors.black : context.colTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _spaceChip(BuildContext context, GrowSpace space) {
    final selected = _filterSpaceId == space.id;
    return GestureDetector(
      onTap: () => setState(() {
        _filterSpaceId = selected ? null : space.id;
        if (!selected) _dateFilter = 'all';
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.growing : context.colSurface3,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
              color: selected ? AppColors.growing : context.colBorder),
        ),
        child: Text(
          space.name,
          style: AppTypography.labelLarge(context).copyWith(
            color: selected ? Colors.black : context.colTextSecondary,
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────

  Widget _sectionHeader(
    BuildContext context,
    String title, {
    IconData? icon,
    Color? iconColor,
  }) {
    final ic = iconColor ?? context.colTextSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: ic, size: 16),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(title, style: AppTypography.headlineSmall(context)),
        ],
      ),
    );
  }

  void _showEditHarvestDialog(
    BuildContext context,
    HarvestLog log,
    GrowRepository repo,
  ) {
    final wetCtrl = TextEditingController(
      text: log.wetWeight != null ? log.wetWeight!.toStringAsFixed(1) : '',
    );
    final dryCtrl = TextEditingController(
      text: log.dryWeight != null ? log.dryWeight!.toStringAsFixed(1) : '',
    );
    final notesCtrl = TextEditingController(text: log.notes ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppSheet(
        title: 'Edit Harvest Log',
        subtitle: log.plantName,
        icon: Icons.emoji_events_rounded,
        iconColor: AppColors.harvested,
        children: [
          // Wet weight
          TextField(
            controller: wetCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: ctx.colTextPrimary),
            decoration: const InputDecoration(
              labelText: 'Wet weight (g)',
              prefixIcon: Icon(Icons.water_drop_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Dry weight
          TextField(
            controller: dryCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: ctx.colTextPrimary),
            decoration: const InputDecoration(
              labelText: 'Dry weight (g)',
              prefixIcon: Icon(Icons.scale_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Notes
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            style: TextStyle(color: ctx.colTextPrimary),
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Action
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
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              onPressed: () {
                final wet = double.tryParse(wetCtrl.text);
                final dry = double.tryParse(dryCtrl.text);
                final notesText = notesCtrl.text.trim();
                repo.updateHarvestLog(HarvestLog(
                  id: log.id,
                  plantId: log.plantId,
                  plantName: log.plantName,
                  strain: log.strain,
                  harvestedDate: log.harvestedDate,
                  wetWeight: wet,
                  dryWeight: dry,
                  notes: notesText.isEmpty ? null : notesText,
                  isDraft: log.isDraft,
                  qualityRating: log.qualityRating,
                  aromaNote: log.aromaNote,
                  flavorNotes: log.flavorNotes,
                  effectNotes: log.effectNotes,
                ));
                Navigator.pop(ctx);
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
    ).then((_) {
      wetCtrl.dispose();
      dryCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  Widget _archiveTile(
    BuildContext context,
    HarvestLog log,
    GrowRepository repo,
    Map<String, Plant> plantById, {
    bool isRemoved = false,
    StrainCommunityStats? communityStats,
  }) {
    final plant = plantById[log.plantId];
    if (plant == null) return const SizedBox.shrink();

    final accentColor = isRemoved ? AppColors.danger : AppColors.harvested;

    final growDays =
        log.harvestedDate.difference(plant.startDate).inDays;

    final space = repo.growSpaces
        .where((s) => s.id == plant.growSpaceId)
        .firstOrNull;

    final subtitleParts = <String>[
      if (space != null) space.name,
      if (log.strain.isNotEmpty) log.strain,
    ];

    final tile = GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlantDetailScreen(plant: plant)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                Container(width: 4, color: accentColor),

                // Card body
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Row 1: name · dry weight · percentile ──
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plant.name,
                                style: AppTypography.labelLarge(context),
                              ),
                            ),
                            if (log.dryWeight != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusFull),
                                  border: Border.all(
                                      color: accentColor.withValues(
                                          alpha: 0.3)),
                                ),
                                child: Text(
                                  '${log.dryWeight!.toStringAsFixed(1)}g dry',
                                  style: AppTypography.labelSmall(context)
                                      .copyWith(
                                          color: accentColor, fontSize: 10),
                                ),
                              ),
                              // Community percentile chip — only shown
                              // once stats have loaded for this strain.
                              if (communityStats != null) ...[
                                const SizedBox(width: AppSpacing.xxs),
                                _percentileChip(
                                  context,
                                  communityStats.classify(log.dryWeight!),
                                  communityStats.percentileLabel(
                                      log.dryWeight!),
                                ),
                              ],
                            ],
                          ],
                        ),

                        // ── Row 2: strain · space ──
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitleParts.join(' · '),
                            style: AppTypography.bodySmall(context)
                                .copyWith(
                                    color: context.colTextSecondary),
                          ),
                        ],

                        // ── Row 3: date · grow days ──
                        const SizedBox(height: 3),
                        Text(
                          isRemoved
                              ? 'Removed · ${plant.archiveReason ?? 'No reason recorded'}'
                              : 'Harvested ${fmtShortDate(log.harvestedDate)} · ${growDays}d from seed',
                          style: AppTypography.bodySmall(context).copyWith(
                              color: context.colTextMuted, fontSize: 11),
                        ),

                        // ── Row 4: cost-per-gram pill ──
                        Builder(builder: (context) {
                          final currency =
                              context.watch<CurrencyService>();
                          final cpg = repo.costPerGram(
                              log.plantId, log.dryWeight);
                          final total =
                              repo.totalCostForPlant(log.plantId);
                          if (cpg == null && total <= 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: GestureDetector(
                              onTap: () {
                                final plant = repo.plants
                                    .where((p) => p.id == log.plantId)
                                    .firstOrNull;
                                if (plant == null) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ExpenseTrackerScreen(
                                        filterPlant: plant),
                                  ),
                                );
                              },
                              child: Wrap(
                                spacing: 4,
                                children: [
                                  if (total > 0)
                                    _costPill(context,
                                        Icons.account_balance_wallet_rounded,
                                        'Invested',
                                        currency.format(total),
                                        AppColors.harvested),
                                  if (cpg != null)
                                    _costPill(context,
                                        Icons.scale_rounded,
                                        'Cost/g',
                                        currency.formatPerGram(cpg),
                                        AppColors.growing),
                                ],
                              ),
                            ),
                          );
                        }),

                        // ── Row 4b: quality stars ──
                        if (log.qualityRating != null) ...[
                          const SizedBox(height: 5),
                          _qualityStars(context, log.qualityRating!),
                        ],

                        // ── Row 4b: sub-score pills ──
                        if (log.smellRating != null ||
                            log.effectRating != null ||
                            log.bagAppealRating != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (log.smellRating != null)
                                _subScorePill(context,
                                    Icons.air_rounded,
                                    'Smell',
                                    log.smellRating!,
                                    AppColors.info),
                              if (log.effectRating != null)
                                _subScorePill(context,
                                    Icons.psychology_rounded,
                                    'Effect',
                                    log.effectRating!,
                                    AppColors.training),
                              if (log.bagAppealRating != null)
                                _subScorePill(context,
                                    Icons.visibility_rounded,
                                    'Appeal',
                                    log.bagAppealRating!,
                                    AppColors.secondary),
                            ],
                          ),
                        ],

                        // ── Row 5: action buttons ──
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _tileAction(
                              context,
                              icon: Icons.edit_outlined,
                              label: 'Edit',
                              onTap: () => _showEditHarvestDialog(
                                  context, log, repo),
                            ),
                            if (!isRemoved) ...[
                              const SizedBox(width: AppSpacing.xs),
                              _tileAction(
                                context,
                                icon: log.hasQualityAssessment
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                label: log.hasQualityAssessment
                                    ? 'Edit Rating'
                                    : 'Rate',
                                color: log.hasQualityAssessment
                                    ? AppColors.harvested
                                    : null,
                                onTap: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => HarvestQualitySheet(
                                    harvestLog: log,
                                    onSave: ({
                                      required double? qualityRating,
                                      required String? aromaNote,
                                      required String? flavorNotes,
                                      required String? effectNotes,
                                      required double? smellRating,
                                      required double? effectRating,
                                      required double? bagAppealRating,
                                    }) {
                                      repo.updateHarvestQuality(
                                        harvestLogId: log.id,
                                        qualityRating: qualityRating,
                                        aromaNote: aromaNote,
                                        flavorNotes: flavorNotes,
                                        effectNotes: effectNotes,
                                        smellRating: smellRating,
                                        effectRating: effectRating,
                                        bagAppealRating: bagAppealRating,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: AppSpacing.xs),
                            _tileAction(
                              context,
                              icon: Icons.description_rounded,
                              label: 'Report',
                              color: AppColors.primary,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GrowSessionReportScreen(plant: plant),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Icon(Icons.chevron_right,
                                size: 15, color: context.colTextMuted),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => ConfirmSheet.show(
        context,
        icon: Icons.emoji_events_rounded,
        iconColor: AppColors.danger,
        title: 'Remove harvest record?',
        body: 'This permanently deletes the harvest record for '
            '"${plant.name}". The plant entry is kept.',
        confirmLabel: 'Delete Record',
      ),
      onDismissed: (_) {
        repo.deleteHarvestLog(log.id);
        UndoOverlay.show(
          context,
          icon: Icons.emoji_events_rounded,
          color: AppColors.harvested,
          title: 'Harvest Record Deleted',
          subtitle: '"${plant.name}" harvest record\nhas been removed.',
          undoLabel: 'Undo Delete',
          onUndo: () => repo.readdHarvestLog(log),
        );
      },
      child: tile,
    );
  }

  Widget _percentileChip(
    BuildContext context,
    CommunityPercentile percentile,
    String label,
  ) {
    final color = switch (percentile) {
      CommunityPercentile.top25    => AppColors.growing,
      CommunityPercentile.p50to75  => AppColors.growing,
      CommunityPercentile.p25to50  => AppColors.warning,
      CommunityPercentile.bottom25 => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(context)
            .copyWith(color: color, fontSize: 9),
      ),
    );
  }

  Widget _qualityStars(BuildContext context, double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) {
          // Same half-star logic as HarvestQualitySheet.
          final icon = rating >= i + 1
              ? Icons.star_rounded
              : (rating >= i + 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded);
          final filled = icon != Icons.star_outline_rounded;
          return Icon(
            icon,
            size: 13,
            color: filled ? AppColors.harvested : context.colTextMuted,
          );
        },
      ),
    );
  }

  Widget _costPill(BuildContext context, IconData icon, String label,
      String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: AppTypography.labelSmall(context)
                  .copyWith(color: color, fontSize: 9)),
          const SizedBox(width: 3),
          Text(value,
              style: AppTypography.labelSmall(context)
                  .copyWith(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _subScorePill(BuildContext context, IconData icon, String label,
      double rating, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: AppTypography.labelSmall(context)
                  .copyWith(color: color, fontSize: 9)),
          const SizedBox(width: 3),
          ...List.generate(
            5,
            (i) {
              final iconData = rating >= i + 1
                  ? Icons.star_rounded
                  : (rating >= i + 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded);
              final filled = iconData != Icons.star_outline_rounded;
              return Icon(
                iconData,
                size: 9,
                color: filled ? color : context.colTextMuted,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tileAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? context.colTextMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 3),
            Text(
              label,
              style: AppTypography.labelSmall(context)
                  .copyWith(color: c, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
