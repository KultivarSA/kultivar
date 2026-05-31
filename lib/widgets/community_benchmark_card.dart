import 'dart:math';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/grow_diary_stats.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../models/strain_community_stats.dart';
import '../services/community_service.dart';
import '../services/ui_preferences_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'harvest_quality_sheet.dart' show HalfStarRow;
import 'skeleton.dart';

// ── Load state ─────────────────────────────────────────────────────────────

enum _LoadState { loading, done }

// ── Public widget ──────────────────────────────────────────────────────────

/// Shows anonymous community benchmarks for the plant's strain alongside a
/// one-time opt-in prompt to contribute the user's own harvest data.
///
/// Renders nothing when:
///  • the plant has no dry weight yet, OR
///  • loading is complete, stats are unavailable, AND the user already
///    answered the sharing prompt (opted in or declined).
///
/// Usage:
/// ```dart
/// CommunityBenchmarkCard(
///   plant: currentPlant,
///   harvestLog: repo.harvestLogs
///       .where((l) => l.plantId == currentPlant.id)
///       .firstOrNull,
/// )
/// ```
class CommunityBenchmarkCard extends StatefulWidget {
  final Plant plant;

  /// The harvest log for this plant. Required for data submission — the card
  /// shows the benchmark comparison regardless, but the consent prompt is
  /// only shown when a log with a positive dry weight is available.
  final HarvestLog? harvestLog;

  /// All notes for this plant. Used to extract training techniques that were
  /// applied during the grow so they can be included in the benchmark submission.
  final List<PlantNote> notes;

  const CommunityBenchmarkCard({
    super.key,
    required this.plant,
    this.harvestLog,
    this.notes = const [],
  });

  @override
  State<CommunityBenchmarkCard> createState() => _CommunityBenchmarkCardState();
}

class _CommunityBenchmarkCardState extends State<CommunityBenchmarkCard> {
  _LoadState _loadState = _LoadState.loading;
  StrainCommunityStats? _stats;

  // null  = never asked (show prompt)
  // true  = opted in
  // false = declined (never ask again)
  bool? _shareConsent;

  bool _submitting  = false;
  bool _submitted   = false;

  // True once basic yield sharing succeeded — triggers the optional diary form.
  bool _showDiaryForm = false;
  // True once the diary form was submitted OR skipped.
  bool _diaryDone     = false;

  String? _appVersion;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Best dry weight to use for the comparison bar.
  double? get _dryGrams {
    final fromLog = widget.harvestLog?.dryWeight;
    if (fromLog != null && fromLog > 0) return fromLog;
    final fromPlant = widget.plant.dryWeight;
    if (fromPlant != null && fromPlant > 0) return fromPlant;
    return null;
  }

