// ─────────────────────────────────────────────────────────────────────────────
// Training / technique model
// ─────────────────────────────────────────────────────────────────────────────

enum TrainingTechnique {
  topping,
  fimming,
  lst,
  supercropping,
  defoliation,
  lollipopping,
  scrog,
  mainlining,
  pinching,
  schwazzing,
  sog,
  other,
}

extension TrainingTechniqueExt on TrainingTechnique {
  String get label {
    switch (this) {
      case TrainingTechnique.topping:      return 'Topping';
      case TrainingTechnique.fimming:      return 'FIMming';
      case TrainingTechnique.lst:          return 'LST';
      case TrainingTechnique.supercropping:return 'Supercropping';
      case TrainingTechnique.defoliation:  return 'Defoliation';
      case TrainingTechnique.lollipopping: return 'Lollipopping';
      case TrainingTechnique.scrog:        return 'SCROG';
      case TrainingTechnique.mainlining:   return 'Mainlining';
      case TrainingTechnique.pinching:     return 'Pinching';
      case TrainingTechnique.schwazzing:   return 'Schwazzing';
      case TrainingTechnique.sog:          return 'SOG';
      case TrainingTechnique.other:        return 'Other';
    }
  }

  String get shortLabel {
    switch (this) {
      case TrainingTechnique.supercropping: return 'HST';
      case TrainingTechnique.lollipopping:  return 'Lollipop';
      case TrainingTechnique.schwazzing:    return 'Schwazz';
      default: return label;
    }
  }

  /// 1 = low stress, 2 = medium, 3 = high stress
  int get stressLevel {
    switch (this) {
      case TrainingTechnique.lst:
      case TrainingTechnique.scrog:
      case TrainingTechnique.sog:
        return 1;
      case TrainingTechnique.fimming:
      case TrainingTechnique.defoliation:
      case TrainingTechnique.lollipopping:
      case TrainingTechnique.pinching:
        return 2;
      case TrainingTechnique.topping:
      case TrainingTechnique.supercropping:
      case TrainingTechnique.mainlining:
      case TrainingTechnique.schwazzing:
      case TrainingTechnique.other:
        return 3;
    }
  }

  /// Whether this technique benefits from a severity qualifier.
  bool get hasSeverity {
    switch (this) {
      case TrainingTechnique.defoliation:
      case TrainingTechnique.lst:
      case TrainingTechnique.lollipopping:
      case TrainingTechnique.schwazzing:
        return true;
      default:
        return false;
    }
  }

  /// Whether a target site (node / branch) is relevant.
  bool get hasTargetSite {
    switch (this) {
      case TrainingTechnique.scrog:
      case TrainingTechnique.sog:
        return false;
      default:
        return true;
    }
  }

  /// Default recovery days (used when no severity override is provided).
  int get defaultRecoveryDays {
    switch (this) {
      case TrainingTechnique.lst:
      case TrainingTechnique.scrog:
      case TrainingTechnique.sog:
        return 0;
      case TrainingTechnique.pinching:
        return 2;
      case TrainingTechnique.fimming:
      case TrainingTechnique.defoliation:
      case TrainingTechnique.lollipopping:
        return 5;
      case TrainingTechnique.topping:
      case TrainingTechnique.supercropping:
      case TrainingTechnique.mainlining:
      case TrainingTechnique.schwazzing:
        return 7;
      case TrainingTechnique.other:
        return 3;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum TrainingSeverity { light, medium, heavy }

extension TrainingSeverityExt on TrainingSeverity {
  String get label {
    switch (this) {
      case TrainingSeverity.light:  return 'Light';
      case TrainingSeverity.medium: return 'Medium';
      case TrainingSeverity.heavy:  return 'Heavy';
    }
  }

  /// Recovery day modifier applied on top of the technique default.
  int recoveryDaysFor(TrainingTechnique technique) {
    final base = technique.defaultRecoveryDays;
    switch (this) {
      case TrainingSeverity.light:  return (base * 0.6).round();
      case TrainingSeverity.medium: return base;
      case TrainingSeverity.heavy:  return (base * 1.4).round();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TrainingDetails — structured payload attached to a training PlantNote
// ─────────────────────────────────────────────────────────────────────────────

class TrainingDetails {
  /// Which technique was applied.
  final TrainingTechnique technique;

  /// Optional severity — most relevant for defoliation / LST / lollipopping.
  final TrainingSeverity? severity;

  /// Free-text site descriptor: "Main cola", "Node 5", "Lower thirds", etc.
  final String? targetSite;

  /// Node number, when technique is topping or FIMming.
  final int? nodeNumber;

  /// Expected recovery days.  Auto-computed from technique + severity but
  /// editable by the user before saving.
  final int recoveryDays;

  const TrainingDetails({
    required this.technique,
    this.severity,
    this.targetSite,
    this.nodeNumber,
    required this.recoveryDays,
  });

  // ── Computed ─────────────────────────────────────────────────────────────

  /// True when this technique triggers a non-zero recovery period.
  bool get hasRecovery => recoveryDays > 0;

  /// Recovery progress given an event date.  Returns 0.0–1.0.
  /// 1.0 = fully recovered.
  double recoveryProgress(DateTime eventDate) {
    if (recoveryDays <= 0) return 1.0;
    final elapsed = DateTime.now().difference(eventDate).inHours;
    final total = recoveryDays * 24.0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// Days remaining in recovery (0 when fully recovered).
  int daysRemaining(DateTime eventDate) {
    if (recoveryDays <= 0) return 0;
    final elapsed = DateTime.now().difference(eventDate).inDays;
    return (recoveryDays - elapsed).clamp(0, recoveryDays);
  }

  bool isRecovering(DateTime eventDate) =>
      hasRecovery && daysRemaining(eventDate) > 0;

  // ── Factory ───────────────────────────────────────────────────────────────

  /// Auto-computes [recoveryDays] from technique + severity.
  factory TrainingDetails.auto({
    required TrainingTechnique technique,
    TrainingSeverity? severity,
    String? targetSite,
    int? nodeNumber,
  }) {
    final days = severity != null
        ? severity.recoveryDaysFor(technique)
        : technique.defaultRecoveryDays;
    return TrainingDetails(
      technique: technique,
      severity: severity,
      targetSite: targetSite,
      nodeNumber: nodeNumber,
      recoveryDays: days,
    );
  }

  // ── JSON ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'technique': technique.name,
        'severity': severity?.name,
        'targetSite': targetSite,
        'nodeNumber': nodeNumber,
        'recoveryDays': recoveryDays,
      };

  factory TrainingDetails.fromJson(Map<String, dynamic> json) =>
      TrainingDetails(
        technique: TrainingTechnique.values.firstWhere(
          (t) => t.name == json['technique'],
          orElse: () => TrainingTechnique.other,
        ),
        severity: json['severity'] != null
            ? TrainingSeverity.values.firstWhere(
                (s) => s.name == json['severity'],
                orElse: () => TrainingSeverity.medium,
              )
            : null,
        targetSite: json['targetSite'] as String?,
        nodeNumber: json['nodeNumber'] as int?,
        recoveryDays: json['recoveryDays'] as int? ?? 0,
      );
}
