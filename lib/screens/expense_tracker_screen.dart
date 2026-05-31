import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/grow_expense.dart';
import '../models/plant.dart';
import '../repository/grow_repository.dart';
import '../services/currency_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/empty_state_art.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class ExpenseTrackerScreen extends StatefulWidget {
  /// When set, only expenses for this plant are shown and the title reflects
  /// the plant name. Used when pushed from Plant Detail.
  final Plant? filterPlant;

  const ExpenseTrackerScreen({super.key, this.filterPlant});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Sorting
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: widget.filterPlant != null ? 2 : 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GrowRepository>();

    final allExpenses = widget.filterPlant != null
        ? repo.expensesForPlant(widget.filterPlant!.id)
        : (List<GrowExpense>.from(repo.expenses)
          ..sort((a, b) => _newestFirst
              ? b.date.compareTo(a.date)
              : a.date.compareTo(b.date)));

    final totalSpend = allExpenses.fold(0.0, (s, e) => s + e.amount);

    // Cost-per-gram: only meaningful when filtering to a single plant
    final plantLog = widget.filterPlant != null
        ? repo.harvestLogs
            .where((l) => l.plantId == widget.filterPlant!.id)
            .fold<dynamic>(null, (_, l) => l)
        : null;
    final dryWeight = plantLog?.dryWeight as double?;
    final cpg = dryWeight != null && totalSpend > 0
        ? totalSpend / dryWeight
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.filterPlant != null
              ? '${widget.filterPlant!.name} — Costs'
              : 'Expense Tracker',
          style: AppTypography.headlineMedium(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_newestFirst
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded),
            tooltip: _newestFirst ? 'Oldest first' : 'Newest first',
            onPressed: () => setState(() => _newestFirst = !_newestFirst),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Log Expense',
            onPressed: () => AddExpenseSheet.show(
              context,
              initialPlantId: widget.filterPlant?.id,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            const Tab(text: 'All'),
            const Tab(text: 'By Category'),
            if (widget.filterPlant == null) const Tab(text: 'By Plant'),
          ],
        ),
      ),

      // ── Summary header ─────────────────────────────────────────────────
      body: Column(
        children: [
          _SummaryHeader(
            totalSpend: totalSpend,
            expenseCount: allExpenses.length,
            costPerGram: cpg,
            avgCpg: widget.filterPlant == null
                ? repo.averageCostPerGram
                : null,
          ),

          // ── Tab pages ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ── All (monthly grouped) ──────────────────────────────
                _AllExpensesTab(
                  expenses: allExpenses,
                  repo: repo,
                  newestFirst: _newestFirst,
                ),
                // ── By category ────────────────────────────────────────
                _ByCategoryTab(expenses: allExpenses),
                // ── By plant (global view only) ────────────────────────
                if (widget.filterPlant == null)
                  _ByPlantTab(repo: repo),
              ],
            ),
          ),
        ],
      ),

      // ── FAB ────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expense_fab',
        onPressed: () => AddExpenseSheet.show(
          context,
          initialPlantId: widget.filterPlant?.id,
        ),
        backgroundColor: AppColors.harvested,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log Expense'),
        elevation: 0,
      ),
    );
  }
}

