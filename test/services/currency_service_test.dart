import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/services/currency_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset prefs between tests so default-symbol behaviour is reliable.
    SharedPreferences.setMockInitialValues({});
    // SA2 — neutralise the auto-detection path so tests that exercise
    // the "no saved value" code path don't pick up the test runner's
    // locale (typically en-US, which would map to '$').  Each
    // detection-specific test re-sets this to a known country.
    CurrencyService.debugOverrideCountryCode = '';
  });

  tearDown(() {
    CurrencyService.debugOverrideCountryCode = null;
  });

  group('CurrencyService — defaults', () {
    test('falls back to £ when no symbol is persisted AND no country '
        'detected', () async {
      final c = CurrencyService();
      await c.init();
      expect(c.symbol, '£');
    });

    test('persists chosen symbol across instances', () async {
      final first = CurrencyService();
      await first.init();
      await first.setSymbol('€');

      final second = CurrencyService();
      await second.init();
      expect(second.symbol, '€');
    });

    test('format prefixes amount with current symbol', () async {
      SharedPreferences.setMockInitialValues({'currency_symbol': '\$'});
      final c = CurrencyService();
      await c.init();
      expect(c.format(12.5), '\$12.50');
      expect(c.format(0), '\$0.00');
      expect(c.format(1234.567), '\$1234.57');
    });

    test('formatPerGram adds /g suffix', () async {
      final c = CurrencyService();
      await c.init();
      expect(c.formatPerGram(3.2), '£3.20/g');
    });

    test('setSymbol notifies listeners exactly once', () async {
      final c = CurrencyService();
      await c.init();
      int notifications = 0;
      c.addListener(() => notifications++);

      await c.setSymbol('€');
      expect(notifications, 1);
    });

    test('setSymbol with same value does NOT notify', () async {
      final c = CurrencyService();
      await c.init();
      int notifications = 0;
      c.addListener(() => notifications++);

      await c.setSymbol(c.symbol); // no-op
      expect(notifications, 0);
    });

    test('choices list is non-empty and unique by symbol', () {
      const choices = CurrencyService.choices;
      expect(choices, isNotEmpty);
      final symbols = choices.map((c) => c.symbol).toSet();
      expect(symbols.length, choices.length,
          reason: 'Duplicate symbol in CurrencyService.choices');
    });
  });

  group('CurrencyService — SA2 locale auto-detection', () {
    test('ZA → Rand (R) on a fresh install', () async {
      CurrencyService.debugOverrideCountryCode = 'ZA';
      final c = CurrencyService();
      await c.init();
      expect(c.symbol, 'R',
          reason: 'South African users should land on Rand without '
              'opening the Settings picker — the primary SA2 outcome');
    });

    test('US → Dollar (\$) on a fresh install', () async {
      CurrencyService.debugOverrideCountryCode = 'US';
      final c = CurrencyService();
      await c.init();
      expect(c.symbol, '\$');
    });

    test('GB → Pound (£) on a fresh install', () async {
      CurrencyService.debugOverrideCountryCode = 'GB';
      final c = CurrencyService();
      await c.init();
      expect(c.symbol, '£');
    });

    test('every eurozone member resolves to €', () async {
      const eurozone = [
        'AT', 'BE', 'CY', 'DE', 'EE', 'ES', 'FI', 'FR', 'GR',
        'HR', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PT',
        'SI', 'SK',
      ];
      for (final code in eurozone) {
        SharedPreferences.setMockInitialValues({});
        CurrencyService.debugOverrideCountryCode = code;
        final c = CurrencyService();
        await c.init();
        expect(c.symbol, '€', reason: '$code should map to €');
      }
    });

    test('unknown country code falls back to £', () async {
      // Antarctica — definitely not in our map.
      CurrencyService.debugOverrideCountryCode = 'AQ';
      final c = CurrencyService();
      await c.init();
      expect(c.symbol, '£');
    });

    test('auto-detected symbol is persisted — second launch skips '
        'detection', () async {
      // First launch: detect ZA → save 'R'.
      CurrencyService.debugOverrideCountryCode = 'ZA';
      final first = CurrencyService();
      await first.init();
      expect(first.symbol, 'R');

      // Simulate the user moving devices later — country changes to
      // US — but their preference should NOT silently flip.
      CurrencyService.debugOverrideCountryCode = 'US';
      final second = CurrencyService();
      await second.init();
      expect(second.symbol, 'R',
          reason: 'Once persisted, the symbol stays put — detection '
              'is first-launch only so users who deliberately picked '
              "a currency don't get it changed under them.");
    });

    test('every value in kLocaleCurrencyDefaults exists in choices',
        () {
      // Source-of-truth invariant — if the detection map points at a
      // symbol the picker doesn't show, the user has no clean way to
      // re-select it after the fact.
      final choiceSymbols =
          CurrencyService.choices.map((c) => c.symbol).toSet();
      for (final entry in CurrencyService.kLocaleCurrencyDefaults.entries) {
        expect(choiceSymbols, contains(entry.value),
            reason:
                'kLocaleCurrencyDefaults["${entry.key}"] = "${entry.value}" '
                'is not in CurrencyService.choices — the Settings '
                'picker would show "Custom" instead.');
      }
    });
  });
}