  /// True when we have enough information to submit to Supabase.
  bool get _canSubmit =>
      widget.harvestLog != null &&
      (widget.harvestLog!.dryWeight ?? 0) > 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CommunityBenchmarkCard old) {
    super.didUpdateWidget(old);
    // Reload if the strain changes (e.g. user edits the plant).
    if (old.plant.strain != widget.plant.strain) {
      setState(() {
        _stats     = null;
        _loadState = _LoadState.loading;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final results = await Future.wait([
      CommunityService.fetchStats(widget.plant.strain),
      UiPreferencesService.loadCommunityShareEnabled(),
      PackageInfo.fromPlatform(),
    ]);
    if (!mounted) return;
    final info = results[2] as PackageInfo;
    setState(() {
      _stats        = results[0] as StrainCommunityStats?;
      _shareConsent = results[1] as bool?;
      _appVersion   = '${info.version}+${info.buildNumber}';
      _loadState    = _LoadState.done;
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _onShare() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await UiPreferencesService.saveCommunityShareEnabled(true);
    final ok = await CommunityService.submitBenchmark(
      plant:      widget.plant,
      log:        widget.harvestLog!,
      notes:      widget.notes,
      appVersion: _appVersion,
    );
    if (!mounted) return;
    setState(() {
      _submitting     = false;
      _submitted      = ok;
      _shareConsent   = true;
      // Only show diary form when basic submission succeeded and we have
      // a valid harvest log to pull context from.
      _showDiaryForm  = ok && _canSubmit;
    });
  }

  Future<void> _onDecline() async {
    await UiPreferencesService.saveCommunityShareEnabled(false);
    if (!mounted) return;
    setState(() => _shareConsent = false);
  }

  /// Opens the grow-details diary form in a full bottom sheet.
  void _openDiarySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: ctx.colSurface1,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLg)),
          ),
          child: Column(
            children: [
              // ── Handle ────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.colBorder,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
              // ── Sheet header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding, AppSpacing.xs,
                  AppSpacing.pagePadding, 0,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: AppColors.secondary, size: 17),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Grow Details',
                              style: AppTypography.headlineMedium(ctx)),
                          Text(
                            widget.plant.strain,
                            style: AppTypography.bodySmall(ctx),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        'optional',
                        style: AppTypography.labelSmall(ctx)
                            .copyWith(color: AppColors.secondary, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                  height: AppSpacing.lg,
                  color: ctx.colBorderFaint),
              // ── Scrollable form ────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding, 0,
                    AppSpacing.pagePadding, AppSpacing.xl,
                  ),
                  child: _DiaryForm(
                    plant:      widget.plant,
                    harvestLog: widget.harvestLog!,
                    appVersion: _appVersion,
                    inSheet:    true,
                    onDone: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _showDiaryForm = false;
                        _diaryDone     = true;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dry = _dryGrams;
    if (dry == null) return const SizedBox.shrink();

    if (_loadState == _LoadState.loading) {
      return _LoadingPlaceholder();
    }

    final showConsent = _shareConsent == null && _canSubmit;
    final stats = _stats;

    // Nothing useful to render.
    if (stats == null && !showConsent) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          _Header(
            strain:      widget.plant.strain,
            sampleCount: stats?.sampleCount,
          ),

          // ── Comparison bar ─────────────────────────────────────────────
          if (stats != null) ...[
            const SizedBox(height: AppSpacing.md),
            _PercentileBar(stats: stats, userGrams: dry),
            const SizedBox(height: AppSpacing.xs),
            _StatsRow(stats: stats, userGrams: dry),
          ] else ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No community data yet for this strain.',
              style: AppTypography.bodySmall(context),
            ),
          ],

          // ── Consent / contributed ───────────────────────────────────────
          if (showConsent) ...[
            const SizedBox(height: AppSpacing.md),
            _ConsentSection(
              strainName: widget.plant.strain,
              hasStats:   stats != null,
              submitting: _submitting,
              submitted:  _submitted,
              onShare:    _onShare,
              onDecline:  _onDecline,
            ),
          ] else if (_shareConsent == true && !_showDiaryForm) ...[
            const SizedBox(height: AppSpacing.sm),
            _ContributedBadge(),
          ],

          // ── Optional grow-details diary form ────────────────────────────
          // After the basic benchmark is shared we offer an "Add details"
          // button that opens the diary form in a full bottom sheet — gives
          // the form room to breathe and keeps the benchmark card compact.
          if (_showDiaryForm && !_diaryDone && widget.harvestLog != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _AddDetailsRow(
              onTap: () => _openDiarySheet(context),
            ),
          ] else if (_diaryDone) ...[
            const SizedBox(height: AppSpacing.sm),
            _ContributedBadge(),
          ],
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String strain;
  final int? sampleCount;

  const _Header({required this.strain, this.sampleCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.people_rounded,
            color: AppColors.secondary,
            size: 17,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Community Benchmarks',
                style: AppTypography.headlineSmall(context),
              ),
              Text(
                strain,
                style: AppTypography.bodySmall(context),
              ),
            ],
          ),
        ),
        if (sampleCount != null)
          _Chip(
            label: '$sampleCount grows',
            color: AppColors.secondary,
          ),
      ],
    );
  }
}

// ── Percentile bar ─────────────────────────────────────────────────────────

class _PercentileBar extends StatelessWidget {
  final StrainCommunityStats stats;

