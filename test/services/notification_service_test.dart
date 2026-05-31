import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/services/notification_service.dart';

void main() {
  group('snoozeIdFor', () {
    test('returns deterministic ID for the same input', () {
      const sourceBase = 12345;
      expect(snoozeIdFor(sourceBase), snoozeIdFor(sourceBase));
    });

    test('stays within the documented 510000–610000 window', () {
      // Spot-check 100 random hash inputs.
      for (int i = 0; i < 100; i++) {
        final id = snoozeIdFor(i * 99991);
        expect(id, inInclusiveRange(510000, 610000 - 1),
            reason: 'snoozeIdFor($i) out of range: $id');
      }
    });

    test('produces different IDs for different sources', () {
      // Not a hash uniqueness guarantee — but the modulo space (100k slots)
      // means collisions are statistically rare for ID-range inputs.
      final ids = <int>{};
      for (int i = 110000; i < 120000; i += 1000) {
        ids.add(snoozeIdFor(i));
      }
      expect(ids.length, greaterThan(5));
    });

    test('handles negative source IDs via masking', () {
      // Hash codes in Dart can be negative; ensure we still produce a
      // positive notification ID rather than crashing or returning < 0.
      final id = snoozeIdFor(-9999999);
      expect(id, isNonNegative);
      expect(id, inInclusiveRange(510000, 610000 - 1));
    });
  });
}
