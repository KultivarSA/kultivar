import 'package:flutter/foundation.dart';

import 'ui_preferences_service.dart';

/// User-configurable currency symbol with reactive updates.
///
/// Pattern matches [SubscriptionService] / theme notifiers — provided via
/// the top-level [MultiProvider] in `main.dart`.  Any widget that needs to
/// display monetary values does `context.watch<CurrencyService>().format(x)`
/// (or `.symbol` for the prefix alone) and rebuilds automatically when the
/// user picks a different currency in Settings.
class CurrencyService extends ChangeNotifier {
  String _symbol = '£';

  /// Current user-selected currency symbol (defaults to '£' when the OS
  /// locale doesn't map to any known currency).
  String get symbol => _symbol;

  /// SA2 — first-launch currency defaults keyed by ISO-3166 alpha-2
  /// country code.  Looked up from the OS locale exactly once: when
  /// `init()` runs and finds no previously saved symbol.  After the
  /// user touches the picker we never re-detect — that would be
  /// hostile to a user who deliberately chose a different currency.
  ///
  /// Symbols must match a `choices` entry above; otherwise the
  /// Settings picker would show the auto-detected currency under
  /// "Custom" with no clean way to re-select it.  A unit test
  /// (`currency_service_test.dart`) asserts this invariant.
  ///
  /// Map covers every country tied to a currency Kultivar's picker
  /// already supports.  When the picker grows new symbols, add the
  /// matching country codes here.
  static const Map<String, String> kLocaleCurrencyDefaults = {
    // ── Pound ──
    'GB': '£',
    // ── Dollar ──
    'US': '\$',
    // ── Euro (the 20 eurozone members) ──
    'AT': '€', 'BE': '€', 'CY': '€', 'DE': '€', 'EE': '€',
    'ES': '€', 'FI': '€', 'FR': '€', 'GR': '€', 'HR': '€',
    'IE': '€', 'IT': '€', 'LT': '€', 'LU': '€', 'LV': '€',
    'MT': '€', 'NL': '€', 'PT': '€', 'SI': '€', 'SK': '€',
    // ── Yen / Yuan ──
    'JP': '¥', 'CN': '¥',
    // ── Common ──
    'AU': 'A\$', 'CA': 'C\$', 'CH': 'CHF', 'BR': 'R\$',
    'IN': '₹',
    // ── Nordic Krone / Krona / Króna ──
    'NO': 'kr', 'SE': 'kr', 'DK': 'kr', 'IS': 'kr',
    // ── Africa ──
    'GH': 'GH₵', 'LS': 'L', 'MA': 'DH', 'RW': 'FRw',
    'ZA': 'R',   'UG': 'USh', 'ZM': 'ZK', 'ZW': 'Z\$',
    // ── Americas (LatAm) ──
    'CO': 'Col\$', 'MX': 'Mex\$', 'UY': 'U\$',
    // ── Europe (non-€) ──
    'CZ': 'Kč',
    // ── Middle East / Caucasus ──
    'GE': '₾', 'IL': '₪',
  };

