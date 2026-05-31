import 'package:flutter/material.dart';

import '../models/harvest_log.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ── Half-star tap row ─────────────────────────────────────────────────────────
//
// Renders 5 stars where each star has TWO tap zones — left half = +0.5,
// right half = +1.0.  Tapping a star's right-hand side at its current
// rating clears the score; tapping the left half toggles half-and-half
// vs whole.  This matches the iOS Music / Apple TV rating UI growers
// expect on mobile.
class HalfStarRow extends StatelessWidget {
  final double? rating; // 0.5–5.0 in 0.5 steps, or null
  final double iconSize;
  final Color color;
  final ValueChanged<double?> onChanged;

  /// When true, hover/tap animates the star.  Set false on disabled rows.
  final bool animated;

  const HalfStarRow({
    super.key,
    required this.rating,
    required this.onChanged,
    this.color = AppColors.harvested,
    this.iconSize = 32,
    this.animated = true,
  });

  /// Map a star slot (0..4) and the new tap value to the resulting rating.
  /// Returns null when tapping the same position clears it.
  double? _resolveTap(int starIndex, bool leftHalf) {
    final tappedValue = starIndex + (leftHalf ? 0.5 : 1.0);
    // Tap the exact current rating → clear it (toggle off).
    if (rating == tappedValue) return null;
    return tappedValue;
  }

  /// Render the icon for star slot [i] based on the current [rating].
  /// Full = rating ≥ i+1, half = rating ≥ i+0.5 but < i+1, else empty.
  IconData _iconForStar(int i) {
    final r = rating;
    if (r == null) return Icons.star_outline_rounded;
    if (r >= i + 1) return Icons.star_rounded;
    if (r >= i + 0.5) return Icons.star_half_rounded;
    return Icons.star_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    // A10 — accessibility for the half-star rating.  Individual tap
    // zones are ~iconSize/2 wide (≤ 16 px on sub-scores), below
    // WCAG 2.5.5's 44 pt target.  Wrapping the whole row in a
    // Semantics node with `slider: true` + a numeric value lets
    // screen readers and switch-control users adjust the rating
    // through accessible controls instead of trying to hit a 16 px
    // half-star — the visual touch interaction is preserved for
    // sighted users.
    // Pre-compute the announced strings so `value` / `increasedValue` /
    // `decreasedValue` stay in lock-step — Flutter asserts that all
    // three are either set together or all empty when `onIncrease` /
    // `onDecrease` are present.
    String stars(double v) => '${v.toStringAsFixed(1)} stars out of 5';
    final current = rating;
    final increased = ((current ?? 0) + 0.5).clamp(0.5, 5.0);
    final decreased = current == null || current <= 0.5
        ? 0.0
        : current - 0.5;
    return Semantics(
      container: true,
      slider: true,
      label: 'Rating',
      value: current == null ? 'No rating' : stars(current),
      increasedValue: stars(increased),
      decreasedValue:
          decreased == 0.0 ? 'No rating' : stars(decreased),
      onIncrease: () => onChanged(increased),
      onDecrease: () => onChanged(decreased == 0.0 ? null : decreased),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final icon = _iconForStar(i);
            final filled = icon != Icons.star_outline_rounded;
            final star = Icon(
              icon,
              size: iconSize,
              color: filled ? color : context.colBorder,
            );

            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xxs),
              child: animated
                  ? TweenAnimationBuilder<double>(
                      key: ValueKey('star_${i}_$icon'),
                      tween: Tween(begin: 1.35, end: 1.0),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.elasticOut,
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: _tapZones(i, star),
                    )
                  : _tapZones(i, star),
            );
          }),
        ),
      ),
    );
  }

  /// Two half-width tap regions stacked over [star].  Left half writes
  /// rating = i + 0.5, right half writes rating = i + 1.0.
  Widget _tapZones(int starIndex, Widget star) {
    return Stack(
      alignment: Alignment.center,
      children: [
        star,
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => onChanged(_resolveTap(starIndex, true)),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => onChanged(_resolveTap(starIndex, false)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sub-score row ─────────────────────────────────────────────────────────────

class _SubScoreRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final double? rating;
  final Color color;
  final void Function(double?) onChanged;

  const _SubScoreRow({
    required this.label,
    required this.icon,
    required this.rating,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 84,
          child: Text(label,
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextSecondary)),
        ),
        HalfStarRow(
          rating: rating,
          color: color,
          iconSize: 22,
          animated: false, // sub-scores are subtle; full bounce reserved for the main one
          onChanged: onChanged,
        ),
        if (rating != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text('${rating!.toStringAsFixed(1)}/5',
              style: AppTypography.labelSmall(context)
                  .copyWith(color: color, fontSize: 10)),
        ],
      ],
    );
  }
}

