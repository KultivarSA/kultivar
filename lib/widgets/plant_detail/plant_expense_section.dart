import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/grow_expense.dart';
import '../../models/harvest_log.dart';
import '../../models/plant.dart';
import '../../repository/grow_repository.dart';
import '../../screens/expense_tracker_screen.dart';
import '../../services/currency_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../add_expense_sheet.dart';

/// Snapshot of just the repo data this section actually displays.
///
/// Used as the `Selector` return type so [PlantExpenseSection] only
/// rebuilds when its OWN visible data changes — not on every unrelated
/// repo notification (env logs added in other spaces, plants renamed,
/// etc.).  The `==` implementation compares the IDs + key fields of
/// the top expenses so identity-only changes (re-saving the same
/// list) don't cause a rebuild either.
class _ExpenseSectionData {
  final List<GrowExpense> topExpenses; // up to 3, in display order
  final int totalCount;
  final double total;
  final double? dryWeight;

  const _ExpenseSectionData({
    required this.topExpenses,
    required this.totalCount,
    required this.total,
    required this.dryWeight,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _ExpenseSectionData) return false;
    if (totalCount != other.totalCount) return false;
    if (total != other.total) return false;
    if (dryWeight != other.dryWeight) return false;
    if (topExpenses.length != other.topExpenses.length) return false;
    for (int i = 0; i < topExpenses.length; i++) {
      final a = topExpenses[i];
      final b = other.topExpenses[i];
      if (a.id != b.id ||
          a.amount != b.amount ||
          a.description != b.description ||
          a.category != b.category) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(totalCount, total, dryWeight, topExpenses.length);
}

/// Compact grow-cost summary shown inside the plant-detail header.
/// Lists the three most recent expenses with a total + cost-per-gram
/// pill once a dry weight is on file.  Tapping rows or "View all"
/// drills into [ExpenseTrackerScreen] filtered to this plant.
///
/// Extracted from `plant_detail_screen.dart` (Q1a).
class PlantExpenseSection extends StatelessWidget {
  final Plant plant;
  const PlantExpenseSection({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    return Selector<GrowRepository, _ExpenseSectionData>(
      selector: (_, repo) {
        final all = repo.expensesForPlant(plant.id);
        // Use the most recent harvest log (insertion order) for the
        // dry-weight component of cost-per-gram.  A plant only ever has
        // one harvest log in practice.
        final log = repo.harvestLogs
            .where((l) => l.plantId == plant.id)
            .fold<HarvestLog?>(null, (_, l) => l);
        return _ExpenseSectionData(
          topExpenses: all.take(3).toList(),
          totalCount: all.length,
          total: repo.totalCostForPlant(plant.id),
          dryWeight: log?.dryWeight,
        );
      },
      builder: (context, data, _) => _buildSection(context, data),
    );
  }

  Widget _buildSection(BuildContext context, _ExpenseSectionData data) {
    final currency = context.watch<CurrencyService>();
    final expenses = data.topExpenses;
    final total = data.total;
    final cpg = (total > 0 && data.dryWeight != null && data.dryWeight! > 0)
        ? total / data.dryWeight!
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ───────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 14, color: AppColors.harvested),
              const SizedBox(width: AppSpacing.xs),
              Text('Grow Costs',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colTextMuted)),
              if (total > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.harvested.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    currency.format(total),
                    style: AppTypography.labelSmall(context).copyWith(
                        color: AppColors.harvested,
                        fontWeight: FontWeight.w700,
                        fontSize: 11),
                  ),
                ),
                if (cpg != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.growing.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      currency.formatPerGram(cpg),
                      style: AppTypography.labelSmall(context).copyWith(
                          color: AppColors.growing,
                          fontWeight: FontWeight.w700,
                          fontSize: 11),
                    ),
                  ),
                ],
              ],
            ]),
            Row(children: [
              GestureDetector(
                onTap: () => AddExpenseSheet.show(
                  context,
                  initialPlantId: plant.id,
                ),
                child: Row(children: [
                  const Icon(Icons.add_rounded,
                      color: AppColors.harvested, size: 14),
                  Text('Add',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: AppColors.harvested)),
                ]),
              ),
              if (expenses.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ExpenseTrackerScreen(filterPlant: plant),
                    ),
                  ),
                  child: Text('View all',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextMuted)),
                ),
              ],
            ]),
          ],
        ),

        // ── Recent expenses (up to 3) ─────────────────────────────────
        if (expenses.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          ...expenses.take(3).map((e) => Padding(
                padding:
                    const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Row(children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: e.category.color.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(e.category.icon,
                        size: 13, color: e.category.color),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(e.description,
                        style: AppTypography.bodySmall(context)
                            .copyWith(
                                color: context.colTextSecondary,
                                fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    currency.format(e.amount),
                    style: AppTypography.labelSmall(context).copyWith(
                        color: AppColors.harvested,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ]),
              )),
        ] else ...[
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: () =>
                AddExpenseSheet.show(context, initialPlantId: plant.id),
            child: Text(
              'No expenses yet — tap to log seeds, nutrients, electricity…',
              style: AppTypography.bodySmall(context).copyWith(
                  color: context.colTextMuted, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}