  /// When non-null, a coloured dot is drawn at this position on the bar.
  final double? userGrams;

  const _PercentileBar({required this.stats, this.userGrams});

  Color? get _userColor {
    if (userGrams == null) return null;
    return switch (stats.classify(userGrams!)) {
      CommunityPercentile.top25     => AppColors.growing,
      CommunityPercentile.p50to75   => AppColors.growing,
      CommunityPercentile.p25to50   => AppColors.warning,
      CommunityPercentile.bottom25  => AppColors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: CustomPaint(
        painter: _BarPainter(
          p25:         stats.p25Grams,
          median:      stats.medianGrams,
          p75:         stats.p75Grams,
          userValue:   userGrams,
          trackColor:  context.colSurface3,
          iqrColor:    AppColors.secondary.withValues(alpha: 0.22),
          medianColor: AppColors.secondary,
          userColor:   _userColor,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double p25, median, p75;

  /// When null, no user indicator is drawn (read-only community view).
  final double? userValue;
  final Color trackColor, iqrColor, medianColor;
  final Color? userColor;

  _BarPainter({
    required this.p25,
    required this.median,
    required this.p75,
    this.userValue,
    required this.trackColor,
    required this.iqrColor,
    required this.medianColor,
    this.userColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Guard against degenerate data.
    final uv = userValue;
    final rangeMax = uv != null
        ? max(p75 * 1.6, uv * 1.15)
        : p75 * 1.6;
    if (rangeMax <= 0) return;

    const hPad      = 6.0;
    final drawW     = size.width - hPad * 2;
    final centerY   = size.height / 2;
    const trackH    = 8.0;
    const trackR    = trackH / 2;

    double xOf(double v) =>
        hPad + (v.clamp(0, rangeMax) / rangeMax) * drawW;

    // ── Track ─────────────────────────────────────────────────────────────
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(hPad, centerY - trackH / 2, drawW, trackH),
      const Radius.circular(trackR),
    );
    canvas.drawRRect(trackRect, trackPaint);

    // ── IQR fill (p25 → p75) ─────────────────────────────────────────────
    final iqrPaint = Paint()
      ..color = iqrColor
      ..style = PaintingStyle.fill;
    final iqrLeft  = xOf(p25);
    final iqrRight = xOf(p75);
    final iqrRect  = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        iqrLeft,
        centerY - trackH / 2,
        iqrRight - iqrLeft,
        trackH,
      ),
      const Radius.circular(trackR),
    );
    canvas.drawRRect(iqrRect, iqrPaint);

    // ── Median tick ───────────────────────────────────────────────────────
    final medPaint = Paint()
      ..color = medianColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final medX = xOf(median);
    canvas.drawLine(
      Offset(medX, centerY - trackH),
      Offset(medX, centerY + trackH),
      medPaint,
    );

    // ── User value indicator (optional) ──────────────────────────────────
    if (uv != null && userColor != null) {
      final userX = xOf(uv);
      final uc = userColor!;

      // Vertical stem
      canvas.drawLine(
        Offset(userX, centerY - trackH - 4),
        Offset(userX, centerY + trackH + 4),
        Paint()
          ..color = uc
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );

      // Filled circle
      canvas.drawCircle(Offset(userX, centerY), 7,
          Paint()..color = uc..style = PaintingStyle.fill);

      // White inner dot
      canvas.drawCircle(Offset(userX, centerY), 3,
          Paint()..color = Colors.white..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.userValue   != userValue  ||
      old.p25         != p25        ||
      old.median      != median     ||
      old.p75         != p75        ||
      old.trackColor  != trackColor ||
      old.iqrColor    != iqrColor;
}

// ── Stats row ──────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final StrainCommunityStats stats;

  /// When non-null, a percentile chip is shown for this value.
  final double? userGrams;

  /// Optional label prefix for the chip (e.g. "Yours" or "Your avg").
  final String userLabel;

  const _StatsRow({
    required this.stats,
    this.userGrams,
    this.userLabel = 'Yours',
  });

  @override
  Widget build(BuildContext context) {
    final uv = userGrams;
    Color? chipColor;
    String? chipText;

    if (uv != null) {
      final percentile = stats.classify(uv);
      chipColor = switch (percentile) {
        CommunityPercentile.top25    => AppColors.growing,
        CommunityPercentile.p50to75  => AppColors.growing,
        CommunityPercentile.p25to50  => AppColors.warning,
        CommunityPercentile.bottom25 => AppColors.danger,
      };
      chipText = '$userLabel: ${uv.toStringAsFixed(0)}g · ${stats.percentileLabel(uv)}';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: 4,
            children: [
              _StatPip(label: 'p25',    value: '${stats.p25Grams.toStringAsFixed(0)}g'),
              _StatPip(label: 'Median', value: '${stats.medianGrams.toStringAsFixed(0)}g'),
              _StatPip(label: 'p75',    value: '${stats.p75Grams.toStringAsFixed(0)}g'),
            ],
          ),
        ),
        if (chipText != null && chipColor != null) ...[
          const SizedBox(width: AppSpacing.sm),
          _Chip(label: chipText, color: chipColor),
        ],
      ],
    );
  }
}

class _StatPip extends StatelessWidget {
  final String label;
  final String value;

