import '../models/plant_note.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Acceptable pH range for cannabis (covers soil 6.0–7.0 and hydro 5.5–6.5).
const double _phLow = 5.8;
const double _phHigh = 7.0;

/// EC threshold above which nutrient burn risk is flagged (mS/cm).
const double _ecBurnThreshold = 3.0;

/// Minimum rise per step to flag an EC upward trend.
const double _ecTrendStep = 0.25;

/// How many of the most recent readings to use for trend/average calculations.
const int _lookback = 5;

// ── Result types ─────────────────────────────────────────────────────────────

enum FeedingAlertSeverity { info, warning }

class FeedingAlert {
  final String message;
  final FeedingAlertSeverity severity;

  const FeedingAlert(this.message, this.severity);
}

class FeedingAnalyticsSummary {
  final List<FeedingAlert> alerts;

  /// Recent average pH (combined feed + water pH readings), or null when
  /// fewer than 2 data points exist.
  final double? avgPh;

  /// Last recorded EC value (mS/cm), or null when no EC readings exist.
  final double? latestEc;

  /// Number of pH readings used for [avgPh].
  final int phReadingCount;

  /// Number of EC readings available.
  final int ecReadingCount;

  bool get hasAlerts => alerts.isNotEmpty;
  bool get hasData => phReadingCount >= 2 || ecReadingCount >= 2;

  const FeedingAnalyticsSummary({
    required this.alerts,
    this.avgPh,
    this.latestEc,
    this.phReadingCount = 0,
    this.ecReadingCount = 0,
  });

  static const empty = FeedingAnalyticsSummary(alerts: []);
}

// ── Private helpers ───────────────────────────────────────────────────────────

/// Returns true when [values] are monotonically increasing by at least
/// [minStep] on average between consecutive readings.
bool _isTrendingUp(List<double> values, double minStep) {
  if (values.length < 2) return false;
  int rises = 0;
  for (int i = 1; i < values.length; i++) {
    if (values[i] - values[i - 1] >= minStep) rises++;
  }
  // Require at least half the steps to qualify as a trend.
  return rises >= (values.length - 1) / 2;
}

bool _isTrendingDown(List<double> values, double minStep) {
  if (values.length < 2) return false;
  int drops = 0;
  for (int i = 1; i < values.length; i++) {
    if (values[i - 1] - values[i] >= minStep) drops++;
  }
  return drops >= (values.length - 1) / 2;
}

double _avg(List<double> list) =>
    list.reduce((a, b) => a + b) / list.length;

// ── Public API ────────────────────────────────────────────────────────────────

