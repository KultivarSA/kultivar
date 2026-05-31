import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_data.dart';

/// Fetches outdoor weather from Open-Meteo (free, no API key).
/// Location (lat/lon) is stored in SharedPreferences and updated on request.
/// Responses are cached for [_cacheTtl] to avoid hammering the API.
class WeatherService {
  // ── Storage keys ──────────────────────────────────────────────────────────
  static const _latKey = 'weather_lat';
  static const _lonKey = 'weather_lon';
  static const _locationLabelKey = 'weather_location_label';
  static const _cacheJsonKey = 'weather_cache_json';
  static const _cacheTsKey = 'weather_cache_ts';

  /// How long cached data is considered fresh.
  static const _cacheTtl = Duration(hours: 1);

  // ── Location persistence ──────────────────────────────────────────────────

  static Future<double?> loadLat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_latKey);
  }

  static Future<double?> loadLon() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_lonKey);
  }

  static Future<String?> loadLocationLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_locationLabelKey);
  }

  static Future<void> saveLocation(
    double lat,
    double lon, {
    String? label,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, lat);
    await prefs.setDouble(_lonKey, lon);
    if (label != null) {
      await prefs.setString(_locationLabelKey, label);
    } else {
      await prefs.remove(_locationLabelKey);
    }
    // Invalidate the cache so next fetch uses the new location.
    await prefs.remove(_cacheJsonKey);
    await prefs.remove(_cacheTsKey);
  }

  static Future<void> clearLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latKey);
    await prefs.remove(_lonKey);
    await prefs.remove(_locationLabelKey);
    await prefs.remove(_cacheJsonKey);
    await prefs.remove(_cacheTsKey);
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  /// Requests device location. Returns `null` if permission denied or GPS
  /// unavailable. Throws a [WeatherLocationException] with a human-readable
  /// message on denial so the caller can surface it to the user.
  static Future<Position?> requestDeviceLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const WeatherLocationException(
          'Location services are disabled on this device.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const WeatherLocationException(
            'Location permission was denied. Please enable it in Settings.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const WeatherLocationException(
          'Location permission is permanently denied. Enable it in Settings > Kultivar.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low, // city-level is fine for weather
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  // ── Cache ─────────────────────────────────────────────────────────────────

  static Future<WeatherData?> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_cacheTsKey);
    if (ts == null) return null;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (age > _cacheTtl) return null;
    final raw = prefs.getString(_cacheJsonKey);
    if (raw == null) return null;
    try {
      return WeatherData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCache(WeatherData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheJsonKey, jsonEncode(data.toJson()));
    await prefs.setInt(
        _cacheTsKey, data.fetchedAt.millisecondsSinceEpoch);
  }

  // ── API call ──────────────────────────────────────────────────────────────

  /// Fetches weather for [lat]/[lon]. Uses cached data if fresh.
  /// Pass [forceRefresh] to bypass the cache.
  static Future<WeatherData> fetchWeather({
    required double lat,
    required double lon,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _loadCache();
      if (cached != null) return cached;
    }

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current':
          'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,uv_index',
      'daily':
          'sunrise,sunset,temperature_2m_max,temperature_2m_min,uv_index_max',
      'timezone': 'auto',
      'forecast_days': '1',
      'wind_speed_unit': 'kmh',
    });

    final response =
        await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw WeatherFetchException(
          'Open-Meteo returned status ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final current = body['current'] as Map<String, dynamic>;
    final daily = body['daily'] as Map<String, dynamic>;

    final data = WeatherData(
      tempC: (current['temperature_2m'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      uvIndex: (current['uv_index'] as num?)?.toDouble(),
      windSpeedKmh: (current['wind_speed_10m'] as num?)?.toDouble(),
      sunrise: _parseFirst(daily['sunrise']),
      sunset: _parseFirst(daily['sunset']),
      tempMaxC: _firstNum(daily['temperature_2m_max']),
      tempMinC: _firstNum(daily['temperature_2m_min']),
      uvIndexMax: _firstNum(daily['uv_index_max']),
      fetchedAt: DateTime.now(),
    );

    await _saveCache(data);
    return data;
  }

  static DateTime? _parseFirst(dynamic list) {
    if (list is List && list.isNotEmpty && list.first is String) {
      return DateTime.tryParse(list.first as String);
    }
    return null;
  }

  static double? _firstNum(dynamic list) {
    if (list is List && list.isNotEmpty && list.first is num) {
      return (list.first as num).toDouble();
    }
    return null;
  }

  // ── Geocoding (U10) ─────────────────────────────────────────────────────
  //
  // Open-Meteo also hosts a free reverse-geocoding endpoint that doesn't
  // require an API key.  We use it to turn user-typed city names into
  // lat/lon pairs so the manual location flow no longer requires copying
  // coordinates out of Google Maps.

  /// Search for cities matching [query].  Returns up to 10 hits ordered
  /// by population/relevance.  Queries shorter than 2 chars return `[]`.
  ///
  /// Failures (offline, malformed response, timeout) surface as an empty
  /// list rather than throwing — the manual-location UI then falls
  /// through to the existing lat/lon inputs.
  static Future<List<GeocodingHit>> searchCity(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': trimmed,
      'count': '10',
      'language': 'en',
      'format': 'json',
    });

    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>?;
      if (results == null) return const [];
      return results.map((raw) {
        final r = raw as Map<String, dynamic>;
        return GeocodingHit(
          name: r['name'] as String? ?? '',
          latitude: (r['latitude'] as num).toDouble(),
          longitude: (r['longitude'] as num).toDouble(),
          admin1: r['admin1'] as String?,
          country: r['country'] as String?,
        );
      }).toList(growable: false);
    } catch (_) {
      // Silent — UI degrades to the manual lat/lon inputs.
      return const [];
    }
  }
}

// ── Geocoding (U10) ───────────────────────────────────────────────────────────
//
// Open-Meteo also hosts a free reverse-geocoding endpoint that doesn't
// require an API key.  We use it to turn user-typed city names into
// lat/lon pairs so the manual location flow no longer requires copying
// coordinates out of Google Maps.

/// A single geocoding hit returned by [WeatherService.searchCity].
class GeocodingHit {
  final String name;
  final String? admin1; // e.g. "England", "California"
  final String? country;
  final double latitude;
  final double longitude;

  const GeocodingHit({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.admin1,
    this.country,
  });

  /// Pretty display string: "London, England, United Kingdom".
  String get displayName {
    final parts = [
      name,
      if (admin1 != null && admin1!.isNotEmpty) admin1!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.join(', ');
  }
}

// ── Exceptions ────────────────────────────────────────────────────────────────

class WeatherLocationException implements Exception {
  final String message;
  const WeatherLocationException(this.message);
  @override
  String toString() => message;
}

class WeatherFetchException implements Exception {
  final String message;
  const WeatherFetchException(this.message);
  @override
  String toString() => message;
}