  const _StatPip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.bodySmall(context)),
        Text(value, style: AppTypography.labelLarge(context)),
      ],
    );
  }
}

// ── Diary form ─────────────────────────────────────────────────────────────
//
// Optional second step shown after the basic yield share succeeds.
// Collects medium, light type, and training techniques for the richer
// grow_diary_entries table. All selections are optional; tapping Skip
// is always available.

class _DiaryForm extends StatefulWidget {
  final Plant plant;
  final HarvestLog harvestLog;
  final String? appVersion;

  /// When true the outer card container is suppressed — used when the form
  /// is hosted inside a bottom sheet that provides its own chrome.
  final bool inSheet;

  /// Called whether the user submitted details or tapped Skip.
  final VoidCallback onDone;

  const _DiaryForm({
    required this.plant,
    required this.harvestLog,
    required this.onDone,
    this.appVersion,
    this.inSheet = false,
  });

  @override
  State<_DiaryForm> createState() => _DiaryFormState();
}

class _DiaryFormState extends State<_DiaryForm> {
  static const _mediums = ['soil', 'coco', 'hydro', 'living_soil', 'other'];
  static const _lights  = ['led', 'hps', 'cmh', 'fluorescent', 'other'];
  static const _techniqueOptions = [
    'LST', 'Topping', 'FIMming', 'Defoliation',
    'Super Cropping', 'SCROG', 'SOG', 'Other',
  ];

  String?      _medium;
  String?      _lightType;
  final Set<String> _techniques = {};
  double?      _qualityRating; // 0.5–5.0 in 0.5 steps, pre-filled from harvest log
  bool         _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from the plant's saved setup so growers don't re-select
    // the same medium/light on every harvest.
    _medium      = widget.plant.medium;
    _lightType   = widget.plant.lightType;
    // Pre-fill from the quality assessment the user already gave this harvest.
    _qualityRating = widget.harvestLog.qualityRating;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await CommunityService.submitDiaryEntry(
      plant:         widget.plant,
      log:           widget.harvestLog,
      medium:        _medium,
      lightType:     _lightType,
      techniques:    _techniques.toList(),
      qualityRating: _qualityRating,
      appVersion:    widget.appVersion,
    );
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row — hidden when hosted in a sheet (sheet provides its own header).
        if (!widget.inSheet) ...[
          Row(children: [
            const Icon(Icons.tune_rounded,
                color: AppColors.secondary, size: 14),
            const SizedBox(width: AppSpacing.xs),
            Text('Add grow details?',
                style: AppTypography.labelLarge(context)),
            const Spacer(),
            Text('optional',
                style: AppTypography.bodySmall(context)
                    .copyWith(color: context.colTextMuted)),
          ]),
          const SizedBox(height: AppSpacing.sm),
        ],

