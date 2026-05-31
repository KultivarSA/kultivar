import '../models/plant.dart';
import '../models/plant_note.dart';
import 'vpd_analytics.dart';

// ── Result types ─────────────────────────────────────────────────────────────

class IssuePhaseResult {
  /// Display name for this phase (e.g. 'Late Flower').
  final String phaseName;

  /// Total issue notes mapped to this phase across all analysed plants.
  final int issueCount;

  /// Number of distinct plants that logged at least one issue in this phase.
  final int affectedPlants;

  /// The most-frequently-used [PlantNote.issueName] in this phase, or null
  /// when none of the issue notes carried a named issue.
  final String? topIssueName;

  /// How many of the issue notes used [topIssueName].
  final int topIssueCount;

  const IssuePhaseResult({
    required this.phaseName,
    required this.issueCount,
    required this.affectedPlants,
    this.topIssueName,
    this.topIssueCount = 0,
  });
}

class IssuePatternSummary {
  /// Phases sorted by issue count descending (highest-risk first).
  final List<IssuePhaseResult> phases;

  final int totalIssues;

  /// How many plants were examined (regardless of whether they had issues).
  final int totalPlantsAnalysed;

  /// Number of plants that had at least one issue note.
  final int plantsWithIssues;

  /// True when there is enough data to show meaningful patterns.
  bool get hasData => totalIssues >= 2;

  /// Whether all issues landed in the same phase — useful for callout copy.
  bool get singlePhase => phases.length == 1;

  /// The phase with the most issues, or null when [phases] is empty.
  IssuePhaseResult? get worstPhase =>
      phases.isEmpty ? null : phases.first;

  const IssuePatternSummary({
    required this.phases,
    required this.totalIssues,
    required this.totalPlantsAnalysed,
    required this.plantsWithIssues,
  });

  static const empty = IssuePatternSummary(
    phases: [],
    totalIssues: 0,
    totalPlantsAnalysed: 0,
    plantsWithIssues: 0,
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Maps a [GrowPhase] (or null) to a human-readable label.
String _phaseLabel(GrowPhase? phase) {
  if (phase == null) return 'Other';
  return phase.label;
}

/// Finds the most common non-null value in a list of strings.
/// Returns null when the list is empty or all entries are null.
(String? name, int count) _topValue(List<String?> values) {
  final counts = <String, int>{};
  for (final v in values) {
    if (v != null && v.trim().isNotEmpty) {
      counts[v.trim()] = (counts[v.trim()] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return (null, 0);
  final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return (top.key, top.value);
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Analyses issue notes across all [plants] and their [notes], grouping
/// by grow phase (veg / early flower / late flower).
///
/// Pass all plants + all notes from the repo; the engine filters to issue
/// notes and looks up each note's plant internally. Notes whose plant cannot
/// be found are skipped.
IssuePatternSummary computeIssuePatterns(
  List<Plant> plants,
  List<PlantNote> notes,
) {
  // Index plants for O(1) lookup.
  final plantById = {for (final p in plants) p.id: p};

  // Only issue-category notes that have a matching plant.
  final issueNotes = notes
      .where((n) =>
          n.category == NoteCategory.issue && plantById.containsKey(n.plantId))
      .toList();

  if (issueNotes.isEmpty) return IssuePatternSummary.empty;

  // Group by phase label.
  // Structure: { phaseLabel: { plantId: [issueNames] } }
  final Map<String, Map<String, List<String?>>> byPhase = {};

  for (final note in issueNotes) {
    final plant = plantById[note.plantId]!;
    final phase = growPhaseForTimestamp(note.createdAt, plant);
    final label = _phaseLabel(phase);

    byPhase.putIfAbsent(label, () => {});
    byPhase[label]!.putIfAbsent(note.plantId, () => []);
    byPhase[label]![note.plantId]!.add(note.issueName);
  }

  // Build phase results.
  final results = byPhase.entries.map((entry) {
    final phaseName = entry.key;
    final plantIssueMap = entry.value;
    final issueCount =
        plantIssueMap.values.fold(0, (sum, list) => sum + list.length);
    final affectedPlants = plantIssueMap.length;

    final allIssueNames =
        plantIssueMap.values.expand((list) => list).toList();
    final (topName, topCount) = _topValue(allIssueNames);

    return IssuePhaseResult(
      phaseName: phaseName,
      issueCount: issueCount,
      affectedPlants: affectedPlants,
      topIssueName: topName,
      topIssueCount: topCount,
    );
  }).toList()
    ..sort((a, b) => b.issueCount.compareTo(a.issueCount));

  // Count plants that had any issue.
  final plantsWithIssues =
      issueNotes.map((n) => n.plantId).toSet().length;

  return IssuePatternSummary(
    phases: results,
    totalIssues: issueNotes.length,
    totalPlantsAnalysed: plants.length,
    plantsWithIssues: plantsWithIssues,
  );
}
