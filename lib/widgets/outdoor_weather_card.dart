import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/plant.dart';
import '../models/weather_data.dart';
import '../repository/grow_repository.dart';
import '../services/weather_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'skeleton.dart';

enum _LocationChoice { cancel, detect, manual, useGlobal }

// ── Outdoor weather card ──────────────────────────────────────────────────────

/// Shows current weather conditions for outdoor plants.
///
/// Location precedence (B8 — per-plant override):
///   1. plant.latitude / plant.longitude when both set
///   2. Global WeatherService location otherwise
///
/// Setting / changing the location through this card always updates the
/// **plant's** override — never overwrites the global default — so users
/// with plants at multiple sites can keep them straight without one
/// stomping on another.
class OutdoorWeatherCard extends StatefulWidget {
  final Plant plant;
  const OutdoorWeatherCard({super.key, required this.plant});

  @override
  State<OutdoorWeatherCard> createState() => _OutdoorWeatherCardState();
}

class _OutdoorWeatherCardState extends State<OutdoorWeatherCard>
    with WidgetsBindingObserver {
  // null = loading, ready to start
  double? _lat;
  double? _lon;
  String? _label;
  bool _locationLoaded = false;
  bool _isPlantOverride = false; // true when location came from the Plant

  WeatherData? _weather;
  bool _fetching = false;
  String? _error;

  /// Cache TTL must match what [WeatherService] enforces internally.
  /// Refresh-on-resume only kicks in once the cached value is older than
  /// this, so we don't slam the API every time the user backgrounds the
  /// app for 30 seconds.
  static const Duration _resumeRefreshThreshold = Duration(minutes: 55);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user comes back from background, refetch if our cached
    // weather is stale.  Without this, the "Updated 4 min ago" label can
    // sit unchanged for hours until the user manually pulls refresh.
    if (state != AppLifecycleState.resumed) return;
    final w = _weather;
    if (w == null) return;
    if (DateTime.now().difference(w.fetchedAt) >= _resumeRefreshThreshold) {
      _fetchWeather(forceRefresh: true);
    }
  }

  @override
  void didUpdateWidget(covariant OutdoorWeatherCard old) {
    super.didUpdateWidget(old);
    // Plant edit dialog can swap the location out from under us — re-init
    // when the plant's lat/lon actually changed.
    if (old.plant.latitude != widget.plant.latitude ||
        old.plant.longitude != widget.plant.longitude) {
      _init();
    }
  }

  Future<void> _init() async {
    // Prefer the plant's own override when both coords are present.
    if (widget.plant.latitude != null && widget.plant.longitude != null) {
      if (!mounted) return;
      setState(() {
        _lat = widget.plant.latitude;
        _lon = widget.plant.longitude;
        _label = widget.plant.locationLabel;
        _isPlantOverride = true;
        _locationLoaded = true;
      });
      await _fetchWeather(forceRefresh: true);
      return;
    }

    // Otherwise fall back to the global default.
    final lat = await WeatherService.loadLat();
    final lon = await WeatherService.loadLon();
    final label = await WeatherService.loadLocationLabel();
    if (!mounted) return;
    setState(() {
      _lat = lat;
      _lon = lon;
      _label = label;
      _isPlantOverride = false;
      _locationLoaded = true;
    });
    if (lat != null && lon != null) {
      await _fetchWeather();
    }
  }

  Future<void> _fetchWeather({bool forceRefresh = false}) async {
    if (_lat == null || _lon == null) return;
    setState(() {
      _fetching = true;
      _error = null;
    });
    try {
      final data = await WeatherService.fetchWeather(
        lat: _lat!,
        lon: _lon!,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _weather = data;
        _fetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _fetching = false;
      });
    }
  }

  /// Persists [lat]/[lon] (and optional [label]) as either a per-plant
  /// override or the global default, depending on what the user just
  /// configured.
  ///
  /// We default to **per-plant** for two reasons:
  /// 1. The card lives inside Plant Detail, so the user's mental model is
  ///    "I'm setting the location for THIS plant".
  /// 2. It avoids accidentally clobbering another outdoor plant's
  ///    location when the user updates this one.
  Future<void> _persistLocation(double lat, double lon, {String? label}) async {
    if (!mounted) return;
    final repo = context.read<GrowRepository>();
    repo.updatePlant(widget.plant.copyWith(
      latitude: lat,
      longitude: lon,
      locationLabel: label,
    ));
    setState(() {
      _lat = lat;
      _lon = lon;
      _label = label;
      _isPlantOverride = true;
    });
  }

  Future<void> _detectLocation() async {
    setState(() {
      _fetching = true;
      _error = null;
    });
    try {
      final pos = await WeatherService.requestDeviceLocation();
      if (pos == null) return;
      // If the user has no global default yet, also seed it — that way
      // their first detected location populates both the plant override
      // AND the global fallback for any future outdoor plants.
      final globalLat = await WeatherService.loadLat();
      if (globalLat == null) {
        await WeatherService.saveLocation(pos.latitude, pos.longitude);
      }
      await _persistLocation(pos.latitude, pos.longitude);
      await _fetchWeather(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is WeatherLocationException
            ? e.message
            : 'Could not get location.';
        _fetching = false;
      });
    }
  }

  Future<void> _enterManually() async {
    final result = await _ManualLocationDialog.show(context);
    if (result == null) return;
    await _persistLocation(result.$1, result.$2, label: result.$3);
    await _fetchWeather(forceRefresh: true);
  }

  Future<void> _clearOverride() async {
    final repo = context.read<GrowRepository>();
    repo.updatePlant(widget.plant.copyWith(
      latitude: null,
      longitude: null,
      locationLabel: null,
    ));
    // Re-init to pick up the global default (or show the empty-state
    // prompt when no global is set).
    await _init();
  }

  Future<void> _changeLocation() async {
    final globalLat = await WeatherService.loadLat();
    final hasGlobalDefault = globalLat != null;
    if (!mounted) return;

    final choice = await showDialog<_LocationChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text('Change Location'),
        content: Text(
          _isPlantOverride
              ? 'This plant has its own location override. How would you like to update it?'
              : 'How would you like to set this plant\'s location?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LocationChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LocationChoice.detect),
            child: const Text('Detect GPS'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LocationChoice.manual),
            child: const Text('Enter manually'),
          ),
          // Only offer the "use global" path when there's a global default
          // available AND the current location is a plant override.
          if (_isPlantOverride && hasGlobalDefault)
            TextButton(
              onPressed: () => Navigator.pop(ctx, _LocationChoice.useGlobal),
              child: const Text('Use global'),
            ),
        ],
      ),
    );

    switch (choice) {
      case _LocationChoice.detect:
        await _detectLocation();
        break;
      case _LocationChoice.manual:
        await _enterManually();
        break;
      case _LocationChoice.useGlobal:
        await _clearOverride();
        break;
      case _LocationChoice.cancel:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locationLoaded) {
      // A6 — full-card skeleton instead of a centred spinner.
      // Reads as "weather is loading" rather than "something
      // generic is busy", and pre-shapes the layout so the
      // surrounding Plant Detail content doesn't jump when the
      // real card renders.
      return const SkeletonWeatherCard();
    }

    if (_lat == null || _lon == null) {
      return _SetLocationPrompt(
        onDetect: _detectLocation,
        onManual: _enterManually,
        loading: _fetching,
        error: _error,
      );
    }

    return _cardShell(context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              fetching: _fetching,
              weather: _weather,
              locationLabel: _label,
              isPlantOverride: _isPlantOverride,
              onRefresh: () => _fetchWeather(forceRefresh: true),
              onChangeLocation: _changeLocation,
            ),
            if (_fetching && _weather == null)
              // A6 — body skeleton (header above is already
              // rendered with real labels) so the user sees the
              // weather scaffolding fill in rather than a spinner.
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLine(height: 24, width: 60),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonLine(height: 12),
                    SizedBox(height: AppSpacing.xs),
                    SkeletonLine(height: 12, width: 200),
                  ],
                ),
              )
            else if (_error != null && _weather == null)
              _ErrorBody(error: _error!, onRetry: _fetchWeather)
            else if (_weather != null)
              _WeatherBody(weather: _weather!),
          ],
        ));
  }

  Widget _cardShell(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final bool fetching;
  final WeatherData? weather;
  final String? locationLabel;
  final bool isPlantOverride;
  final VoidCallback onRefresh;
  final VoidCallback onChangeLocation;

  const _CardHeader({
    required this.fetching,
    required this.weather,
    required this.locationLabel,
    required this.isPlantOverride,
    required this.onRefresh,
    required this.onChangeLocation,
  });

  @override
  Widget build(BuildContext context) {
    final minAgo = weather?.minutesAgo;
    final freshLabel = minAgo == null
        ? ''
        : minAgo < 1
            ? 'just now'
            : '$minAgo min ago';

    // Build the right-side metadata line:
    //   "Back garden · just now"   (plant override + freshness)
    //   "just now"                  (no label, fall through)
    //   ""                          (loading initial fetch)
    final detailParts = <String>[
      if (locationLabel != null && locationLabel!.isNotEmpty) locationLabel!,
      if (freshLabel.isNotEmpty) freshLabel,
    ];

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, 0),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny_rounded,
              color: Color(0xFF4CAF50), size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Outdoor Conditions',
            style: AppTypography.labelLarge(context).copyWith(
              color: const Color(0xFF4CAF50),
              fontWeight: FontWeight.w700,
            ),
          ),
          // Subtle "per plant" marker so multi-site users can spot at a
          // glance that this card is using the plant's override, not the
          // global default.
          if (isPlantOverride) ...[
            const SizedBox(width: AppSpacing.xs),
            Tooltip(
              message: 'This plant has its own location override',
              child: Icon(Icons.push_pin_rounded,
                  size: 11,
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.7)),
            ),
          ],
          const Spacer(),
          if (detailParts.isNotEmpty)
            Flexible(
              child: Text(
                detailParts.join(' · '),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTypography.bodySmall(context)
                    .copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          const SizedBox(width: AppSpacing.xxs),
          SizedBox(
            width: 32,
            height: 32,
            child: fetching
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: onRefresh,
                    color: Theme.of(context).colorScheme.outline,
                    padding: EdgeInsets.zero,
                    tooltip: 'Refresh',
                  ),
          ),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
              onPressed: onChangeLocation,
              color: Theme.of(context).colorScheme.outline,
              padding: EdgeInsets.zero,
              tooltip: 'Change location',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weather body ──────────────────────────────────────────────────────────────

class _WeatherBody extends StatelessWidget {
  final WeatherData weather;
  const _WeatherBody({required this.weather});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Condition + temp ──────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(weather.conditionIcon,
                  size: 36, color: _conditionColor(weather.weatherCode)),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weather.conditionLabel,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${weather.tempC.round()}°C',
                        style: AppTypography.headlineLarge(context).copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (weather.tempMaxC != null && weather.tempMinC != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '↑${weather.tempMaxC!.round()}°  ↓${weather.tempMinC!.round()}°',
                          style: AppTypography.bodySmall(context).copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Stat row ──────────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Stat(
                icon: Icons.water_drop_rounded,
                label: '${weather.humidity.round()}%',
                tooltip: 'Relative humidity',
                color: Colors.blueAccent,
              ),
              if (weather.windSpeedKmh != null)
                _Stat(
                  icon: Icons.air_rounded,
                  label: '${weather.windSpeedKmh!.round()} km/h',
                  tooltip: 'Wind speed',
                  color: Colors.blueGrey,
                ),
              if (weather.uvIndexMax != null || weather.uvIndex != null)
                _Stat(
                  icon: Icons.wb_sunny_outlined,
                  label:
                      'UV ${(weather.uvIndexMax ?? weather.uvIndex)!.toStringAsFixed(1)} · ${weather.uvRisk}',
                  tooltip: 'UV index',
                  color: weather.uvColor,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Sunrise / sunset bar ──────────────────────────────────────────
          if (weather.sunrise != null && weather.sunset != null) ...[
            _SunBar(weather: weather),
          ],
        ],
      ),
    );
  }

  Color _conditionColor(int code) {
    if (code == 0) return const Color(0xFFFFC107); // sunny amber
    if (code <= 2) return const Color(0xFF90CAF9); // light blue
    if (code == 3) return Colors.blueGrey;
    if (code == 45 || code == 48) return Colors.grey;
    if (code >= 51 && code <= 82) return Colors.blueAccent;
    if (code >= 71 && code <= 86) return Colors.lightBlue;
    if (code >= 95) return Colors.deepPurple;
    return Colors.blueGrey;
  }
}

