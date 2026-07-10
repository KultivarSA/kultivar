import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../main.dart' show KultivarApp;
import '../models/grow_diary_stats.dart';
import '../models/grow_space.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../models/strain_community_stats.dart';
import '../repository/grow_repository.dart';
import '../services/community_service.dart';
import '../services/hive_service.dart';
import '../services/review_prompt_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/image_cache_size.dart';
import '../utils/photo_path_resolver.dart';
import '../utils/plant_environment_analytics.dart';
import '../widgets/harvest_quality_sheet.dart';
import '../widgets/health_score_card.dart';
import '../widgets/plant_environment_card.dart';
import '../widgets/pro_gate.dart';

class GrowSessionReportScreen extends StatelessWidget {
  final Plant plant;

  const GrowSessionReportScreen({
    super.key,
    required this.plant,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();

    final currentPlant = repo.plants.firstWhere(
      (p) => p.id == plant.id,
      orElse: () => plant,
    );

    final notes = repo.notesForPlant(currentPlant.id, ascending: true);

    final harvestLog =
        repo.harvestLogs.where((l) => l.plantId == currentPlant.id).firstOrNull;

    final space = repo.growSpaces
        .where((s) => s.id == currentPlant.growSpaceId)
        .firstOrNull;

    final envLogs = HiveService.logsForSpace(currentPlant.growSpaceId)
        .where((l) =>
            l.recordedAt.isAfter(currentPlant.startDate) &&
            (currentPlant.archivedAt == null ||
                l.recordedAt.isBefore(currentPlant.archivedAt!)))
        .toList();

    final daysTotal = currentPlant.archivedAt != null
        ? currentPlant.archivedAt!.difference(currentPlant.startDate).inDays
        : currentPlant.daysGrowing;

    final yieldPct = harvestLog?.yieldPercentage;

    final issueNotes =
        notes.where((n) => n.category == NoteCategory.issue).toList();

    final resolvedCount = issueNotes.where((n) => n.isResolved).length;

    final photoNotes = notes.where((n) => n.photoUrls.isNotEmpty).toList();

    final insights = space != null
        ? PlantEnvironmentAnalytics.generateInsights(
            plant: currentPlant,
            logs: envLogs,
            space: space,
          )
        : <PlantEnvironmentInsight>[];

    final recommendations = _buildRecommendations(
      plant: currentPlant,
      notes: notes,
      insights: insights,
      yieldPct: yieldPct,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.emoji_events_rounded,
              color: AppColors.harvested, size: 22),
          const SizedBox(width: AppSpacing.xs),
          Text('Grow Report',
              style: AppTypography.headlineMedium(context)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share PDF',
            onPressed: () async {
              // PDF reports are a paid feature (Lifetime + Pro).
              if (!context.read<SubscriptionService>().hasUnlimitedFeatures) {
                await showPaywall(context);
                return;
              }

              // Task #87 — Capture the GrowRepository reference *before*
              // we await any async work so we don't drag a BuildContext
              // across the share-sheet gap (which trips
              // `use_build_context_synchronously` and is genuinely
              // unsafe if the user navigates away mid-share).
              final repoForReviewPrompt = context.read<GrowRepository>();

              final bytes = await _buildPdfBytes(
                plant: currentPlant,
                harvestLog: harvestLog,
                notes: notes,
                space: space,
                recommendations: recommendations,
                daysTotal: daysTotal,
                yieldPct: yieldPct,
              );
              await Printing.sharePdf(
                bytes: bytes,
                filename:
                    'grow_report_${currentPlant.name.replaceAll(' ', '_')}.pdf',
              );

              // Highest-satisfaction moment: the user just shared a
              // polished Grow Report PDF.  Ask them (subject to every
              // cooldown in ReviewPromptService).  Fire-and-forget —
              // we don't gate the share UX on it.
              await ReviewPromptService.maybePrompt(
                repo: repoForReviewPrompt,
                isDemoMode: KultivarApp.isDemoModeNotifier.value,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
            tooltip: 'Export PDF',
            onPressed: () {
              // PDF reports are a paid feature (Lifetime + Pro).
              if (!context.read<SubscriptionService>().hasUnlimitedFeatures) {
                showPaywall(context);
                return;
              }
              _exportPdf(
                context: context,
                plant: currentPlant,
                harvestLog: harvestLog,
                notes: notes,
                space: space,
                insights: insights,
                recommendations: recommendations,
                daysTotal: daysTotal,
                yieldPct: yieldPct,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero header ───────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.completed.withValues(alpha: 0.2),
                    context.colSurface1,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                    color: AppColors.completed.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.completed, size: 28),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(currentPlant.name,
                              style: AppTypography.displayMedium(context)
                                  .copyWith(color: AppColors.completed)),
                          Text(
                            currentPlant.strain,
                            style: AppTypography.bodyLarge(context)
                                .copyWith(color: context.colTextSecondary),
                          ),
                          if (space != null)
                            Text(
                              space.name,
                              style: AppTypography.bodySmall(context),
                            ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),

                  // Key stats row
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _statChip(
                        context,
                        '$daysTotal days',
                        'Total Grow',
                        AppColors.growing,
                      ),
                      if (harvestLog?.wetWeight != null)
                        _statChip(
                          context,
                          '${harvestLog!.wetWeight!.toStringAsFixed(1)}g',
                          'Wet Weight',
                          AppColors.drying,
                        ),
                      if (harvestLog?.dryWeight != null)
                        _statChip(
                          context,
                          '${harvestLog!.dryWeight!.toStringAsFixed(1)}g',
                          'Dry Weight',
                          AppColors.harvested,
                        ),
                      if (yieldPct != null)
                        _statChip(
                          context,
                          '${yieldPct.toStringAsFixed(1)}%',
                          'Yield',
                          yieldPct >= 22
                              ? AppColors.completed
                              : AppColors.harvested,
                        ),
                      _statChip(
                        context,
                        '${issueNotes.length}',
                        'Issues',
                        issueNotes.isEmpty
                            ? AppColors.growing
                            : AppColors.danger,
                      ),
                      if (issueNotes.isNotEmpty)
                        _statChip(
                          context,
                          '$resolvedCount',
                          'Resolved',
                          AppColors.growing,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Community benchmark ───────────
            // Silently loads — shows nothing while fetching or when the
            // strain has fewer than 5 community submissions.
            _CommunitySection(
              strainName:     currentPlant.strain,
              dryWeightGrams: harvestLog?.dryWeight,
            ),

            // ── Health grade ──────────────────
            HealthScoreCard(
              plant: currentPlant,
              spaceEnvironmentLogs: envLogs,
              plantNotes: notes,
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Photo timeline grid ───────────
            if (photoNotes.isNotEmpty) ...[
              Row(children: [
                const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text('Growth Photos',
                    style: AppTypography.headlineSmall(context)),
              ]),
              const SizedBox(height: AppSpacing.sm),
              _photoGrid(context, photoNotes),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Quality assessment (hoisted) ──
            // Quality is the personal payoff of a completed grow — show it
            // before environment data so users reach it without scrolling.
            _qualitySection(context, harvestLog),

            const SizedBox(height: AppSpacing.lg),

            // ── Environment summary ───────────
            if (space != null && envLogs.isNotEmpty) ...[
              PlantEnvironmentCard(
                plant: currentPlant,
                logs: envLogs,
                space: space,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Issue log ─────────────────────
            if (issueNotes.isNotEmpty) ...[
              Row(children: [
                const Icon(Icons.warning_rounded,
                    color: AppColors.warning, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text('Issue Log',
                    style: AppTypography.headlineSmall(context)),
              ]),
              const SizedBox(height: AppSpacing.sm),
              ...issueNotes.map((n) => _issueRow(context, n)),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Feed / water summary ──────────
            ..._feedingSummary(context, notes),

            // ── Recommendations ───────────────
            if (recommendations.isNotEmpty) ...[
              Row(children: [
                const Icon(Icons.lightbulb_rounded,
                    color: AppColors.secondary, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text('For Your Next Grow',
                    style: AppTypography.headlineSmall(context)),
              ]),
              const SizedBox(height: AppSpacing.sm),
              ...recommendations.map((r) => _recommendationRow(context, r)),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Timeline notes summary ────────
            Row(children: [
              const Icon(Icons.edit_note_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text('Note Summary',
                  style: AppTypography.headlineSmall(context)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            _noteSummary(context, notes),

            const SizedBox(height: AppSpacing.lg),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // ── Widget helpers ────────────────────────────

  Widget _statChip(
      BuildContext context, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value,
              style:
                  AppTypography.headlineSmall(context).copyWith(color: color)),
          Text(label, style: AppTypography.bodySmall(context)),
        ],
      ),
    );
  }

  Widget _photoGrid(BuildContext context, List<PlantNote> photoNotes) {
    final allPhotos = <_PhotoEntry>[];
    for (final note in photoNotes) {
      for (final nameOrPath in note.photoUrls) {
        allPhotos.add(_PhotoEntry(
          // Resolve bare filenames to absolute paths at build time so every
          // downstream File() / Image.file() call gets a valid path.
          path: PhotoPathResolver.resolve(nameOrPath),
          date: note.createdAt,
          label: note.categoryLabel,
        ));
      }
    }
    allPhotos.sort((a, b) => a.date.compareTo(b.date));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: allPhotos.length,
      itemBuilder: (_, i) {
        final entry = allPhotos[i];
        return Semantics(
          // A9 — every grid cell is a button that opens the photo
          // in its own viewer; describe by category + date so the
          // user can navigate by sound without seeing the layout.
          button: true,
          label: '${entry.label} photo from ${entry.date.day.toString().padLeft(2, '0')}/${entry.date.month.toString().padLeft(2, '0')}',
          child: GestureDetector(
            onTap: () => _viewPhoto(context, entry.path),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(entry.path),
                    fit: BoxFit.cover,
                    // P1.4 — report-screen photo grid; each cell is
                    // ~120 logical px on a phone, ~160 on tablet.
                    // Cap at 160 × DPR — a touch generous but spares
                    // the tablet layout from re-decoding on rotation.
                    cacheWidth: imageCacheWidth(context, 160),
                    // Parent Semantics carries the label.
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) => Container(
                      color: context.colSurface2,
                      child: Icon(Icons.broken_image,
                          color: context.colTextMuted),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xxs),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8)),
                    ),
                    child: Text(
                      _shortDate(entry.date),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _issueRow(BuildContext context, PlantNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: note.isResolved
              ? AppColors.growing.withValues(alpha: 0.3)
              : AppColors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(children: [
        Icon(
          note.isResolved ? Icons.check_circle : Icons.warning_rounded,
          color: note.isResolved ? AppColors.growing : AppColors.danger,
          size: 16,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.issueName ?? 'Issue',
                style: AppTypography.labelLarge(context).copyWith(
                  color: note.isResolved ? AppColors.growing : AppColors.danger,
                ),
              ),
              Text(note.content,
                  style: AppTypography.bodySmall(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Text(
          note.isResolved ? 'Resolved' : 'Open',
          style: AppTypography.labelSmall(context).copyWith(
            color: note.isResolved ? AppColors.growing : AppColors.danger,
          ),
        ),
      ]),
    );
  }

  List<Widget> _feedingSummary(BuildContext context, List<PlantNote> notes) {
    final feedingNotes =
        notes.where((n) => n.category == NoteCategory.feeding).toList();
    final wateringNotes =
        notes.where((n) => n.category == NoteCategory.watering).toList();
    final ipmNotes =
        notes.where((n) => n.category == NoteCategory.ipm).toList();

    if (feedingNotes.isEmpty && wateringNotes.isEmpty && ipmNotes.isEmpty) {
      return [];
    }

    return [
      Row(children: [
        const Icon(Icons.eco_rounded,
            color: AppColors.growing, size: 16),
        const SizedBox(width: AppSpacing.xs),
        Text('Inputs Summary',
            style: AppTypography.headlineSmall(context)),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.colBorder),
        ),
        child: Column(children: [
          _summaryRow(context, 'Feeding events', '${feedingNotes.length}',
              AppColors.curing),
          _summaryRow(context, 'Watering events', '${wateringNotes.length}',
              AppColors.primary),
          _summaryRow(context, 'IPM applications', '${ipmNotes.length}',
              AppColors.warning),
          if (feedingNotes.isNotEmpty &&
              feedingNotes.any((n) => n.feedingDetails?.ecIn != null)) ...[
            Divider(color: context.colBorder),
            _summaryRow(
              context,
              'Avg EC',
              () {
                final ecs = feedingNotes
                    .where((n) => n.feedingDetails?.ecIn != null)
                    .map((n) => n.feedingDetails!.ecIn!)
                    .toList();
                if (ecs.isEmpty) return '—';
                final avg = ecs.reduce((a, b) => a + b) / ecs.length;
                return avg.toStringAsFixed(2);
              }(),
              context.colTextSecondary,
            ),
          ],
        ]),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  Widget _summaryRow(
      BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium(context)),
          Text(value,
              style: AppTypography.labelLarge(context).copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _recommendationRow(BuildContext context, String rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: AppColors.primary, size: 14),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
              child: Text(rec,
                  style: AppTypography.bodyMedium(context)
                      .copyWith(color: context.colTextPrimary))),
        ],
      ),
    );
  }

  Widget _noteSummary(BuildContext context, List<PlantNote> notes) {
    final counts = <NoteCategory, int>{};
    for (final n in notes) {
      counts[n.category] = (counts[n.category] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colSurface1,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.colBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_note_rounded,
                color: context.colTextMuted, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text('No notes logged during this grow.',
                style: AppTypography.bodyMedium(context)
                    .copyWith(color: context.colTextMuted)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.colBorder),
      ),
      child: Column(
        children: counts.entries.map((e) {
          return _summaryRow(
            context,
            e.key.name.substring(0, 1).toUpperCase() + e.key.name.substring(1),
            '${e.value}',
            context.colTextSecondary,
          );
        }).toList(),
      ),
    );
  }

// ── Quality assessment ────────────────────────

  Widget _qualitySection(BuildContext context, HarvestLog? log) {
    if (log == null) return const SizedBox.shrink();

    void openSheet() {
      showModalBottomSheet(
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
            context.read<GrowRepository>().updateHarvestQuality(
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.star_rounded,
                  color: AppColors.harvested, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text('Quality Assessment',
                  style: AppTypography.headlineSmall(context)),
            ]),
            TextButton.icon(
              onPressed: openSheet,
              icon: const Icon(Icons.edit_rounded,
                  size: 14, color: AppColors.primary),
              label: Text(
                log.hasQualityAssessment ? 'Edit' : 'Add',
                style: AppTypography.labelLarge(context)
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (log.hasQualityAssessment) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colSurface1,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border:
                  Border.all(color: AppColors.harvested.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.qualityRating != null) ...[
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        final r = log.qualityRating!;
                        // Match the half-star rendering used in HarvestQualitySheet.
                        final icon = r >= i + 1
                            ? Icons.star_rounded
                            : (r >= i + 0.5
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded);
                        final filled = icon != Icons.star_outline_rounded;
                        return Icon(
                          icon,
                          size: 22,
                          color: filled
                              ? AppColors.harvested
                              : context.colBorder,
                        );
                      }),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${log.qualityRating!.toStringAsFixed(1)}/5',
                        style: AppTypography.labelSmall(context)
                            .copyWith(color: AppColors.harvested),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (log.aromaNote != null)
                  _qualityRow(context, 'Aroma', log.aromaNote!),
                if (log.flavorNotes != null)
                  _qualityRow(context, 'Flavor', log.flavorNotes!),
                if (log.effectNotes != null)
                  _qualityRow(context, 'Effects', log.effectNotes!),
              ],
            ),
          ),
        ] else
          // ── CTA card ────────────────────────────────────────────
          //
          // Quality assessment is easy to miss — the "Add" link in the
          // section header is small.  This card is the discovery
          // surface that turns a passing glance into an action: it
          // explains what the feature is for and gives a full-width
          // button that opens the same sheet.  Mirrors the gold/
          // harvest accent already used by the section title.
          _QualityAssessmentCta(onTap: openSheet),
      ],
    );
  }

  Widget _qualityRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: AppTypography.labelSmall(context)
                  .copyWith(color: context.colTextMuted),
            ),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodySmall(context)),
          ),
        ],
      ),
    );
  }

  // ── Recommendations engine ────────────────────

  List<String> _buildRecommendations({
    required Plant plant,
    required List<PlantNote> notes,
    required List<PlantEnvironmentInsight> insights,
    double? yieldPct,
  }) {
    final recs = <String>[];

    // Env-based
    for (final i in insights) {
      if (i.severity == InsightSeverity.warning) {
        recs.add(i.message);
      }
    }

    // Yield-based
    if (yieldPct != null) {
      if (yieldPct < 18) {
        recs.add(
          'Yield was below 18%. Review your '
          'drying conditions and harvest timing '
          'to improve next grow.',
        );
      } else if (yieldPct >= 25) {
        recs.add(
          'Excellent yield of '
          '${yieldPct.toStringAsFixed(1)}%! '
          'Replicate these conditions next grow.',
        );
      }
    }

    // Issue-based
    final unresolvedIssues = notes
        .where((n) => n.category == NoteCategory.issue && !n.isResolved)
        .toList();
    if (unresolvedIssues.isNotEmpty) {
      recs.add(
        '${unresolvedIssues.length} issue(s) were '
        'left unresolved. Review them before '
        'starting your next grow.',
      );
    }

    // Feeding data
    final hasFeeding = notes.any((n) => n.category == NoteCategory.feeding);
    if (!hasFeeding) {
      recs.add(
        'No feeding events were logged. '
        'Recording feeds helps correlate '
        'inputs with yield outcomes.',
      );
    }

    return recs;
  }

  // ── PDF export ────────────────────────────────

  // ── PDF bytes builder (shared by export and share) ───

  Future<Uint8List> _buildPdfBytes({
    required Plant plant,
    required HarvestLog? harvestLog,
    required List<PlantNote> notes,
    required GrowSpace? space,
    required List<String> recommendations,
    required int daysTotal,
    required double? yieldPct,
  }) async {
    final doc = pw.Document();

    // Build grow timeline rows
    final timelineRows = <List<String>>[
      ['Event', 'Date', 'Days In'],
      ['Seed / Clone Start', _pdfDate(plant.startDate), '0'],
    ];
    if (plant.isAutoflower) {
      timelineRows.add([
        'Type',
        'Autoflower — no flip needed',
        '—',
      ]);
    } else if (plant.flipDate != null) {
      timelineRows.add([
        'Flip to Flower',
        _pdfDate(plant.flipDate!),
        '${plant.flipDate!.difference(plant.startDate).inDays}',
      ]);
    }
    if (plant.harvestedDate != null) {
      timelineRows.add([
        'Harvest',
        _pdfDate(plant.harvestedDate!),
        '${plant.harvestedDate!.difference(plant.startDate).inDays}',
      ]);
    }
    if (plant.dryingEndDate != null) {
      timelineRows.add([
        'Drying Complete',
        _pdfDate(plant.dryingEndDate!),
        '${plant.dryingEndDate!.difference(plant.startDate).inDays}',
      ]);
    }
    if (plant.curingEndDate != null) {
      timelineRows.add([
        'Curing Complete',
        _pdfDate(plant.curingEndDate!),
        '${plant.curingEndDate!.difference(plant.startDate).inDays}',
      ]);
    }

    // Group notes by category for the notes section
    final notesByCategory = <NoteCategory, List<PlantNote>>{};
    for (final n in notes) {
      notesByCategory.putIfAbsent(n.category, () => []).add(n);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          // Title
          pw.Text(
            'Grow Report — ${plant.name}',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: AppSpacing.xs),
          pw.Text(
            '${plant.strain}'
            '${plant.isAutoflower ? ' (Autoflower)' : ''}'
            '${space != null ? ' · ${space.name}' : ''}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: AppSpacing.xxs),
          pw.Text(
            '${_pdfDate(plant.startDate)} → '
            '${plant.archivedAt != null ? _pdfDate(plant.archivedAt!) : 'ongoing'}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.Divider(),
          pw.SizedBox(height: AppSpacing.sm),

          // Stats table
          pw.Text('Key Stats',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: AppSpacing.xs),
          pw.TableHelper.fromTextArray(
            data: [
              ['Metric', 'Value'],
              ['Total Days', '$daysTotal'],
              ['Genetics', plant.isAutoflower ? 'Autoflower' : 'Photoperiod'],
              ['Source', plant.isClone ? 'Clone' : 'Seed'],
              if (harvestLog?.wetWeight != null)
                ['Wet Weight', '${harvestLog!.wetWeight!.toStringAsFixed(1)}g'],
              if (harvestLog?.dryWeight != null)
                ['Dry Weight', '${harvestLog!.dryWeight!.toStringAsFixed(1)}g'],
              if (yieldPct != null)
                ['Yield %', '${yieldPct.toStringAsFixed(1)}%'],
              [
                'Issues Logged',
                '${notes.where((n) => n.category == NoteCategory.issue).length}'
              ],
              [
                'Issues Resolved',
                '${notes.where((n) => n.category == NoteCategory.issue && n.isResolved).length}'
              ],
              [
                'Feeding Events',
                '${notes.where((n) => n.category == NoteCategory.feeding).length}'
              ],
              [
                'Watering Events',
                '${notes.where((n) => n.category == NoteCategory.watering).length}'
              ],
              ['Total Notes', '${notes.length}'],
            ],
          ),
          pw.SizedBox(height: AppSpacing.md),

          // Grow timeline
          pw.Text('Grow Timeline',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: AppSpacing.xs),
          pw.TableHelper.fromTextArray(data: timelineRows),
          pw.SizedBox(height: AppSpacing.md),

          // Issues
          if (notes.any((n) => n.category == NoteCategory.issue)) ...[
            pw.Text('Issue Log',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: AppSpacing.xs),
            ...notes
                .where((n) => n.category == NoteCategory.issue)
                .map((n) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(n.isResolved ? '[✓] ' : '[!] ',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11)),
                          pw.Expanded(
                            child: pw.Text(
                              '${n.issueName ?? 'Issue'}: ${n.content}'
                              '  (${_pdfDate(n.createdAt)})',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    )),
            pw.SizedBox(height: AppSpacing.md),
          ],

          // Quality assessment
          if (harvestLog != null && harvestLog.hasQualityAssessment) ...[
            pw.Text('Quality Assessment',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: AppSpacing.xs),
            if (harvestLog.qualityRating != null)
              pw.Text(
                  'Rating: ${harvestLog.qualityRating!.toStringAsFixed(1)}/5 stars',
                  style: const pw.TextStyle(fontSize: 11)),
            if (harvestLog.aromaNote != null)
              pw.Text('Aroma: ${harvestLog.aromaNote}',
                  style: const pw.TextStyle(fontSize: 11)),
            if (harvestLog.flavorNotes != null)
              pw.Text('Flavor: ${harvestLog.flavorNotes}',
                  style: const pw.TextStyle(fontSize: 11)),
            if (harvestLog.effectNotes != null)
              pw.Text('Effects: ${harvestLog.effectNotes}',
                  style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: AppSpacing.md),
          ],

          // Recommendations
          if (recommendations.isNotEmpty) ...[
            pw.Text('Recommendations for Next Grow',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: AppSpacing.xs),
            ...recommendations.map((r) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text('• $r',
                      style: const pw.TextStyle(fontSize: 11)),
                )),
            pw.SizedBox(height: AppSpacing.md),
          ],

          // Full note log
          if (notes.isNotEmpty) ...[
            pw.Text('Full Note Log',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: AppSpacing.xs),
            ...notesByCategory.entries.expand((entry) {
              final catName = entry.key.name.substring(0, 1).toUpperCase() +
                  entry.key.name.substring(1);
              return [
                pw.Text(catName,
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: AppSpacing.xxs),
                ...entry.value.map((n) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 5, left: 8),
                      child: pw.Text(
                        '[${_pdfDate(n.createdAt)}] ${n.content}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    )),
                pw.SizedBox(height: AppSpacing.sm),
              ];
            }),
          ],
        ],
      ),
    );

    return doc.save();
  }

  String _pdfDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  // ── PDF export (print / download) ─────────────

  Future<void> _exportPdf({
    required BuildContext context,
    required Plant plant,
    required HarvestLog? harvestLog,
    required List<PlantNote> notes,
    required GrowSpace? space,
    required List<PlantEnvironmentInsight> insights,
    required List<String> recommendations,
    required int daysTotal,
    required double? yieldPct,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildPdfBytes(
        plant: plant,
        harvestLog: harvestLog,
        notes: notes,
        space: space,
        recommendations: recommendations,
        daysTotal: daysTotal,
        yieldPct: yieldPct,
      ),
      name: 'grow_report_${plant.name.replaceAll(' ', '_')}.pdf',
    );
  }

  // ── Helpers ───────────────────────────────────

  String _shortDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year.toString().substring(2)}';
  }

  void _viewPhoto(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                File(path),
                semanticLabel: 'Plant photo',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Community benchmark section ───────────────────────────────────────────────
// Self-loading widget: fetches yield + diary stats in parallel, renders when
// data is available, returns SizedBox.shrink() while loading or when the
// strain hasn't reached the 5-submission minimum.

class _CommunitySection extends StatefulWidget {
  final String strainName;

  /// The user's dry weight for the percentile banner. May be null when the
  /// harvest log has no dry weight recorded yet.
  final double? dryWeightGrams;

  const _CommunitySection({
    required this.strainName,
    this.dryWeightGrams,
  });

  @override
  State<_CommunitySection> createState() => _CommunitySectionState();
}

class _CommunitySectionState extends State<_CommunitySection> {
  StrainCommunityStats? _stats;
  GrowDiaryStats? _diaryStats;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      CommunityService.fetchStats(widget.strainName),
      CommunityService.fetchDiaryStats(widget.strainName),
    ]);
    if (!mounted) return;
    setState(() {
      _stats      = results[0] as StrainCommunityStats?;
      _diaryStats = results[1] as GrowDiaryStats?;
      _loaded     = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_stats == null && _diaryStats == null) return const SizedBox.shrink();

    final dw = widget.dryWeightGrams;
    final hasPercentile = _stats != null && dw != null && dw > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──
        Row(children: [
          const Icon(Icons.people_rounded,
              color: AppColors.secondary, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text('Community Benchmark',
              style: AppTypography.headlineSmall(context)),
          const Spacer(),
          if (_stats != null)
            Text(
              '${_stats!.sampleCount} grows',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted),
            ),
        ]),
        const SizedBox(height: AppSpacing.sm),

        // ── Data card ──
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colSurface1,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: context.colBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Percentile banner — only when we have both the community
              // distribution and the user's dry weight.
              if (hasPercentile) ...[
                _percentileBanner(context, _stats!, dw),
                Divider(color: context.colBorder, height: AppSpacing.lg),
              ],

              // Yield distribution from strain_community_stats.
              if (_stats != null) ...[
                _row(context, 'Median yield',
                    '${_stats!.medianGrams.toStringAsFixed(0)}g',
                    AppColors.harvested),
                _row(context, 'Community range',
                    '${_stats!.p25Grams.toStringAsFixed(0)}g'
                    ' – ${_stats!.p75Grams.toStringAsFixed(0)}g',
                    context.colTextSecondary),
              ],

              // Grow-context rows from strain_grow_stats (diary entries).
              if (_diaryStats?.topMedium != null)
                _row(context, 'Most common medium',
                    GrowDiaryStats.mediumLabel(_diaryStats!.topMedium!),
                    AppColors.growing),
              if (_diaryStats?.topLightType != null)
                _row(context, 'Most common light',
                    GrowDiaryStats.lightLabel(_diaryStats!.topLightType!),
                    AppColors.secondary),
              if (_diaryStats?.avgFlowerDays != null)
                _row(context, 'Avg flower time',
                    '${_diaryStats!.avgFlowerDays} days',
                    AppColors.primary),
              if (_diaryStats?.avgVegDays != null)
                _row(context, 'Avg veg time',
                    '${_diaryStats!.avgVegDays} days',
                    AppColors.primary),
              if (_diaryStats?.avgQualityRating != null)
                _row(context, 'Avg community rating',
                    '${_diaryStats!.avgQualityRating!.toStringAsFixed(1)} / 5',
                    AppColors.harvested),
            ],
          ),
        ),

