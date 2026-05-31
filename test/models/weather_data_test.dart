import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/models/weather_data.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 6, 1, 12, 0);

  WeatherData sample({
    int weatherCode = 0,
    double? uvIndexMax,
    DateTime? sunrise,
    DateTime? sunset,
  }) {
    return WeatherData(
      tempC: 22.5,
      humidity: 58,
      weatherCode: weatherCode,
      uvIndex: 4.2,
      uvIndexMax: uvIndexMax ?? 6.5,
      windSpeedKmh: 12.3,
      sunrise: sunrise ?? DateTime.utc(2026, 6, 1, 5, 30),
      sunset: sunset ?? DateTime.utc(2026, 6, 1, 21, 0),
      tempMaxC: 25.0,
      tempMinC: 14.0,
      fetchedAt: fixedNow,
    );
  }

  group('WeatherData JSON', () {
    test('round-trips all fields without loss', () {
      final original = sample();
      final restored = WeatherData.fromJson(original.toJson());

      expect(restored.tempC, original.tempC);
      expect(restored.humidity, original.humidity);
      expect(restored.weatherCode, original.weatherCode);
      expect(restored.uvIndex, original.uvIndex);
      expect(restored.uvIndexMax, original.uvIndexMax);
      expect(restored.windSpeedKmh, original.windSpeedKmh);
      expect(restored.sunrise, original.sunrise);
      expect(restored.sunset, original.sunset);
      expect(restored.tempMaxC, original.tempMaxC);
      expect(restored.tempMinC, original.tempMinC);
      expect(restored.fetchedAt, original.fetchedAt);
    });

    test('round-trip handles missing optional fields', () {
      final minimal = WeatherData(
        tempC: 15.0,
        humidity: 70,
        weatherCode: 3,
        fetchedAt: fixedNow,
      );
      final restored = WeatherData.fromJson(minimal.toJson());
      expect(restored.uvIndex, isNull);
      expect(restored.sunrise, isNull);
      expect(restored.tempMaxC, isNull);
    });
  });

  group('lightHours', () {
    test('returns elapsed hours between sunrise and sunset', () {
      final w = sample(
        sunrise: DateTime.utc(2026, 6, 1, 5, 0),
        sunset: DateTime.utc(2026, 6, 1, 21, 0),
      );
      expect(w.lightHours, 16.0);
    });

    test('returns null when sunrise or sunset missing', () {
      final w = WeatherData(
        tempC: 15.0,
        humidity: 70,
        weatherCode: 3,
        fetchedAt: fixedNow,
      );
      expect(w.lightHours, isNull);
    });
  });

  group('uvRisk', () {
    test('Low for UV < 3', () {
      expect(sample(uvIndexMax: 1.5).uvRisk, 'Low');
    });
    test('Moderate for 3 ≤ UV < 6', () {
      expect(sample(uvIndexMax: 4.0).uvRisk, 'Moderate');
    });
    test('High for 6 ≤ UV < 8', () {
      expect(sample(uvIndexMax: 7.0).uvRisk, 'High');
    });
    test('Very High for 8 ≤ UV < 11', () {
      expect(sample(uvIndexMax: 9.5).uvRisk, 'Very High');
    });
    test('Extreme for UV ≥ 11', () {
      expect(sample(uvIndexMax: 12.0).uvRisk, 'Extreme');
    });
  });

  group('conditionLabel / conditionIcon', () {
    test('clear sky', () {
      final w = sample(weatherCode: 0);
      expect(w.conditionLabel, 'Clear sky');
      expect(w.conditionIcon, Icons.wb_sunny_rounded);
    });

    test('overcast', () {
      final w = sample(weatherCode: 3);
      expect(w.conditionLabel, 'Overcast');
    });

    test('foggy', () {
      final w = sample(weatherCode: 45);
      expect(w.conditionLabel, 'Foggy');
    });

    test('rain shower', () {
      final w = sample(weatherCode: 80);
      expect(w.conditionLabel, 'Rain showers');
    });

    test('thunderstorm', () {
      final w = sample(weatherCode: 95);
      expect(w.conditionLabel, 'Thunderstorm');
      expect(w.conditionIcon, Icons.thunderstorm_rounded);
    });

    test('unknown code falls back gracefully', () {
      final w = sample(weatherCode: 999);
      expect(w.conditionLabel, 'Unknown');
    });
  });

  group('minutesAgo', () {
    test('returns absolute difference from now', () {
      // Build with fetchedAt 5 minutes in the past.
      final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final w = WeatherData(
        tempC: 20,
        humidity: 50,
        weatherCode: 0,
        fetchedAt: fiveMinAgo,
      );
      // Allow ±1 minute drift due to test timing.
      expect(w.minutesAgo, inInclusiveRange(4, 6));
    });
  });
}
