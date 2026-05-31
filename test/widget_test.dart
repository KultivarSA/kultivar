// Sanity-check smoke test. Real coverage lives in:
//
//   test/models/     — JSON round-trips and computed properties
//   test/services/   — service unit tests (CurrencyService, snooze IDs, …)
//   test/repository/ — GrowRepository CRUD without Hive / network deps
//   test/utils/      — pure utility functions (temp conversion, etc.)
//
// Add new tests next to the production code they exercise; the CI
// workflow at .github/workflows/test.yml runs all *_test.dart files.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dart toolchain sanity', () {
    expect(1 + 1, 2);
  });
}