// ── Sun bar ───────────────────────────────────────────────────────────────────

class _SunBar extends StatelessWidget {
  final WeatherData weather;
  const _SunBar({required this.weather});

  String _hm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final sunrise = weather.sunrise!;
    final sunset = weather.sunset!;
    final light = weather.lightHours;

    // Progress 0.0–1.0 of daylight elapsed
    final now = DateTime.now();
    double progress = 0;
    if (now.isAfter(sunrise) && now.isBefore(sunset)) {
      progress = now.difference(sunrise).inMinutes /
          sunset.difference(sunrise).inMinutes;
    } else if (now.isAfter(sunset)) {
      progress = 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wb_twilight_rounded,
                size: 14, color: Color(0xFFFFB300)),
            const SizedBox(width: AppSpacing.xxs),
            Text(_hm(sunrise),
                style: AppTypography.bodySmall(context).copyWith(
                    color: const Color(0xFFFFB300),
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (light != null)
              Text(
                '☀ ${light.floor()}h ${((light % 1) * 60).round()}m daylight',
                style: AppTypography.bodySmall(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            const Spacer(),
            Text(_hm(sunset),
                style: AppTypography.bodySmall(context).copyWith(
                    color: const Color(0xFFFF7043),
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: AppSpacing.xxs),
            const Icon(Icons.nights_stay_rounded,
                size: 14, color: Color(0xFFFF7043)),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFC107)),
          ),
        ),
      ],
    );
  }
}