/// Analyses feeding and watering notes for a single plant and returns
/// actionable pH / EC alerts.
///
/// pH sources: [FeedingDetails.phIn], [WateringDetails.phIn],
///             [WateringDetails.runoffPh] (lower priority — labelled separately).
/// EC sources: [FeedingDetails.ecIn].
FeedingAnalyticsSummary computeFeedingAnalytics(List<PlantNote> notes) {
  // Sort chronologically once.
  final sorted = [...notes]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  // Collect pH readings (feed + water input pH; exclude runoff for the
  // primary average — runoff is a separate signal).
  final phReadings = <double>[];
  final runoffReadings = <double>[];
  final ecReadings = <double>[];

  for (final note in sorted) {
    if (note.feedingDetails != null) {
      final fd = note.feedingDetails!;
      if (fd.phIn != null) phReadings.add(fd.phIn!);
      if (fd.ecIn != null) ecReadings.add(fd.ecIn!);
    }
    if (note.wateringDetails != null) {
      final wd = note.wateringDetails!;
      if (wd.phIn != null) phReadings.add(wd.phIn!);
      if (wd.runoffPh != null) runoffReadings.add(wd.runoffPh!);
    }
  }

  if (phReadings.isEmpty && ecReadings.isEmpty) {
    return FeedingAnalyticsSummary.empty;
  }

  final alerts = <FeedingAlert>[];

  // ── pH analysis ───────────────────────────────
  double? avgPh;
  if (phReadings.isNotEmpty) {
    final recent = phReadings.length > _lookback
        ? phReadings.sublist(phReadings.length - _lookback)
        : phReadings;

    avgPh = _avg(recent);

    if (avgPh > _phHigh) {
      alerts.add(FeedingAlert(
        'Recent pH averaged ${avgPh.toStringAsFixed(1)} — above the ideal '
        '${_phLow.toStringAsFixed(1)}–${_phHigh.toStringAsFixed(1)} range. '
        'High pH locks out phosphorus and iron.',
        FeedingAlertSeverity.warning,
      ));
    } else if (avgPh < _phLow) {
      alerts.add(FeedingAlert(
        'Recent pH averaged ${avgPh.toStringAsFixed(1)} — below the ideal '
        '${_phLow.toStringAsFixed(1)}–${_phHigh.toStringAsFixed(1)} range. '
        'Low pH can cause calcium and magnesium deficiencies.',
        FeedingAlertSeverity.warning,
      ));
    } else if (recent.length >= 3) {
      // Check for a creeping trend even while still in range.
      if (_isTrendingUp(recent, 0.15) && avgPh > _phHigh - 0.3) {
        alerts.add(FeedingAlert(
          'pH is trending upward (avg ${avgPh.toStringAsFixed(1)}) and '
          'approaching the upper limit of ${_phHigh.toStringAsFixed(1)}. '
          'Monitor closely.',
          FeedingAlertSeverity.info,
        ));
      } else if (_isTrendingDown(recent, 0.15) && avgPh < _phLow + 0.3) {
        alerts.add(FeedingAlert(
          'pH is trending downward (avg ${avgPh.toStringAsFixed(1)}) and '
          'approaching the lower limit of ${_phLow.toStringAsFixed(1)}. '
          'Monitor closely.',
          FeedingAlertSeverity.info,
        ));
      }
    }

    // Runoff vs input divergence — flag when runoff pH is more than 0.8
    // above or below the input average (indicates root zone pH drift).
    if (runoffReadings.length >= 2 && phReadings.isNotEmpty) {
      final avgRunoff = _avg(runoffReadings
          .sublist(runoffReadings.length > _lookback
              ? runoffReadings.length - _lookback
              : 0));
      final inputAvg = avgPh;
      final diff = avgRunoff - inputAvg;
      if (diff.abs() > 0.8) {
        final direction = diff > 0 ? 'higher' : 'lower';
        alerts.add(FeedingAlert(
          'Runoff pH (avg ${avgRunoff.toStringAsFixed(1)}) is significantly '
          '$direction than input pH (avg ${inputAvg.toStringAsFixed(1)}). '
          'Root-zone pH may be drifting — consider a flush.',
          FeedingAlertSeverity.warning,
        ));
      }
    }
  }

  // ── EC analysis ───────────────────────────────
  double? latestEc;
  if (ecReadings.isNotEmpty) {
    latestEc = ecReadings.last;

    final recent = ecReadings.length > _lookback
        ? ecReadings.sublist(ecReadings.length - _lookback)
        : ecReadings;

    // Upward trend — risk of salt build-up / nutrient burn.
    if (recent.length >= 3 && _isTrendingUp(recent, _ecTrendStep)) {
      final trendStr = recent
          .sublist(recent.length - 3)
          .map((v) => v.toStringAsFixed(1))
          .join(' → ');
      alerts.add(FeedingAlert(
        'EC is trending upward ($trendStr mS/cm). '
        'Salt build-up can lead to nutrient burn — '
        'consider a lighter feed or plain-water flush.',
        FeedingAlertSeverity.warning,
      ));
    } else if (latestEc > _ecBurnThreshold) {
      alerts.add(FeedingAlert(
        'Latest EC reading (${latestEc.toStringAsFixed(2)} mS/cm) is above '
        '${_ecBurnThreshold.toStringAsFixed(1)} mS/cm. '
        'High EC can cause nutrient burn and tip damage.',
        FeedingAlertSeverity.warning,
      ));
    }

    // Downward trend with low absolute value — possible under-feeding.
    if (recent.length >= 3 &&
        _isTrendingDown(recent, _ecTrendStep) &&
        latestEc < 0.8) {
      alerts.add(FeedingAlert(
        'EC is trending low (latest: ${latestEc.toStringAsFixed(2)} mS/cm). '
        'Plants may be under-fed — check for deficiency signs.',
        FeedingAlertSeverity.info,
      ));
    }
  }

  return FeedingAnalyticsSummary(
    alerts: alerts,
    avgPh: avgPh,
    latestEc: latestEc,
    phReadingCount: phReadings.length,
    ecReadingCount: ecReadings.length,
  );
}