        // Bottom gap so HealthScoreCard below has breathing room.
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  // ── Percentile banner ───────────────────────────────────────────────────────

  Widget _percentileBanner(
    BuildContext context,
    StrainCommunityStats stats,
    double? dw,
  ) {
    if (dw == null) return const SizedBox.shrink();
    final pct = stats.classify(dw);

    final Color color;
    final String label;
    final String detail;

    switch (pct) {
      case CommunityPercentile.top25:
        color  = AppColors.growing;
        label  = 'Top 25%';
        detail = 'Your yield beats 75% of community grows for this strain';
      case CommunityPercentile.p50to75:
        color  = AppColors.primary;
        label  = 'Above Average';
        detail = 'Your yield is in the top half for this strain';
      case CommunityPercentile.p25to50:
        color  = AppColors.harvested;
        label  = 'Around Average';
        detail = 'Your yield is close to the community median';
      case CommunityPercentile.bottom25:
        color  = AppColors.warning;
        label  = 'Below Median';
        detail = 'Your yield was below the median — try different conditions next run';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              label,
              style: AppTypography.labelSmall(context)
                  .copyWith(color: color),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              detail,
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Row helper ──────────────────────────────────────────────────────────────

  Widget _row(
          BuildContext context, String label, String value, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.bodyMedium(context)),
            Text(value,
                style: AppTypography.labelLarge(context)
                    .copyWith(color: color)),
          ],
        ),
      );
}

