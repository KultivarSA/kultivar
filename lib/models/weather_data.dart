import 'package:flutter/material.dart';

/// Parsed snapshot from Open-Meteo API.
class WeatherData {
  final double tempC;
  final double humidity; // %
  final double? uvIndex;
  final double? windSpeedKmh;
  final int weatherCode; // WMO code
  final DateTime? sunrise;
  final DateTime? sunset;
  final double? tempMaxC;
  final double? tempMinC;
  final double? uvIndexMax;
  final DateTime fetchedAt;

  const WeatherData({
    required this.tempC,
    required this.humidity,
    required this.weatherCode,
    required this.fetchedAt,
    this.uvIndex,
    this.windSpeedKmh,
    this.sunrise,
    this.sunset,
    this.tempMaxC,
    this.tempMinC,
    this.uvIndexMax,
  });

  // ── Computed ──────────────────────────────────────────────────────────────

  /// Total daylight in hours, or null if sunrise/sunset unavailable.
  double? get lightHours {
    if (sunrise == null || sunset == null) return null;
    final diff = sunset!.difference(sunrise!);
    return diff.inMinutes / 60.0;
  }

  /// UV risk label based on index value.
  String get uvRisk {
    final uv = uvIndexMax ?? uvIndex;
    if (uv == null) return 'Unknown';
    if (uv < 3) return 'Low';
    if (uv < 6) return 'Moderate';
    if (uv < 8) return 'High';
    if (uv < 11) return 'Very High';
    return 'Extreme';
  }

  Color get uvColor {
    final uv = uvIndexMax ?? uvIndex;
    if (uv == null) return Colors.grey;
    if (uv < 3) return const Color(0xFF4CAF50); // green
    if (uv < 6) return const Color(0xFFFFC107); // amber
    if (uv < 8) return const Color(0xFFFF9800); // orange
    if (uv < 11) return const Color(0xFFF44336); // red
    return const Color(0xFF9C27B0); // purple
  }

  /// Human-readable weather condition from WMO code.
  String get conditionLabel {
    if (weatherCode == 0) return 'Clear sky';
    if (weatherCode == 1) return 'Mainly clear';
    if (weatherCode == 2) return 'Partly cloudy';
    if (weatherCode == 3) return 'Overcast';
    if (weatherCode == 45 || weatherCode == 48) return 'Foggy';
    if (weatherCode >= 51 && weatherCode <= 57) return 'Drizzle';
    if (weatherCode >= 61 && weatherCode <= 67) return 'Rain';
    if (weatherCode >= 71 && weatherCode <= 77) return 'Snow';
    if (weatherCode >= 80 && weatherCode <= 82) return 'Rain showers';
    if (weatherCode == 85 || weatherCode == 86) return 'Snow showers';
    if (weatherCode >= 95 && weatherCode <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  /// Material icon representing the weather condition.
  IconData get conditionIcon {
    if (weatherCode == 0) return Icons.wb_sunny_rounded;
    if (weatherCode <= 2) return Icons.wb_cloudy_rounded;
    if (weatherCode == 3) return Icons.cloud_rounded;
    if (weatherCode == 45 || weatherCode == 48) return Icons.foggy;
    if (weatherCode >= 51 && weatherCode <= 67) return Icons.grain;
    if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit;
    if (weatherCode >= 80 && weatherCode <= 82) return Icons.water_drop_rounded;
    if (weatherCode == 85 || weatherCode == 86) return Icons.ac_unit;
    if (weatherCode >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }

  /// Minutes since data was fetched.
  int get minutesAgo =>
      DateTime.now().difference(fetchedAt).inMinutes.abs();

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'tempC': tempC,
        'humidity': humidity,
        'uvIndex': uvIndex,
        'windSpeedKmh': windSpeedKmh,
        'weatherCode': weatherCode,
        'sunrise': sunrise?.toIso8601String(),
        'sunset': sunset?.toIso8601String(),
        'tempMaxC': tempMaxC,
        'tempMinC': tempMinC,
        'uvIndexMax': uvIndexMax,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        tempC: (json['tempC'] as num).toDouble(),
        humidity: (json['humidity'] as num).toDouble(),
        weatherCode: json['weatherCode'] as int,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        uvIndex: (json['uvIndex'] as num?)?.toDouble(),
        windSpeedKmh: (json['windSpeedKmh'] as num?)?.toDouble(),
        sunrise: json['sunrise'] != null
            ? DateTime.parse(json['sunrise'] as String)
            : null,
        sunset: json['sunset'] != null
            ? DateTime.parse(json['sunset'] as String)
            : null,
        tempMaxC: (json['tempMaxC'] as num?)?.toDouble(),
        tempMinC: (json['tempMinC'] as num?)?.toDouble(),
        uvIndexMax: (json['uvIndexMax'] as num?)?.toDouble(),
      );
}