        // ── Quality rating ───────────────────────────────────────────────
        Text('QUALITY RATING',
            style: AppTypography.labelSmall(context)
                .copyWith(letterSpacing: 0.6)),
        const SizedBox(height: 5),
        Row(
          children: [
            // Reuse the half-star tap-row from HarvestQualitySheet so the
            // community submission flow matches the local rating UI exactly.
            HalfStarRow(
              rating: _qualityRating,
              color: AppColors.harvested,
              iconSize: 26,
              animated: false,
              onChanged: (v) => setState(() => _qualityRating = v),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (_qualityRating != null)
              Text(
                _ratingLabel(_qualityRating!),
                style: AppTypography.bodySmall(context)
                    .copyWith(color: AppColors.harvested),
              )
            else
              Text(
                'tap to rate',
                style: AppTypography.bodySmall(context)
                    .copyWith(color: context.colTextMuted),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Medium ───────────────────────────────────────────────────────
        Text('MEDIUM',
            style: AppTypography.labelSmall(context)
                .copyWith(letterSpacing: 0.6)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: _mediums
              .map((m) => _toggle(
                    context,
                    label:    GrowDiaryStats.mediumLabel(m),
                    selected: _medium == m,
                    onTap: () => setState(
                        () => _medium = _medium == m ? null : m),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Light type ────────────────────────────────────────────────────
        Text('LIGHT TYPE',
            style: AppTypography.labelSmall(context)
                .copyWith(letterSpacing: 0.6)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: _lights
              .map((l) => _toggle(
                    context,
                    label:    GrowDiaryStats.lightLabel(l),
                    selected: _lightType == l,
                    onTap: () => setState(
                        () => _lightType = _lightType == l ? null : l),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Training techniques (multi-select) ────────────────────────────
        Text('TRAINING',
            style: AppTypography.labelSmall(context)
                .copyWith(letterSpacing: 0.6)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: _techniqueOptions
              .map((t) => _toggle(
                    context,
                    label:    t,
                    selected: _techniques.contains(t),
                    onTap: () => setState(() => _techniques.contains(t)
                        ? _techniques.remove(t)
                        : _techniques.add(t)),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Actions ────────────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                disabledBackgroundColor:
                    AppColors.secondary.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Submit Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          TextButton(
            onPressed: widget.onDone,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm)),
            child: Text('Skip',
                style: TextStyle(
                    fontSize: 13, color: context.colTextMuted)),
          ),
        ]),
      ],
    );

    // When hosted inside a bottom sheet, render without a card container.
    if (widget.inSheet) return content;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: content,
    );
  }

  static String _ratingLabel(double r) {
    // Round half-stars to the nearest whole-star descriptor so the label
    // remains compact ("Good" not "Good-Very Good").  The numeric value
    // is also shown alongside this label by the caller — see the
    // `${r.toStringAsFixed(1)} / 5` text in the picker.
    final n = r.round();
    switch (n) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      default:
        return 'Excellent';
    }
  }

  Widget _toggle(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondary.withValues(alpha: 0.18)
              : context.colSurface3,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: selected
                ? AppColors.secondary.withValues(alpha: 0.5)
                : context.colBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall(context).copyWith(
            color: selected
                ? AppColors.secondary
                : context.colTextSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ── Consent section ────────────────────────────────────────────────────────

class _ConsentSection extends StatelessWidget {
  final String strainName;
  final bool hasStats;
  final bool submitting;
  final bool submitted;
  final VoidCallback onShare;

  /// Permanently declines — sets the preference to false so the prompt
  /// never appears again (can be re-enabled in Settings → Community).
  final VoidCallback onDecline;

  const _ConsentSection({
    required this.strainName,
    required this.hasStats,
    required this.submitting,
    required this.submitted,
    required this.onShare,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    if (submitted) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.growing, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Shared! Thanks for contributing to the community.',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: AppColors.growing),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.lock_rounded,
                  color: AppColors.secondary, size: 14),
              const SizedBox(width: AppSpacing.xs),
              Text(
                hasStats
                    ? 'Add your harvest to the data?'
                    : 'Be the first to share $strainName?',
                style: AppTypography.labelLarge(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // ── What's shared ──────────────────────────────────────────────
          Text(
            'We\'d share anonymously: dry weight, grow duration, '
            'autoflower/clone flag. No account, name, or location — ever.',
            style: AppTypography.bodySmall(context),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Data points preview
          const Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              _DataPoint(Icons.scale_rounded,        'Dry weight'),
              _DataPoint(Icons.timer_outlined,       'Grow days'),
              _DataPoint(Icons.auto_awesome_rounded, 'Auto / clone'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Buttons ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: submitting ? null : onShare,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    disabledBackgroundColor:
                        AppColors.secondary.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Share Anonymously',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              TextButton(
                onPressed: onDecline,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
                ),
                child: Text(
                  'Never',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colTextMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add details row ────────────────────────────────────────────────────────
//
// Shown after the basic benchmark is shared.  Keeps the card compact while
// offering a clear path to the full diary form bottom sheet.

class _AddDetailsRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddDetailsRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded,
            color: AppColors.growing, size: 16),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Shared!',
            style: AppTypography.bodySmall(context)
                .copyWith(color: AppColors.growing),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add details',
                  style: AppTypography.labelSmall(context).copyWith(
                      color: AppColors.secondary, fontSize: 11),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.chevron_right_rounded,
                    size: 13, color: AppColors.secondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Data-point chip ────────────────────────────────────────────────────────
//
// Tiny pill shown in the consent section listing what will be submitted.

class _DataPoint extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DataPoint(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.labelSmall(context)
                .copyWith(color: AppColors.secondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Contributed badge ──────────────────────────────────────────────────────

class _ContributedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded,
            color: AppColors.growing, size: 14),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Your harvest contributed to these stats',
          style: AppTypography.bodySmall(context)
              .copyWith(color: AppColors.growing),
        ),
      ],
    );
  }
}

// ── Loading placeholder ────────────────────────────────────────────────────

// A6 — was a static surface3 placeholder; now uses the shared
// shimmer-pulsing primitive so the card reads as "loading" rather
// than "loaded but empty".  Pre-shaped to the same dimensions as
// the populated card to avoid a layout shift when stats arrive.
class _LoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SkeletonBenchmarkCard();
}

// ── CommunityStrainCard ────────────────────────────────────────────────────
//
// Read-only variant for the Strain Library.  Shows community benchmarks for
// a strain without the consent prompt — that only belongs on a specific
// harvest in PlantDetailScreen.
//
// Usage:
// ```dart
// CommunityStrainCard(
//   strainName: strain.name,
//   userAvgGrams: avgDryWeight,   // from user's own harvest history
// )
// ```

class CommunityStrainCard extends StatefulWidget {
  final String strainName;

  /// User's own average dry weight for this strain.
  /// When provided, marked on the bar and shown as a percentile chip.
  final double? userAvgGrams;

  const CommunityStrainCard({
    super.key,
    required this.strainName,
    this.userAvgGrams,
  });

  @override
  State<CommunityStrainCard> createState() => _CommunityStrainCardState();
}

class _CommunityStrainCardState extends State<CommunityStrainCard> {
  _LoadState        _loadState  = _LoadState.loading;
  StrainCommunityStats? _stats;
  GrowDiaryStats?   _diaryStats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CommunityStrainCard old) {
    super.didUpdateWidget(old);
    if (old.strainName != widget.strainName) {
      setState(() {
        _stats      = null;
        _diaryStats = null;
        _loadState  = _LoadState.loading;
      });
      _load();
    }
  }

  Future<void> _load() async {
    // Fetch both data sets in parallel — diary stats are independent of yield
    // stats and both are non-critical.
    final results = await Future.wait([
      CommunityService.fetchStats(widget.strainName),
      CommunityService.fetchDiaryStats(widget.strainName),
    ]);
    if (!mounted) return;
    setState(() {
      _stats      = results[0] as StrainCommunityStats?;
      _diaryStats = results[1] as GrowDiaryStats?;
      _loadState  = _LoadState.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadState == _LoadState.loading) {
      return _LoadingPlaceholder();
    }

    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          _Header(
            strain:      widget.strainName,
            sampleCount: stats.sampleCount,
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Bar ─────────────────────────────────────────────────────────
          _PercentileBar(
            stats:     stats,
            userGrams: widget.userAvgGrams,
          ),
          const SizedBox(height: AppSpacing.xs),

          // ── Stats labels + optional percentile chip ─────────────────────
          _StatsRow(
            stats:     stats,
            userGrams: widget.userAvgGrams,
            userLabel: 'Your avg',
          ),

          // ── Community grow time (yield stats source) ────────────────────
          if (stats.avgGrowDays != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(color: context.colBorder, height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 13, color: AppColors.secondary),
                const SizedBox(width: 5),
                Text(
                  'Community avg grow: ${stats.avgGrowDays}d',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextSecondary),
                ),
                if (stats.avgVegDays != null ||
                    stats.avgFlowerDays != null) ...[
                  Text('  ·  ', style: AppTypography.bodySmall(context)),
                  if (stats.avgVegDays != null)
                    Text(
                      'veg ${stats.avgVegDays}d',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextMuted),
                    ),
                  if (stats.avgVegDays != null &&
                      stats.avgFlowerDays != null)
                    Text('  /  ', style: AppTypography.bodySmall(context)),
                  if (stats.avgFlowerDays != null)
                    Text(
                      'flower ${stats.avgFlowerDays}d',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextMuted),
                    ),
                ],
              ],
            ),
          ],

          // ── Grow conditions (diary stats source) ────────────────────────
          if (_diaryStats != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(color: context.colBorder, height: 1),
            const SizedBox(height: AppSpacing.sm),
            _DiaryStatsRow(stats: _diaryStats!),
          ],
        ],
      ),
    );
  }
}

