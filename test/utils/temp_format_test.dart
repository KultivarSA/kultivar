import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/main.dart';
import 'package:kultivar/utils/temp_format.dart';

void main() {
  group('temp_format', () {
    setUp(() {
      KultivarApp.useFahrenheitNotifier.value = false; // default
    });

    test('formatTemp renders °C by default with one decimal', () {
      expect(formatTemp(22.5), '22.5°C');
      expect(formatTemp(22.5, decimals: 0), '23°C');
    });

    test('formatTemp renders °F when toggle is on', () {
      KultivarApp.useFahrenheitNotifier.value = true;
      // 22.5°C = 72.5°F
      expect(formatTemp(22.5), '72.5°F');
    });

    test('toStorageTemp identity in C mode', () {
      expect(toStorageTemp(20.0), 20.0);
    });

    test('toStorageTemp converts F input back to C', () {
      KultivarApp.useFahrenheitNotifier.value = true;
      // 72.5°F → 22.5°C
      expect(toStorageTemp(72.5), closeTo(22.5, 0.01));
    });

    test('fromStorageTemp is inverse of toStorageTemp', () {
      KultivarApp.useFahrenheitNotifier.value = true;
      const stored = 18.3;
      final displayed = fromStorageTemp(stored);
      expect(toStorageTemp(displayed), closeTo(stored, 0.01));
    });

    test('tempUnitSuffix tracks the notifier', () {
      KultivarApp.useFahrenheitNotifier.value = false;
      expect(tempUnitSuffix, '°C');
      KultivarApp.useFahrenheitNotifier.value = true;
      expect(tempUnitSuffix, '°F');
    });
  });
}
