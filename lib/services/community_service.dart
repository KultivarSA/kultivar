import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/grow_diary_stats.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../models/strain_community_stats.dart';

/// Handles all reads from and writes to the Supabase community layer.
///
/// All submissions are anonymous — no user ID, no IP stored at the
/// application layer.  The aggregate view enforces a minimum sample size
/// of 5 before any data is surfaced.
///
/// Tier gating: community access is a Pro Cloud feature.  Free and
/// Lifetime Local users must NOT make any Supabase calls.  Rather than
/// patching every call site (and risking new ones being added without
/// the guard), all public read/write methods short-circuit when
/// [hasAccess] is false.  Set this from `SubscriptionService` whenever
/// the tier changes — the wiring lives in main.dart.
class CommunityService {
  /// True when the current user is allowed to hit the Supabase backend.
  /// Defaults to false — `SubscriptionService` flips it to match the
  /// active tier during init and on every tier change.
  static bool hasAccess = false;

  /// Returns the Supabase client, or null when credentials weren't supplied
  /// at build time (see [SupabaseConfig]).  Callers MUST short-circuit on
  /// null — accessing [Supabase.instance.client] before `initialize()` was
  /// called throws an `AssertionError`.
  static SupabaseClient? get _db {
    if (!hasAccess) return null;
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ── Read ────────────────────────────────────────────────────────────────

  /// Returns community aggregate stats for [strainName], or `null` when:
  ///  • the strain has fewer than 5 submissions, or
  ///  • there is no network, or
  ///  • any other error occurs (silent — community data is always optional).
  static Future<StrainCommunityStats?> fetchStats(String strainName) async {
    final db = _db;
    if (db == null) return null;
    try {
      final normalized = _normalize(strainName);
      final response = await db
          .from('strain_community_stats')
          .select()
          .eq('strain_name', normalized)
          .maybeSingle();

      if (response == null) return null;
      return StrainCommunityStats.fromJson(response);
    } catch (_) {
      // Community data is non-critical — never surface network errors to the user.
      return null;
    }
  }

  /// Returns aggregated grow-context stats (medium, light, stage durations)
  /// for [strainName] from the `strain_grow_stats` view, or `null` when fewer
  /// than 5 diary submissions exist or on any network error.
  static Future<GrowDiaryStats?> fetchDiaryStats(String strainName) async {
    final db = _db;
    if (db == null) return null;
    try {
      final normalized = _normalize(strainName);
      final response = await db
          .from('strain_grow_stats')
          .select()
          .eq('strain_name', normalized)
          .maybeSingle();

      if (response == null) return null;
      return GrowDiaryStats.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  // ── Write ───────────────────────────────────────────────────────────────

  /// Anonymously submits a harvest benchmark.
  ///
  /// Call this after the user opts in — never call silently without consent.
  /// Pass [notes] so training techniques used during the grow can be included
  /// in the submission — these are aggregated server-side to populate the
  /// community technique-frequency data.
  /// Returns `true` on success, `false` on any error.
  static Future<bool> submitBenchmark({
    required Plant plant,
    required HarvestLog log,
    List<PlantNote> notes = const [],
    String? appVersion,
  }) async {
    if (log.dryWeight == null || log.dryWeight! <= 0) return false;
    if (plant.harvestedDate == null) return false;
    final db = _db;
    if (db == null) return false;

    // Deduplicate training techniques used across all training notes for
    // this plant, then join as a comma-separated string (e.g. "lst,topping").
    final techniques = notes
        .where((n) =>
            n.plantId == plant.id && n.trainingDetails != null)
        .map((n) => n.trainingDetails!.technique.name)
        .toSet()
        .toList();
    final trainingValue =
        techniques.isEmpty ? null : techniques.join(',');

    try {
      await db.from('strain_benchmarks').insert({
        'strain_name':   _normalize(plant.strain),
        'dry_weight_g':  log.dryWeight,
        'grow_days':     plant.harvestedDate!
                             .difference(plant.startDate)
                             .inDays,
        'veg_days':      plant.flipDate?.difference(plant.startDate).inDays,
        'flower_days':   plant.flipDate != null
                             ? plant.harvestedDate!.difference(plant.flipDate!).inDays
                             : null,
        'medium':        _safeMedium(plant),
        'light_type':    plant.lightType,
        'training':      trainingValue,
        'is_autoflower': plant.isAutoflower,
        'is_clone':      plant.isClone,
        if (appVersion != null) 'app_version': appVersion,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Anonymously submits detailed grow-context data to `grow_diary_entries`.
  ///
  /// All fields except [plant] and [log] are optional — submitting with only
  /// some fields filled is valid and still contributes to the aggregate.
  /// Returns `true` on success, `false` on any error (silent).
  static Future<bool> submitDiaryEntry({
    required Plant plant,
    required HarvestLog log,
    String? medium,
    String? lightType,
    List<String> techniques = const [],
    /// Explicit quality rating (1–5). When supplied, takes precedence over
    /// [log.qualityRating] so the diary form can let the user set or change it.
    /// Accepts the local half-star scale (0.5–5.0); rounded to the nearest
    /// whole star before persisting to the community schema (Supabase
    /// `quality_rating` is an int column).
    double? qualityRating,
    String? appVersion,
  }) async {
    if (plant.harvestedDate == null) return false;
    final db = _db;
    if (db == null) return false;

    try {
      await db.from('grow_diary_entries').insert({
        'strain_name':    _normalize(plant.strain),
        'medium':         medium,
        'light_type':     lightType,
        'techniques':     techniques.isEmpty ? null : techniques.join(','),
        'is_autoflower':  plant.isAutoflower,
        'is_clone':       plant.isClone,
        'dry_weight_g':   log.dryWeight,
        'veg_days':       plant.flipDate
                              ?.difference(plant.startDate).inDays,
        'flower_days':    plant.flipDate != null
                              ? plant.harvestedDate!
                                    .difference(plant.flipDate!).inDays
                              : null,
        // Round half-stars to whole stars — Supabase schema is int.
        'quality_rating':
            (qualityRating ?? log.qualityRating)?.round(),
        if (appVersion != null) 'app_version': appVersion,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Normalises a strain name for consistent grouping:
  /// lowercase, collapsed whitespace, trimmed.
  static String _normalize(String name) =>
      name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Maps the plant's grow space type string to one of the allowed
  /// medium values. Returns null when unrecognised so the DB CHECK
  /// constraint is never violated.
  static String? _safeMedium(Plant plant) {
    // Plant doesn't carry medium directly yet — placeholder for when it does.
    return null;
  }
}
