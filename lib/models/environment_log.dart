import 'dart:math';
import 'plant.dart';

class EnvironmentLog {
  final String id;
  final String growSpaceId;
  final DateTime recordedAt;
  final double? temperature;
  final double? humidity;
  final String? notes;

  EnvironmentLog({
    required this.id,
    required this.growSpaceId,
    required this.recordedAt,
    this.temperature,
    this.humidity,
    this.notes,
  });

  /// Vapor Pressure Deficit in kPa.
  /// Ideal cannabis range: 0.4–1.6 kPa.
  double? get vpd {
    if (temperature == null || humidity == null) return null;
    final svp = 0.6108 * exp(17.27 * temperature! / (temperature! + 237.3));
    return svp * (1 - humidity! / 100);
  }

  String get vpdStatus {
    final v = vpd;
    if (v == null) return 'No data';
    if (v < 0.4) return 'Too Low';
    if (v <= 1.6) return 'In Range';
    return 'Too High';
  }

  /// Stage-aware VPD status using tighter grow-phase bands.
  ///
  /// Germination/Seedling  0.4–0.8 kPa · Vegetative  0.8–1.2 kPa
  /// Stretch/Flower/Flush  1.0–1.6 kPa
  ///
  /// Falls back to the global [vpdStatus] when [stage] is null.
  String vpdStatusForStage(GrowStage? stage) {
    final v = vpd;
    if (v == null) return 'No data';
    if (stage == null) return vpdStatus;

    double low;
    double high;
    switch (stage) {
      case GrowStage.germination:
      case GrowStage.seedling:
        low = 0.4;
        high = 0.8;
        break;
      case GrowStage.vegetative:
        low = 0.8;
        high = 1.2;
        break;
      case GrowStage.stretch:
      case GrowStage.earlyFlower:
      case GrowStage.lateFlower:
      case GrowStage.flush:
        low = 1.0;
        high = 1.6;
        break;
    }

    if (v < low) return 'Too Low';
    if (v <= high) return 'In Range';
    return 'Too High';
  }

  /// Global-default optimal check using hardcoded industry ranges.
  ///
  /// ⚠️  Prefer [GrowSpace.isOptimal] which respects per-space thresholds.
  /// This getter exists only for standalone log inspection that has no
  /// reference to a specific grow space.
  bool get isOptimal {
    if (temperature == null || humidity == null) return false;
    final tempOk = temperature! >= 18 && temperature! <= 28;
    final humidityOk = humidity! >= 40 && humidity! <= 70;
    return tempOk && humidityOk;
  }

  /// ⚠️  Prefer [GrowSpace.isOptimal] when a space reference is available.
  String getStatus() {
    if (temperature == null || humidity == null) return 'Incomplete';
    if (isOptimal) return 'Optimal';
    if (temperature! < 18 || temperature! > 28) return 'Temp Warning';
    if (humidity! < 40 || humidity! > 70) return 'Humidity Warning';
    return 'Check Values';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'growSpaceId': growSpaceId,
        'recordedAt': recordedAt.toIso8601String(),
        'temperature': temperature,
        'humidity': humidity,
        'notes': notes,
      };

  factory EnvironmentLog.fromJson(Map<String, dynamic> json) => EnvironmentLog(
        id: json['id'],
        growSpaceId: json['growSpaceId'],
        recordedAt: DateTime.parse(json['recordedAt']),
        temperature: (json['temperature'] as num?)?.toDouble(),
        humidity: (json['humidity'] as num?)?.toDouble(),
        notes: json['notes'],
      );
}