// ── Summary header ────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final double totalSpend;
  final int expenseCount;
  final double? costPerGram;
  final double? avgCpg;

  const _SummaryHeader({
    required this.totalSpend,
    required this.expenseCount,
    this.costPerGram,
    this.avgCpg,
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyService>();
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.md,
          AppSpacing.pagePadding, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.harvested.withValues(alpha: 0.06),
        border: Border(
            bottom: BorderSide(color: AppColors.harvested.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          _StatPill(
            label: 'Total Invested',
            value: currency.format(totalSpend),
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.harvested,
            large: true,
          ),
          const SizedBox(width: AppSpacing.md),
          if (costPerGram != null) ...[
            _StatPill(
              label: 'Cost / gram',
              value: currency.formatPerGram(costPerGram!),
              icon: Icons.scale_rounded,
              color: AppColors.growing,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (avgCpg != null) ...[
            _StatPill(
              label: 'Avg ${currency.symbol}/g',
              value: currency.formatPerGram(avgCpg!),
              icon: Icons.bar_chart_rounded,
              color: AppColors.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          _StatPill(
            label: 'Entries',
            value: '$expenseCount',
            icon: Icons.receipt_rounded,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool large;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: large ? 2 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: AppSpacing.xxs),
              Text(label,
                  style: AppTypography.labelSmall(context)
                      .copyWith(color: color, fontSize: 9)),
            ]),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTypography.headlineSmall(context).copyWith(
                  color: color,
                  fontSize: large ? 16 : 13,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ── All expenses tab (grouped by month) ──────────────────────────────────────

class _AllExpensesTab extends StatelessWidget {
  final List<GrowExpense> expenses;
  final GrowRepository repo;
  final bool newestFirst;

  const _AllExpensesTab({
    required this.expenses,
    required this.repo,
    required this.newestFirst,
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyService>();
    if (expenses.isEmpty) {
      return _EmptyState(
        onAdd: () => AddExpenseSheet.show(context),
      );
    }

    // Group by year-month
    final Map<String, List<GrowExpense>> grouped = {};
    for (final e in expenses) {
      final key =
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(e);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) => newestFirst ? b.compareTo(a) : a.compareTo(b));

    return ListView.builder(
      padding: const EdgeInsets.only(
          bottom: AppSpacing.fabClearance, top: AppSpacing.sm),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final key = keys[i];
        final items = grouped[key]!;
        final monthTotal = items.fold(0.0, (s, e) => s + e.amount);
        final dt = DateTime.parse('$key-01');
        final monthLabel = _monthLabel(dt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding, AppSpacing.sm,
                  AppSpacing.pagePadding, AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(monthLabel,
                      style: AppTypography.labelLarge(context)
                          .copyWith(color: context.colTextMuted)),
                  Text(currency.format(monthTotal),
                      style: AppTypography.labelLarge(context)
                          .copyWith(color: AppColors.harvested)),
                ],
              ),
            ),
            ...items.map((e) => _ExpenseTile(
                  expense: e,
                  repo: repo,
                  plantName: repo.plants
                      .where((p) => p.id == e.plantId)
                      .map((p) => p.name)
                      .firstOrNull,
                )),
          ],
        );
      },
    );
  }

  String _monthLabel(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

// ── By-category tab ───────────────────────────────────────────────────────────

class _ByCategoryTab extends StatelessWidget {
  final List<GrowExpense> expenses;

  const _ByCategoryTab({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyService>();
    if (expenses.isEmpty) {
      return _EmptyState(onAdd: () => AddExpenseSheet.show(context));
    }

    // Tally by category
    final Map<ExpenseCategory, double> totals = {};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    final total = totals.values.fold(0.0, (s, v) => s + v);
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // P1.2 — ListView.builder so off-screen category rows aren't
    // built eagerly.  Bounded by enum size today (9 categories) but
    // moving to .builder keeps the list policy consistent and avoids
    // a future regression if category aggregation ever fans out.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.md,
          AppSpacing.pagePadding, AppSpacing.fabClearance),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final entry = sorted[i];
        final cat = entry.key;
        final amount = entry.value;
        final pct = total > 0 ? amount / total : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(cat.icon, size: 16, color: cat.color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cat.label,
                                style: AppTypography.labelLarge(context)
                                    .copyWith(
                                        color: context.colTextPrimary)),
                            Text(currency.format(amount),
                                style: AppTypography.labelLarge(context)
                                    .copyWith(color: cat.color)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor:
                                cat.color.withValues(alpha: 0.1),
                            color: cat.color,
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: context.colTextMuted, fontSize: 11),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── By-plant tab ──────────────────────────────────────────────────────────────

class _ByPlantTab extends StatelessWidget {
  final GrowRepository repo;

  const _ByPlantTab({required this.repo});

  @override
  Widget build(BuildContext context) {
    // Build per-plant totals — only plants that have at least one expense
    final Map<String, double> totals = {};
    for (final e in repo.expenses) {
      if (e.plantId == null) continue;
      totals[e.plantId!] = (totals[e.plantId!] ?? 0) + e.amount;
    }

    // Space-level (unattributed)
    final spaceLevelTotal = repo.expenses
        .where((e) => e.plantId == null)
        .fold(0.0, (s, e) => s + e.amount);

    if (totals.isEmpty && spaceLevelTotal == 0) {
      return _EmptyState(onAdd: () => AddExpenseSheet.show(context));
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // P1.2 — ListView.builder so off-screen plant cards aren't built
    // eagerly.  Enthusiast growers with 50+ completed cycles would
    // otherwise have 50+ _PlantCostTile widgets instantiated up-front,
    // each running a per-plant cost-per-gram computation against the
    // repository.  Builder defers that work until scroll.
    //
    // The optional _SpaceLevelTile lives at index `sorted.length` (one
    // past the last plant row) when spaceLevelTotal > 0, so itemCount
    // adds a trailing slot conditionally.
    final hasSpaceLevel = spaceLevelTotal > 0;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.md,
          AppSpacing.pagePadding, AppSpacing.fabClearance),
      itemCount: sorted.length + (hasSpaceLevel ? 1 : 0),
      itemBuilder: (_, i) {
        // Trailing space-level tile.
        if (i == sorted.length) {
          return _SpaceLevelTile(total: spaceLevelTotal);
        }
        final entry = sorted[i];
        final plant = repo.plants
            .where((p) => p.id == entry.key)
            .firstOrNull;
        if (plant == null) return const SizedBox.shrink();

        final log = repo.harvestLogs
            .where((l) => l.plantId == plant.id)
            .firstOrNull;
        final cpg = repo.costPerGram(plant.id, log?.dryWeight);

        return _PlantCostTile(
          plant: plant,
          total: entry.value,
          dryWeightGrams: log?.dryWeight,
          costPerGram: cpg,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseTrackerScreen(filterPlant: plant),
            ),
          ),
        );
      },
    );
  }
}

// ── Expense tile ──────────────────────────────────────────────────────────────

class _ExpenseTile extends StatelessWidget {
  final GrowExpense expense;
  final GrowRepository repo;
  final String? plantName;

  const _ExpenseTile({
    required this.expense,
    required this.repo,
    this.plantName,
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyService>();
    final e = expense;
    return Dismissible(
      key: Key(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        color: AppColors.danger.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_rounded,
            color: AppColors.danger, size: 22),
      ),
      confirmDismiss: (_) => ConfirmSheet.show(
        context,
        icon: Icons.delete_rounded,
        iconColor: AppColors.danger,
        title: 'Delete Expense',
        body: 'Remove "${e.description}" (${currency.format(e.amount)})?',
        confirmLabel: 'Delete',
        confirmColor: AppColors.danger,
      ),
      onDismissed: (_) => repo.deleteExpense(e.id),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: e.category.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(e.category.icon, size: 18, color: e.category.color),
        ),
        title: Text(e.description,
            style: AppTypography.labelLarge(context)
                .copyWith(color: context.colTextPrimary)),
        subtitle: Row(children: [
          Text(
            e.date.toLocal().toString().split(' ')[0],
            style: AppTypography.bodySmall(context)
                .copyWith(color: context.colTextMuted, fontSize: 11),
          ),
          if (plantName != null) ...[
            Text(' · ',
                style: AppTypography.bodySmall(context)
                    .copyWith(color: context.colTextMuted)),
            const Icon(Icons.eco_rounded, size: 11, color: AppColors.growing),
            const SizedBox(width: 2),
            Text(plantName!,
                style: AppTypography.bodySmall(context).copyWith(
                    color: AppColors.growing, fontSize: 11)),
          ],
        ]),
        // Trailing column: amount on top, overflow menu below.  The
        // explicit menu replaces the previous tap-anywhere + swipe-to-
        // delete combo which was discoverable only by accident; the
        // swipe gesture is kept as a power-user shortcut.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currency.format(e.amount),
              style: AppTypography.labelLarge(context).copyWith(
                  color: AppColors.harvested, fontWeight: FontWeight.w700),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  size: 18, color: context.colTextMuted),
              tooltip: 'More actions',
              padding: EdgeInsets.zero,
              onSelected: (action) async {
                switch (action) {
                  case 'edit':
                    AddExpenseSheet.show(context, existing: e);
                  case 'delete':
                    final confirmed = await ConfirmSheet.show(
                      context,
                      icon: Icons.delete_rounded,
                      iconColor: AppColors.danger,
                      title: 'Delete Expense',
                      body:
                          'Remove "${e.description}" (${currency.format(e.amount)})?',
                      confirmLabel: 'Delete',
                      confirmColor: AppColors.danger,
                    );
                    if (confirmed) repo.deleteExpense(e.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 16),
                    SizedBox(width: AppSpacing.xs),
                    Text('Edit'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_rounded,
                        size: 16, color: AppColors.danger),
                    SizedBox(width: AppSpacing.xs),
                    Text('Delete',
                        style: TextStyle(color: AppColors.danger)),
                  ]),
                ),
              ],
            ),
          ],
        ),
        onTap: () => AddExpenseSheet.show(context, existing: e),
      ),
    );
  }
}

