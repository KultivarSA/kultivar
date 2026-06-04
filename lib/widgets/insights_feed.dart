import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/insight_engine.dart';

class _UiInsight {
  final Insight insight;
  final IconData icon;
  final Color color;
  final bool isImportant;
  final String explanation;

  _UiInsight({
    required this.insight,
    required this.icon,
    required this.color,
    required this.isImportant,
    required this.explanation,
  });
}

class InsightsFeed extends StatefulWidget {
  final List<Insight> insights;
  final String timeWindowLabel;
  final void Function(String message)? onNotify;

  const InsightsFeed({
    super.key,
    required this.insights,
    required this.timeWindowLabel,
    this.onNotify,
  });

  @override
  State<InsightsFeed> createState() => _InsightsFeedState();
}

class _InsightsFeedState extends State<InsightsFeed> {
  final Set<String> _notifiedMessages = {};
  bool _showAllInsights = false;

  List<_UiInsight> _mapInsights(BuildContext context) {
    return widget.insights.map((i) {
      switch (i.type) {
        case InsightType.positive:
          return _UiInsight(
            insight: i,
            icon: Icons.trending_up,
            color: AppColors.growing,
            isImportant: true,
            explanation:
                'Average yield has increased noticeably compared with the historical baseline.',
          );
        case InsightType.negative:
          return _UiInsight(
            insight: i,
            icon: Icons.trending_down,
            color: AppColors.danger,
            isImportant: true,
            explanation:
                'Recent yield is significantly below expected baseline values.',
          );
        case InsightType.neutral:
          return _UiInsight(
            insight: i,
            icon: Icons.info_outline,
            color: context.colTextMuted,
            isImportant: false,
            explanation:
                'Current performance is within normal historical variation.',
          );
      }
    }).toList();
  }

  @override
  void didUpdateWidget(covariant InsightsFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onNotify == null) return;
    // Bug fix: caller's onNotify typically inserts a toast into the
    // Overlay (AppToast.show -> OverlayState.insert -> setState).
    // didUpdateWidget runs DURING the build phase, so calling
    // setState on the Overlay throws "setState called during build".
    // That exception cancels the rebuild of the dashboard subtree
    // mid-flight, which is exactly why Marco's dry-weight chart
    // rendered as a tiny sliver -- the build phase aborted before
    // the chart's CustomPaint had a chance to paint.
    //
    // Defer the notification past the current frame so onNotify
    // runs after build completes and the Overlay is free to mutate.
    final important = _mapInsights(context)
        .where((i) => i.isImportant)
        .map((i) => i.insight.message)
        .where((msg) => !_notifiedMessages.contains(msg))
        .toList();
    if (important.isEmpty) return;
    for (final msg in important) {
      _notifiedMessages.add(msg);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final msg in important) {
        widget.onNotify!(msg);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapped = _mapInsights(context);

    if (mapped.isEmpty) {
      return Text(
        'No significant insights for this period.',
        style: AppTypography.bodyMedium(context),
      );
    }

    final important = mapped.where((i) => i.isImportant).toList();
    final neutral = mapped.where((i) => !i.isImportant).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            '${AppLocalizations.of(context).analyticsInsightsHeader} • '
                '${widget.timeWindowLabel}',
            style: AppTypography.headlineSmall(context)),
        const SizedBox(height: AppSpacing.sm),
        ...important.map(_buildInsightCard),
        if (neutral.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: () =>
                setState(() => _showAllInsights = !_showAllInsights),
            icon: Icon(
              _showAllInsights ? Icons.expand_less : Icons.expand_more,
              color: context.colTextMuted,
              size: 18,
            ),
            label: Text(
              _showAllInsights
                  ? 'Hide less important insights'
                  : 'Show all insights',
              style: AppTypography.labelLarge(context)
                  .copyWith(color: context.colTextMuted),
            ),
          ),
          if (_showAllInsights) ...neutral.map(_buildInsightCard),
        ],
      ],
    );
  }

  Widget _buildInsightCard(_UiInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colSurface1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: insight.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(insight.icon, color: insight.color, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(insight.insight.message,
                    style: AppTypography.bodyLarge(context)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Why this appears: ${insight.explanation}',
            style: AppTypography.bodySmall(context),
          ),
        ],
      ),
    );
  }
}
