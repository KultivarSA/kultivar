/// Locale-tolerant parser for user-entered monetary amounts.
///
/// Handles every reasonable combination of `.` and `,` as decimal or
/// thousands separators by inspecting the relative positions rather than
/// assuming a specific locale.  Returns null when the input cannot be
/// interpreted as a positive number.
///
/// ## Examples
///
/// | Input        | Result   | Reasoning                          |
/// |--------------|----------|------------------------------------|
/// | `"12.50"`    | 12.50    | unambiguous US decimal             |
/// | `"12,50"`    | 12.50    | EU decimal (2 digits after `,`)    |
/// | `"1,000.50"` | 1000.50  | mixed → last is decimal            |
/// | `"1.000,50"` | 1000.50  | mixed → last is decimal            |
/// | `"1.234.567"`| 1234567  | one type repeated → thousands      |
/// | `"1,500"`    | 1500.00  | small int part + 3 trailing        |
/// | `"1234.567"` | 1234.567 | 4+ int digits → decimal precision  |
/// | `"1,5"`      | 1.50     | 1 trailing digit → decimal         |
/// | `"  £42  "`  | 42.00    | strips whitespace and symbols      |
/// | `""`         | null     | empty input                        |
/// | `"-5"`       | null     | negative — out of domain           |
/// | `"abc"`      | null     | unparseable                        |
///
/// ## Ambiguity rule for single-separator + 3 trailing digits
///
/// `"1,000"` is genuinely ambiguous (1.000 EU decimal vs 1000 US
/// thousands).  We resolve to **thousands** only when the integer part
/// is 1–3 digits — the magnitude where thousands-grouping makes sense.
/// Inputs like `"1234,567"` have 4+ integer digits, which never makes
/// sense as a thousands group (you'd write `"1,234,567"` instead), so
/// these always parse as decimals.
double? parseUserAmount(String input) {
  // 1. Strip whitespace + any non-digit / non-separator chars (currency
  //    symbols, stray letters from accidental keyboard switches, etc.).
  var s = input.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll(RegExp(r'[^\d.,-]'), '');
  if (s.isEmpty) return null;

  // Reject negatives — expense amounts are always >= 0.
  if (s.contains('-')) return null;

  final dotCount = '.'.allMatches(s).length;
  final commaCount = ','.allMatches(s).length;

  // No separators at all — plain integer string.
  if (dotCount == 0 && commaCount == 0) {
    return double.tryParse(s);
  }

  // Both kinds present — whichever appears LAST is the decimal separator;
  // the other is thousands grouping, which we strip.  No ambiguity here.
  if (dotCount > 0 && commaCount > 0) {
    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    final decimalSep = lastDot > lastComma ? '.' : ',';
    final thousandsSep = decimalSep == '.' ? ',' : '.';
    final cleaned =
        s.replaceAll(thousandsSep, '').replaceAll(decimalSep, '.');
    return double.tryParse(cleaned);
  }

  // Only one kind present.
  final sep = dotCount > 0 ? '.' : ',';
  final count = dotCount + commaCount;

  // Multiple instances of one separator (e.g. "1.234.567" or "1,234,567")
  // — it can only be thousands grouping, never decimal.
  if (count > 1) {
    return double.tryParse(s.replaceAll(sep, ''));
  }

  // Single separator — disambiguate by digit counts on either side.
  final pos = s.indexOf(sep);
  final leadingDigits = pos;
  final trailingDigits = s.length - pos - 1;

  // Treat as thousands grouping only when the format matches a real
  // thousands group: 1–3 integer digits followed by exactly 3 trailing
  // digits.  Everything else is decimal.
  final isThousands =
      trailingDigits == 3 && leadingDigits >= 1 && leadingDigits <= 3;

  if (isThousands) {
    return double.tryParse(s.replaceAll(sep, ''));
  }
  return double.tryParse(s.replaceAll(sep, '.'));
}