// ── Plant cost tile (by-plant tab) ────────────────────────────────────────────

class _PlantCostTile extends StatelessWidget {
  final Plant plant;
  final double total;
  final double? dryWeightGrams;
  final double? costPerGram;
  final VoidCallback onTap;

  const _PlantCostTile({
    required this.plant,
    required this.total,
    this.dryWeightGrams,
    this.costPerGram,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyService>();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.growing.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: const Icon(Icons.eco_rounded, size: 18, color: AppColors.growing),
      ),
      title: Text(plant.name,
          style: AppTypography.labelLarge(context)
              .copyWith(color: context.colTextPrimary)),
      subtitle: Text(plant.strain,
          style: AppTypography.bodySmall(context)
              .copyWith(color: context.colTextMuted)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(currency.format(total),
              style: AppTypography.labelLarge(context)
                  .copyWith(
                      color: AppColors.harvested,
                      fontWeight: FontWeight.w700)),
          if (costPerGram != null)
            Text(currency.formatPerGram(costPerGram!),
                style: AppTypography.bodySmall(context)
                    .copyWith(color: AppColors.growing, fontSize: 11)),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SpaceLevelTile extends StatelessWidget {
  final double total;
  const _SpaceLevelTile({required this.total});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyService>();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: const Icon(Icons.home_work_rounded,
            size: 18, color: AppColors.textMuted),
      ),
      title: Text('Space-level / unattributed',
          style: AppTypography.labelLarge(context)
              .copyWith(color: context.colTextSecondary)),
      trailing: Text(currency.format(total),
          style: AppTypography.labelLarge(context)
              .copyWith(
                  color: AppColors.harvested, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A3 — receipt line-art instead of the single
            // receipt_long icon-in-circle.  Harvested-gold accent
            // matches the section's brand colour used below for the
            // primary CTA.
            const LineArtIllustration(
              art: EmptyArt.receipt,
              accent: AppColors.harvested,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(AppLocalizations.of(context).costsEmptyTitle,
                style: AppTypography.headlineSmall(context)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppLocalizations.of(context).costsEmptyBody,
              style: AppTypography.bodyMedium(context)
                  .copyWith(color: context.colTextMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(AppLocalizations.of(context).costsEmptyAddAction),
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.harvested,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