// ── Photo entry model ─────────────────────────────

class _PhotoEntry {
  final String path;
  final DateTime date;
  final String label;

  const _PhotoEntry({
    required this.path,
    required this.date,
    required this.label,
  });
}

// ── Quality assessment CTA ────────────────────────────────────────────────────
//
// Inline discoverability surface shown on the Grow Report when the user
// hasn't rated their harvest yet.  The "Add" link in the section header
// is small and easy to skip past — this card spells out the payoff
// ("rate aroma, flavor, effects, bag appeal") and gives a full-width
// button so the action is unmissable.  Once the user submits a rating
// the card is replaced by the populated quality summary block.
class _QualityAssessmentCta extends StatelessWidget {
  final VoidCallback onTap;

  const _QualityAssessmentCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.harvested.withValues(alpha: 0.18),
            AppColors.harvested.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border:
            Border.all(color: AppColors.harvested.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.harvested.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 18, color: AppColors.harvested),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate this harvest',
                      style: AppTypography.labelLarge(context)
                          .copyWith(color: AppColors.harvested),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Capture aroma, flavor, effects and bag appeal '
                      'while it\'s fresh — Kultivar uses these notes '
                      'to surface your best grows over time.',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.star_rounded, size: 18),
              label: const Text('Start quality assessment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.harvested,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
