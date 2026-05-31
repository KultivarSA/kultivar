import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/models/grow_expense.dart';

void main() {
  group('GrowExpense', () {
    final fixedDate = DateTime.utc(2026, 3, 15, 12, 0);

    test('round-trips through JSON without data loss', () {
      final original = GrowExpense(
        id: 'exp-1',
        plantId: 'plant-1',
        growSpaceId: 'space-A',
        date: fixedDate,
        category: ExpenseCategory.nutrients,
        description: 'BioBizz Top·Max 1L',
        amount: 24.99,
        notes: 'Local grow shop',
      );

      final restored = GrowExpense.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.plantId, original.plantId);
      expect(restored.growSpaceId, original.growSpaceId);
      expect(restored.date.toIso8601String(),
          original.date.toIso8601String());
      expect(restored.category, original.category);
      expect(restored.description, original.description);
      expect(restored.amount, original.amount);
      expect(restored.notes, original.notes);
    });

    test('JSON with unknown category falls back to "other"', () {
      // Guards against future enum changes / corrupted backup files.
      final json = {
        'id': 'exp-2',
        'plantId': null,
        'growSpaceId': null,
        'date': fixedDate.toIso8601String(),
        'category': 'this_category_does_not_exist',
        'description': 'mystery line',
        'amount': 5.0,
        'notes': null,
      };

      final restored = GrowExpense.fromJson(json);
      expect(restored.category, ExpenseCategory.other);
    });

    test('copyWith preserves all unspecified fields', () {
      final original = GrowExpense(
        id: 'exp-3',
        plantId: 'plant-1',
        date: fixedDate,
        category: ExpenseCategory.electricity,
        description: 'Monthly bill share',
        amount: 42.0,
      );

      final updated = original.copyWith(amount: 50.0);

      expect(updated.id, original.id);
      expect(updated.plantId, original.plantId);
      expect(updated.category, original.category);
      expect(updated.description, original.description);
      expect(updated.amount, 50.0);
    });

    test('handles space-level expense with null plantId', () {
      final original = GrowExpense(
        id: 'exp-4',
        plantId: null,
        growSpaceId: 'space-A',
        date: fixedDate,
        category: ExpenseCategory.equipment,
        description: 'New extractor fan',
        amount: 89.99,
      );

      final restored = GrowExpense.fromJson(original.toJson());
      expect(restored.plantId, isNull);
      expect(restored.growSpaceId, 'space-A');
    });
  });

  group('ExpenseCategory extension', () {
    test('every category has a non-empty label', () {
      for (final cat in ExpenseCategory.values) {
        expect(cat.label, isNotEmpty,
            reason: 'Category ${cat.name} has empty label');
      }
    });

    test('every category has an icon and a color', () {
      for (final cat in ExpenseCategory.values) {
        expect(cat.icon, isNotNull);
        expect(cat.color, isNotNull);
      }
    });
  });
}
