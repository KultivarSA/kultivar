import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/utils/amount_parser.dart';

void main() {
  group('parseUserAmount — unambiguous formats', () {
    test('plain integer', () {
      expect(parseUserAmount('100'), 100.0);
      expect(parseUserAmount('0'), 0.0);
    });

    test('US decimal (12.50)', () {
      expect(parseUserAmount('12.50'), 12.5);
      expect(parseUserAmount('0.99'), 0.99);
      expect(parseUserAmount('1234.567'), 1234.567);
    });

    test('EU decimal (12,50)', () {
      expect(parseUserAmount('12,50'), 12.5);
      expect(parseUserAmount('0,99'), 0.99);
    });

    test('US thousands + decimal (1,000.50)', () {
      expect(parseUserAmount('1,000.50'), 1000.5);
      expect(parseUserAmount('1,234,567.89'), 1234567.89);
    });

    test('EU thousands + decimal (1.000,50)', () {
      expect(parseUserAmount('1.000,50'), 1000.5);
      expect(parseUserAmount('1.234.567,89'), 1234567.89);
    });

    test('single trailing digit is always decimal', () {
      expect(parseUserAmount('1,5'), 1.5);
      expect(parseUserAmount('1.5'), 1.5);
    });

    test('two trailing digits is always decimal', () {
      expect(parseUserAmount('1,50'), 1.5);
      expect(parseUserAmount('1.50'), 1.5);
    });

    test('four+ trailing digits is always decimal', () {
      expect(parseUserAmount('1,2345'), 1.2345);
      expect(parseUserAmount('1.2345'), 1.2345);
    });
  });

  group('parseUserAmount — ambiguous 3-digit case', () {
    test('single separator with exactly 3 trailing digits is thousands', () {
      // "1,000" — could be 1.0 (EU) or 1000 (US thousands).
      // Documented convention: pick thousands.  Real-world grower
      // expenses are far more likely £1000 (e.g. a light) than £1.000
      // (a weird way to write "one whole pound").
      expect(parseUserAmount('1,000'), 1000.0);
      expect(parseUserAmount('1.000'), 1000.0);
      expect(parseUserAmount('25,500'), 25500.0);
    });

    test('multiple-separator case is never ambiguous', () {
      // "1,000.00" has two separators — the latter is clearly decimal,
      // so the former is thousands.  No ambiguity.
      expect(parseUserAmount('1,000.00'), 1000.0);
      expect(parseUserAmount('1.000,00'), 1000.0);
    });

    test('large integer part with 3 trailing digits is decimal, not thousands',
        () {
      // "1234.567" — 4-digit integer part means this can't be a thousands
      // group ("1,234,567" would be), so parse as a high-precision decimal.
      expect(parseUserAmount('1234.567'), 1234.567);
      expect(parseUserAmount('1234,567'), 1234.567);
    });

    test('repeated single separator is always thousands', () {
      // "1.234.567" can only be thousands grouping in EU notation —
      // there's no way for a single number to have two decimal points.
      expect(parseUserAmount('1.234.567'), 1234567.0);
      expect(parseUserAmount('1,234,567'), 1234567.0);
    });
  });

  group('parseUserAmount — sanitisation', () {
    test('trims whitespace', () {
      expect(parseUserAmount('  42  '), 42.0);
    });

    test('strips currency symbols', () {
      expect(parseUserAmount('£42.50'), 42.5);
      expect(parseUserAmount('\$1,000.00'), 1000.0);
      expect(parseUserAmount('€ 12,99'), 12.99);
    });

    test('strips stray letters', () {
      // Someone with caps lock on, or accidental international keyboard.
      expect(parseUserAmount('42abc'), 42.0);
    });
  });

  group('parseUserAmount — invalid inputs', () {
    test('empty string returns null', () {
      expect(parseUserAmount(''), isNull);
      expect(parseUserAmount('   '), isNull);
    });

    test('non-numeric returns null', () {
      expect(parseUserAmount('abc'), isNull);
      expect(parseUserAmount('foo'), isNull);
    });

    test('negative numbers return null (out of expense domain)', () {
      expect(parseUserAmount('-5'), isNull);
      expect(parseUserAmount('-1.50'), isNull);
    });

    test('only-separators string returns null', () {
      expect(parseUserAmount('.'), isNull);
      expect(parseUserAmount(','), isNull);
    });
  });

  group('parseUserAmount — regression cases from the original bug', () {
    test('the literal example from the sweep: 1,000.50', () {
      // Before B3: input formatter allowed [\d.,], save did
      // replaceAll(',', '.') → '1.000.50' → double.tryParse returns null
      // → silent failure.  Now: parses correctly to 1000.5.
      expect(parseUserAmount('1,000.50'), 1000.5);
    });

    test('previously fine: 12.50 stays parseable', () {
      expect(parseUserAmount('12.50'), 12.5);
    });

    test('previously fine: 12,50 stays parseable', () {
      expect(parseUserAmount('12,50'), 12.5);
    });
  });
}