// ── Small stat chip ───────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final Color color;

  const _Stat({
    required this.icon,
    required this.label,
    required this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.bodySmall(context)
                .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: chip);
    }
    return chip;
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBody({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 32, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.xs),
          Text(
            error,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(context)
                .copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

// ── Set location prompt ───────────────────────────────────────────────────────

class _SetLocationPrompt extends StatelessWidget {
  final VoidCallback onDetect;
  final VoidCallback onManual;
  final bool loading;
  final String? error;

  const _SetLocationPrompt({
    required this.onDetect,
    required this.onManual,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.wb_sunny_rounded,
                    color: Color(0xFF4CAF50), size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Outdoor Conditions',
                  style: AppTypography.labelLarge(context).copyWith(
                    color: const Color(0xFF4CAF50),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Icon(Icons.location_off_rounded,
                size: 32,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Set your outdoor location to see local weather, '
              'sunrise/sunset times and UV index.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(context).copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall(context)
                    .copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (loading)
              const CircularProgressIndicator(strokeWidth: 2)
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.gps_fixed_rounded, size: 16),
                      label: const Text('Detect GPS'),
                      onPressed: onDetect,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50),
                        side: const BorderSide(color: Color(0xFF4CAF50)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Enter manually'),
                      onPressed: onManual,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Manual location dialog ────────────────────────────────────────────────────

class _ManualLocationDialog extends StatefulWidget {
  const _ManualLocationDialog();

  static Future<(double, double, String?)?> show(BuildContext context) {
    return showDialog<(double, double, String?)?>(
      context: context,
      builder: (_) => const _ManualLocationDialog(),
    );
  }

  @override
  State<_ManualLocationDialog> createState() => _ManualLocationDialogState();
}

class _ManualLocationDialogState extends State<_ManualLocationDialog> {
  final _cityCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  String? _error;

  // ── City search state (U10) ──
  Timer? _searchDebounce;
  bool _searching = false;
  List<GeocodingHit> _results = const [];
  bool _showResults = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _cityCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  /// Debounced city-name search.  Hits Open-Meteo's free geocoding API
  /// and updates [_results] in-place.  No external API key required.
  void _onCityChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      final trimmed = value.trim();
      if (trimmed.length < 2) {
        setState(() {
          _results = const [];
          _showResults = false;
        });
        return;
      }
      setState(() => _searching = true);
      final hits = await WeatherService.searchCity(trimmed);
      if (!mounted) return;
      setState(() {
        _results = hits;
        _searching = false;
        _showResults = true;
      });
    });
  }

  void _selectHit(GeocodingHit hit) {
    setState(() {
      _latCtrl.text = hit.latitude.toStringAsFixed(4);
      _lonCtrl.text = hit.longitude.toStringAsFixed(4);
      // Pre-fill the label with the city name only when the user hasn't
      // typed their own custom label yet — never overwrite a personal
      // note like "Back garden" with "London, England, UK".
      if (_labelCtrl.text.trim().isEmpty) {
        _labelCtrl.text = hit.name;
      }
      _cityCtrl.text = hit.displayName;
      _showResults = false;
      _error = null;
    });
  }

  void _submit() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lon = double.tryParse(_lonCtrl.text.trim());
    if (lat == null || lat < -90 || lat > 90) {
      setState(() => _error = 'Latitude must be between -90 and 90');
      return;
    }
    if (lon == null || lon < -180 || lon > 180) {
      setState(() => _error = 'Longitude must be between -180 and 180');
      return;
    }
    final label =
        _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim();
    Navigator.pop(context, (lat, lon, label));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: const Text('Enter Location'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Type a city name and pick a match, or enter '
              'coordinates manually below.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            // ── City search ──
            TextField(
              controller: _cityCtrl,
              autofocus: true,
              onChanged: _onCityChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search city',
                hintText: 'London, Madrid, Berlin…',
                prefixIcon: const Icon(Icons.public_rounded, size: 18),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_cityCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: 'Clear search',
                            onPressed: () => setState(() {
                              _cityCtrl.clear();
                              _results = const [];
                              _showResults = false;
                            }),
                          )
                        : null),
              ),
            ),
            if (_showResults && _results.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: Container(
                  margin: const EdgeInsets.only(top: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final hit = _results[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined,
                            size: 18),
                        title: Text(
                          hit.name,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: hit.country != null
                            ? Text(
                                [
                                  if (hit.admin1 != null) hit.admin1!,
                                  hit.country!,
                                ].join(', '),
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () => _selectHit(hit),
                      );
                    },
                  ),
                ),
              ),
            if (_showResults && !_searching && _results.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'No cities matched — check spelling or enter coordinates manually.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            // ── Manual coordinates ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[-\d.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: '51.5074',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextField(
                    controller: _lonCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[-\d.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: '-0.1278',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g. Back garden',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Set Location'),
        ),
      ],
    );
  }
}