// ── Diary stats row ────────────────────────────────────────────────────────
//
// Compact display of grow-condition trends from the strain_grow_stats view.
// Shown at the bottom of CommunityStrainCard when diary data is available.

class _DiaryStatsRow extends StatelessWidget {
  final GrowDiaryStats stats;

  const _DiaryStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final chips = <_DiaryChipData>[];

    // Most common medium
    if (stats.topMedium != null) {
      final pct = _pctForMedium(stats.topMedium!);
      final label = pct != null
          ? '${GrowDiaryStats.mediumLabel(stats.topMedium!)} ${pct.toStringAsFixed(0)}%'
          : GrowDiaryStats.mediumLabel(stats.topMedium!);
      chips.add(_DiaryChipData(Icons.grass_rounded, label));
    }

    // Most common light
    if (stats.topLightType != null) {
      final pct = _pctForLight(stats.topLightType!);
      final label = pct != null
          ? '${GrowDiaryStats.lightLabel(stats.topLightType!)} ${pct.toStringAsFixed(0)}%'
          : GrowDiaryStats.lightLabel(stats.topLightType!);
      chips.add(_DiaryChipData(Icons.wb_sunny_outlined, label));
    }

    // Quality rating
    if (stats.avgQualityRating != null) {
      chips.add(_DiaryChipData(
        Icons.star_rounded,
        '${stats.avgQualityRating!.toStringAsFixed(1)} avg',
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.people_outline_rounded,
              size: 12, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'How ${stats.sampleCount} growers grew it',
            style: AppTypography.labelSmall(context)
                .copyWith(color: AppColors.secondary, fontSize: 10),
          ),
        ]),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: chips
              .map((c) => _diaryChip(context, c.icon, c.label))
              .toList(),
        ),
      ],
    );
  }

  double? _pctForMedium(String key) => switch (key) {
    'soil'  => stats.pctSoil,
    'coco'  => stats.pctCoco,
    'hydro' => stats.pctHydro,
    _       => null,
  };

  double? _pctForLight(String key) => switch (key) {
    'led' => stats.pctLed,
    'hps' => stats.pctHps,
    _     => null,
  };

  Widget _diaryChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.labelSmall(context)
                .copyWith(color: AppColors.secondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _DiaryChipData {
  final IconData icon;
  final String label;
  const _DiaryChipData(this.icon, this.label);
}

// ── Reusable chip ──────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(context).copyWith(color: color),
      ),
    );
  }
}
