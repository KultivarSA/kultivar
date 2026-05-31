import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ── Category ──────────────────────────────────────────────────────────────────

enum ExpenseCategory {
  seeds,
  clones,
  nutrients,
  electricity,
  substrate,
  equipment,
  ipm,
  water,
  other,
}

extension ExpenseCategoryExt on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.seeds:
        return 'Seeds';
      case ExpenseCategory.clones:
        return 'Clones';
      case ExpenseCategory.nutrients:
        return 'Nutrients';
      case ExpenseCategory.electricity:
        return 'Electricity';
      case ExpenseCategory.substrate:
        return 'Substrate';
      case ExpenseCategory.equipment:
        return 'Equipment';
      case ExpenseCategory.ipm:
        return 'IPM';
      case ExpenseCategory.water:
        return 'Water';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.seeds:
        return Icons.grass_rounded;
      case ExpenseCategory.clones:
        return Icons.content_cut_rounded;
      case ExpenseCategory.nutrients:
        return Icons.science_rounded;
      case ExpenseCategory.electricity:
        return Icons.bolt_rounded;
      case ExpenseCategory.substrate:
        return Icons.terrain_rounded;
      case ExpenseCategory.equipment:
        return Icons.construction_rounded;
      case ExpenseCategory.ipm:
        return Icons.bug_report_rounded;
      case ExpenseCategory.water:
        return Icons.water_drop_rounded;
      case ExpenseCategory.other:
        return Icons.receipt_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.seeds:
        return AppColors.growing;
      case ExpenseCategory.clones:
        return AppColors.training;
      case ExpenseCategory.nutrients:
        return AppColors.info;
      case ExpenseCategory.electricity:
        return AppColors.drying;
      case ExpenseCategory.substrate:
        return AppColors.secondary;
      case ExpenseCategory.equipment:
        return AppColors.textMuted;
      case ExpenseCategory.ipm:
        return AppColors.ipmColor;
      case ExpenseCategory.water:
        return AppColors.water;
      case ExpenseCategory.other:
        return AppColors.harvested;
    }
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

class GrowExpense {
  final String id;

  /// The plant this expense is attributed to.
  /// Null means the expense is space-level (e.g. electricity, equipment shared
  /// across all plants in the grow).
  final String? plantId;

  /// Optional grow-space attribution for space-level expenses.
  final String? growSpaceId;

  final DateTime date;
  final ExpenseCategory category;

  /// Short label shown in the list (e.g. "BioBizz Top·Max", "600 W HPS bulb").
  final String description;

  /// Amount in the user's local currency.
  final double amount;

  /// Optional extra notes.
  final String? notes;

  const GrowExpense({
    required this.id,
    this.plantId,
    this.growSpaceId,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    this.notes,
  });

  GrowExpense copyWith({
    String? plantId,
    String? growSpaceId,
    DateTime? date,
    ExpenseCategory? category,
    String? description,
    double? amount,
    String? notes,
  }) {
    return GrowExpense(
      id: id,
      plantId: plantId ?? this.plantId,
      growSpaceId: growSpaceId ?? this.growSpaceId,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'growSpaceId': growSpaceId,
        'date': date.toIso8601String(),
        'category': category.name,
        'description': description,
        'amount': amount,
        'notes': notes,
      };

  factory GrowExpense.fromJson(Map<String, dynamic> json) => GrowExpense(
        id: json['id'],
        plantId: json['plantId'] as String?,
        growSpaceId: json['growSpaceId'] as String?,
        date: DateTime.parse(json['date']),
        category: ExpenseCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => ExpenseCategory.other,
        ),
        description: json['description'] ?? '',
        amount: (json['amount'] as num).toDouble(),
        notes: json['notes'] as String?,
      );
}