class HarvestQualitySheet extends StatefulWidget {
  final HarvestLog harvestLog;
  final void Function({
    required double? qualityRating,
    required String? aromaNote,
    required String? flavorNotes,
    required String? effectNotes,
    required double? smellRating,
    required double? effectRating,
    required double? bagAppealRating,
  }) onSave;

  const HarvestQualitySheet({
    super.key,
    required this.harvestLog,
    required this.onSave,
  });

  @override
  State<HarvestQualitySheet> createState() => _HarvestQualitySheetState();
}

class _HarvestQualitySheetState extends State<HarvestQualitySheet> {
  late double? _rating;
  late double? _smellRating;
  late double? _effectRating;
  late double? _bagAppealRating;
  late TextEditingController _aromaCtrl;
  late TextEditingController _flavorCtrl;
  late TextEditingController _effectsCtrl;

  @override
  void initState() {
    super.initState();
    final log = widget.harvestLog;
    _rating = log.qualityRating;
    _smellRating = log.smellRating;
    _effectRating = log.effectRating;
    _bagAppealRating = log.bagAppealRating;
    _aromaCtrl = TextEditingController(text: log.aromaNote ?? '');
    _flavorCtrl = TextEditingController(text: log.flavorNotes ?? '');
    _effectsCtrl = TextEditingController(text: log.effectNotes ?? '');
  }

  @override
  void dispose() {
    _aromaCtrl.dispose();
    _flavorCtrl.dispose();
    _effectsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ───────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: context.colBorder,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),

            // ── Header ──────────────────────────
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.harvested.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded,
                    color: AppColors.harvested, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quality Assessment',
                        style: AppTypography.headlineMedium(context)),
                    Text(
                      widget.harvestLog.strain,
                      style: AppTypography.bodySmall(context),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),

            // ── Overall star rating ─────────────
            Row(
              children: [
                Text('Overall Rating',
                    style: AppTypography.labelLarge(context)),
                const Spacer(),
                if (_rating != null)
                  Text('${_rating!.toStringAsFixed(1)} / 5',
                      style: AppTypography.labelSmall(context)
                          .copyWith(color: AppColors.harvested)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Half-star precision: tap a star's left half for X.5, right
            // half for X.0.  Tapping the current rating clears it.
            HalfStarRow(
              rating: _rating,
              color: AppColors.harvested,
              onChanged: (v) => setState(() => _rating = v),
            ),
            Text(
              'Tip: tap the left half of a star for half-points.',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: context.colTextMuted, fontSize: 11),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Sub-scores ───────────────────────
            Text('Sub-scores (optional)',
                style: AppTypography.labelLarge(context)),
            const SizedBox(height: AppSpacing.sm),
            _SubScoreRow(
              label: 'Smell',
              icon: Icons.air_rounded,
              rating: _smellRating,
              color: AppColors.info,
              onChanged: (v) => setState(() => _smellRating = v),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SubScoreRow(
              label: 'Effect',
              icon: Icons.psychology_rounded,
              rating: _effectRating,
              color: AppColors.training,
              onChanged: (v) => setState(() => _effectRating = v),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SubScoreRow(
              label: 'Bag Appeal',
              icon: Icons.visibility_rounded,
              rating: _bagAppealRating,
              color: AppColors.secondary,
              onChanged: (v) => setState(() => _bagAppealRating = v),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Aroma ───────────────────────────
            TextField(
              controller: _aromaCtrl,
              style: TextStyle(color: context.colTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Aroma',
                hintText: 'e.g. citrus, pine, earthy…',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Flavor ──────────────────────────
            TextField(
              controller: _flavorCtrl,
              style: TextStyle(color: context.colTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Flavor',
                hintText: 'e.g. sweet, spicy, floral…',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Effects ─────────────────────────
            TextField(
              controller: _effectsCtrl,
              maxLines: 2,
              style: TextStyle(color: context.colTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Effects',
                hintText: 'e.g. relaxing, uplifting, cerebral…',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Save ────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave(
                    qualityRating: _rating,
                    aromaNote: _aromaCtrl.text.trim().isEmpty
                        ? null
                        : _aromaCtrl.text.trim(),
                    flavorNotes: _flavorCtrl.text.trim().isEmpty
                        ? null
                        : _flavorCtrl.text.trim(),
                    effectNotes: _effectsCtrl.text.trim().isEmpty
                        ? null
                        : _effectsCtrl.text.trim(),
                    smellRating: _smellRating,
                    effectRating: _effectRating,
                    bagAppealRating: _bagAppealRating,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.harvested,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: const Text('Save Quality',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
