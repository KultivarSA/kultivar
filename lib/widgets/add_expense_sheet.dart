import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/grow_expense.dart';
import '../repository/grow_repository.dart';
import '../services/currency_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/amount_parser.dart';
import '../widgets/app_sheet.dart';

class AddExpenseSheet extends StatefulWidget {
  /// When non-null the sheet is pre-filled for editing.
  final GrowExpense? existing;

  /// Pre-select a plant when opened from Plant Detail.
  final String? initialPlantId;

  const AddExpenseSheet({super.key, this.existing, this.initialPlantId});

  static Future<void> show(
    BuildContext context, {
    GrowExpense? existing,
    String? initialPlantId,
  }) {
    // Bug fix: pop-with-result pattern -- see add_note_sheet.dart.
    // Capture repo before showing the modal so we don't have to
    // touch context across the async gap.
    final repo = context.read<GrowRepository>();
    return showModalBottomSheet<GrowExpense>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseSheet(
        existing: existing,
        initialPlantId: initialPlantId,
      ),
    ).then((expense) {
      if (expense == null) return;
      // Bug fix v4 (defence in depth) -- see add_note_sheet.dart.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (existing != null) {
          repo.updateExpense(expense);
        } else {
          repo.addExpense(expense);
        }
      });
    });
  }

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  late ExpenseCategory _category;
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _notesCtrl;
  late DateTime _date;
  String? _plantId;
  // Space attribution.  Used for costs that belong to a grow space as a
  // whole rather than a single plant — tents, lights, electricity, etc.
  // Plant attribution still takes precedence when both are set; the
  // space is then carried as additional context.
  String? _growSpaceId;
  String? _amountError;
  String? _descError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category ?? ExpenseCategory.nutrients;
    _amountCtrl = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(2) : '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _date = e?.date ?? DateTime.now();
    _plantId = e?.plantId ?? widget.initialPlantId;
    _growSpaceId = e?.growSpaceId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save(GrowRepository repo, StateSetter ss) {
    // Locale-tolerant parse — handles '1,000.50', '1.000,50', '12,34' etc.
    // Falls back to inline validation errors instead of failing silently.
    final amount = parseUserAmount(_amountCtrl.text);
    final descTrimmed = _descCtrl.text.trim();

    String? amountErr;
    String? descErr;
    if (_amountCtrl.text.trim().isEmpty) {
      amountErr = 'Enter an amount';
    } else if (amount == null) {
      amountErr = 'Couldn\'t read that amount — try 12.50 or 1,234.56';
    } else if (amount <= 0) {
      amountErr = 'Amount must be greater than zero';
    }
    if (descTrimmed.isEmpty) {
      descErr = 'Add a short description';
    }

    if (amountErr != null || descErr != null) {
      ss(() {
        _amountError = amountErr;
        _descError = descErr;
      });
      return;
    }

    // amount is guaranteed non-null past the early-return above.
    final validAmount = amount!;
    // Bug fix: build the entity, pop with it as result, persist
    // in show().then() after the modal is fully torn down.
    final expense = widget.existing != null
        ? widget.existing!.copyWith(
            category: _category,
            amount: validAmount,
            description: descTrimmed,
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            date: _date,
            plantId: _plantId,
            growSpaceId: _growSpaceId,
          )
        : GrowExpense(
            id: repo.newId(),
            plantId: _plantId,
            growSpaceId: _growSpaceId,
            date: _date,
            category: _category,
            description: descTrimmed,
            amount: validAmount,
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
    Navigator.pop(context, expense);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GrowRepository>();
    final activePlants = repo.plants
        .where((p) => !p.isArchived)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final spaces = [...repo.growSpaces]
      ..sort((a, b) => a.name.compareTo(b.name));

    return StatefulBuilder(
      builder: (ctx, ss) => AppSheet(
        title: widget.existing != null ? 'Edit Expense' : 'Log Expense',
        subtitle: 'Track grow costs',
        icon: Icons.receipt_long_rounded,
        iconColor: AppColors.harvested,
        children: [
          // ── Amount (big) ─────────────────────────────────────────────────
          Center(
            child: SizedBox(
              width: 180,
              child: TextField(
                controller: _amountCtrl,
                autofocus: widget.existing == null,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                onChanged: (_) {
                  // Clear the stale error as soon as the user edits the
                  // field — gives instant feedback that they've recovered.
                  if (_amountError != null) ss(() => _amountError = null);
                },
                textAlign: TextAlign.center,
                style: AppTypography.headlineLarge(context).copyWith(
                  fontSize: 36,
                  color: AppColors.harvested,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: '${context.watch<CurrencyService>().symbol} ',
                  prefixStyle: const TextStyle(
                    fontSize: 22,
                    color: AppColors.harvested,
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          if (_amountError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Center(
                child: Text(
                  _amountError!,
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),

          // ── Category chips ────────────────────────────────────────────────
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ExpenseCategory.values.map((cat) {
              final sel = _category == cat;
              return GestureDetector(
                onTap: () => ss(() => _category = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? cat.color.withValues(alpha: 0.15)
                        : context.colSurface3,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                      color: sel ? cat.color : context.colBorderFaint,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon,
                          size: 13,
                          color: sel ? cat.color : context.colTextMuted),
                      const SizedBox(width: 5),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: sel ? cat.color : context.colTextSecondary,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Description ──────────────────────────────────────────────────
          TextField(
            controller: _descCtrl,
            onChanged: (_) {
              if (_descError != null) ss(() => _descError = null);
            },
            style: TextStyle(color: context.colTextPrimary),
            decoration: InputDecoration(
              labelText: 'Description *',
              hintText:
                  _category == ExpenseCategory.electricity
                      ? 'e.g. Monthly electricity — 8-week cycle'
                      : _category == ExpenseCategory.nutrients
                          ? 'e.g. BioBizz Grow 5 L'
                          : 'e.g. ${_category.label} item',
              prefixIcon: Icon(_category.icon, size: 18),
              errorText: _descError,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Plant attribution ────────────────────────────────────────────
          //
          // Both dropdowns are optional and independent:
          //   * Plant set, space null   → "this is plant P1's cost"
          //   * Space set, plant null   → "this is a Space A cost
          //                              (e.g. lights, electricity)"
          //   * Both set                → "plant P1 in Space A" — the
          //                              cost is attributed to the
          //                              plant for cost-per-gram, with
          //                              space context preserved.
          //   * Both null               → unattributed / general grow cost.
          if (activePlants.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _plantId,
              dropdownColor: context.colSurface2,
              decoration: const InputDecoration(
                labelText: 'Attribute to plant (optional)',
                prefixIcon: Icon(Icons.eco_rounded, size: 18),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— No plant —',
                      style: TextStyle(color: context.colTextMuted)),
                ),
                ...activePlants.map((p) => DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text('${p.name} · ${p.strain}',
                          style:
                              TextStyle(color: context.colTextPrimary)),
                    )),
              ],
              onChanged: (v) => ss(() => _plantId = v),
            ),
          const SizedBox(height: AppSpacing.sm),

          // ── Space attribution ────────────────────────────────────────────
          if (spaces.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _growSpaceId,
              dropdownColor: context.colSurface2,
              decoration: const InputDecoration(
                labelText: 'Attribute to grow space (optional)',
                prefixIcon: Icon(Icons.home_work_rounded, size: 18),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— No space —',
                      style: TextStyle(color: context.colTextMuted)),
                ),
                ...spaces.map((s) => DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text('${s.name} · ${s.type}',
                          style:
                              TextStyle(color: context.colTextPrimary)),
                    )),
              ],
              onChanged: (v) => ss(() => _growSpaceId = v),
            ),
          const SizedBox(height: AppSpacing.sm),

          // ── Date ─────────────────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) ss(() => _date = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.colSurface3,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _date.toLocal().toString().split(' ')[0],
                    style: AppTypography.bodyMedium(context)
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Optional notes ───────────────────────────────────────────────
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            style: TextStyle(color: context.colTextPrimary),
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Supplier, order number, etc.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Save ─────────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(widget.existing != null
                  ? 'Save Changes'
                  : 'Log Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.harvested,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
                textStyle: AppTypography.labelLarge(context)
                    .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              onPressed: () => _save(repo, ss),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: AppTypography.labelLarge(context)
                      .copyWith(color: context.colTextSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}