  /// Built-in choices presented in the Settings dropdown.
  ///
  /// The first block holds the highest-traffic symbols (which also feed
  /// the one-tap quick-row at the top of the picker sheet).  The rest
  /// run alphabetically by country / region label so unfamiliar
  /// currencies can be found by scanning.  Free-text isn't offered —
  /// keeps the list curated and the symbols predictable across users
  /// who share data via community benchmarks.
  ///
  /// Symbols that collide with USD ('$') get a country prefix (Col$,
  /// Mex$, Z$, U\$) so growers reading another user's exported CSV
  /// can't mistake them for dollars.
  static const List<({String symbol, String label})> choices = [
    // ── Most-used ────────────────────────────────
    (symbol: '£',  label: 'British Pound (£)'),
    (symbol: '\$', label: 'US Dollar (\$)'),
    (symbol: '€',  label: 'Euro (€)'),       // DE, FR, IT, PT, MT, LU, …
    (symbol: '¥',  label: 'Yen / Yuan (¥)'),
    // ── Common ───────────────────────────────────
    (symbol: 'A\$', label: 'Australian Dollar (A\$)'),
    (symbol: 'C\$', label: 'Canadian Dollar (C\$)'),
    (symbol: 'CHF', label: 'Swiss Franc (CHF)'),
    (symbol: 'R\$', label: 'Brazilian Real (R\$)'),
    (symbol: '₹',  label: 'Indian Rupee (₹)'),
    (symbol: 'kr',  label: 'Krone / Krona (kr)'),    // NOK, SEK, DKK, ISK
    // ── Africa ───────────────────────────────────
    (symbol: 'GH₵', label: 'Ghanaian Cedi (GH₵)'),
    (symbol: 'L',   label: 'Lesotho Loti (L)'),
    (symbol: 'DH',  label: 'Moroccan Dirham (DH)'),
    (symbol: 'FRw', label: 'Rwandan Franc (FRw)'),
    (symbol: 'R',   label: 'South African Rand (R)'),
    (symbol: 'USh', label: 'Ugandan Shilling (USh)'),
    (symbol: 'ZK',  label: 'Zambian Kwacha (ZK)'),
    (symbol: 'Z\$', label: 'Zimbabwean Dollar (Z\$)'),
    // ── Americas (LatAm) ─────────────────────────
    (symbol: 'Col\$', label: 'Colombian Peso (Col\$)'),
    (symbol: 'Mex\$', label: 'Mexican Peso (Mex\$)'),
    (symbol: 'U\$',  label: 'Uruguayan Peso (U\$)'),
    // ── Europe (non-€) ───────────────────────────
    (symbol: 'Kč',  label: 'Czech Koruna (Kč)'),
    // ── Middle East / Caucasus ───────────────────
    (symbol: '₾',  label: 'Georgian Lari (₾)'),
    (symbol: '₪',  label: 'Israeli Shekel (₪)'),
  ];

  /// Loads the persisted symbol.  Called once from `main()` before runApp so
  /// the very first frame shows the right currency.
  ///
  /// On a fresh install ([UiPreferencesService.loadCurrencySymbol]
  /// returns null), looks up the OS locale's country code in
  /// [kLocaleCurrencyDefaults].  SA2 — this is the path that picks
  /// ZAR for SA users automatically without forcing them to find
  /// the currency picker on day one.
  Future<void> init() async {
    final saved = await UiPreferencesService.loadCurrencySymbol();
    if (saved != null) {
      _symbol = saved;
      return;
    }
    _symbol = _localeDefaultSymbol();
    // Persist the auto-detected symbol so subsequent launches don't
    // re-run detection (and don't accidentally switch the user's
    // currency if they later change their device's region).
    await UiPreferencesService.saveCurrencySymbol(_symbol);
  }

  /// Test-only override.  When non-null, `_localeDefaultSymbol()`
  /// uses this instead of querying [PlatformDispatcher].  Pass an
  /// empty string to force the "no country tag" branch.  Always
  /// reset in tearDown so other tests aren't poisoned.
  ///
  /// In production this stays null and the live OS locale is read.
  @visibleForTesting
  static String? debugOverrideCountryCode;

  static String _localeDefaultSymbol() {
    try {
      final override = debugOverrideCountryCode;
      final country = (override ??
              PlatformDispatcher.instance.locale.countryCode)
          ?.toUpperCase();
      if (country == null || country.isEmpty) return '£';
      return kLocaleCurrencyDefaults[country] ?? '£';
    } catch (_) {
      // Some test/embedder configurations don't expose a sensible
      // platform locale; the fallback keeps us out of trouble.
      return '£';
    }
  }

  /// Updates the symbol, persists it, and rebuilds listeners.
  Future<void> setSymbol(String newSymbol) async {
    if (newSymbol == _symbol) return;
    _symbol = newSymbol;
    await UiPreferencesService.saveCurrencySymbol(newSymbol);
    notifyListeners();
  }

  /// Format a monetary amount with two decimal places.
  /// e.g. `format(12.5)` → `'£12.50'`.
  String format(double amount) => '$_symbol${amount.toStringAsFixed(2)}';

  /// Format a per-gram cost (always with a `/g` suffix).
  String formatPerGram(double amount) =>
      '$_symbol${amount.toStringAsFixed(2)}/g';
}
