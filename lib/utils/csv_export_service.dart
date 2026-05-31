import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/environment_log.dart';
import '../models/grow_expense.dart';
import '../models/grow_space.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';

class CsvExportService {
  // ── Harvest logs ──────────────────────────────

  static Future<void> exportHarvestLogs(
    List<HarvestLog> logs,
    List<Plant> plants,
  ) async {
    // Delegates to the shared builder so single-file and ZIP exports
    // can't drift apart on column lists.
    await _share(_buildHarvestLogsCsv(logs), 'harvest_logs.csv');
  }

  // ── Environment logs ──────────────────────────

  static Future<void> exportEnvironmentLogs(
    List<EnvironmentLog> logs,
    List<GrowSpace> spaces,
  ) async {
    await _share(_buildEnvLogsCsv(logs, spaces), 'environment_logs.csv');
  }

  // ── Plants ────────────────────────────────────

  static Future<void> exportPlants(
    List<Plant> plants,
    List<GrowSpace> spaces,
  ) async {
    await _share(_buildPlantsCsv(plants, spaces), 'plants.csv');
  }

  // ── Notes ──────────────────────────────────────

  static Future<void> exportNotes(
    List<PlantNote> notes,
    List<Plant> plants,
  ) async {
    await _share(_buildNotesCsv(notes, plants), 'notes.csv');
  }

  // ── All data (ZIP of CSVs) ─────────────────────
  //
  // Produces a single ZIP file containing four CSVs: plants, harvest_logs,
  // environment_logs, and notes. Shared via the system share sheet in one step.

  static Future<void> exportAllCsv({
    required List<Plant> plants,
    required List<GrowSpace> spaces,
    required List<HarvestLog> harvestLogs,
    required List<EnvironmentLog> envLogs,
    required List<PlantNote> notes,
    List<GrowExpense> expenses = const [],
  }) async {
    final archive = Archive();

    void add(String filename, String csv) {
      // utf8.encode is required for non-ASCII characters in any field
      // (currency symbols £/€, accented strain names, etc.).  Using
      // String.codeUnits would truncate UTF-16 code units to a single
      // byte and corrupt anything outside ASCII.
      final bytes = utf8.encode(csv);
      archive.addFile(ArchiveFile(filename, bytes.length, bytes));
    }

    add('plants.csv', _buildPlantsCsv(plants, spaces));
    add('harvest_logs.csv', _buildHarvestLogsCsv(harvestLogs));
    add('environment_logs.csv', _buildEnvLogsCsv(envLogs, spaces));
    add('notes.csv', _buildNotesCsv(notes, plants));
    add('expenses.csv', _buildExpensesCsv(expenses, plants, spaces));

    // archive 4.x: encode() returns a non-null Uint8List.
    final zipBytes = ZipEncoder().encode(archive);

    final dir = await getTemporaryDirectory();
    final date = DateTime.now()
        .toLocal()
        .toString()
        .split(' ')[0]
        .replaceAll('-', '');
    final file = File('${dir.path}/kultivar_export_$date.zip');
    await file.writeAsBytes(zipBytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/zip')],
      subject: 'Kultivar — full data export',
    );
  }

  // ── CSV builders (return String, no I/O) ──────

  static String _buildPlantsCsv(
      List<Plant> plants, List<GrowSpace> spaces) {
    final buf = StringBuffer();
    buf.writeln(
      'name,strain,grow_space,status,start_date,flip_date,'
      'harvested_date,target_harvest_date,days_growing,'
      'veg_days,flower_days,dry_weight_g,'
      'is_autoflower,is_clone,medium,light_type',
    );
    for (final p in plants) {
      final spaceName =
          spaces.where((s) => s.id == p.growSpaceId).firstOrNull?.name ?? '';
      final harvestEnd =
          p.harvestedDate ?? (p.isArchived ? p.archivedAt : null);
      final vegDays = p.flipDate != null
          ? p.flipDate!.difference(p.startDate).inDays.toString()
          : '';
      final flowerDays = p.flipDate != null && harvestEnd != null
          ? harvestEnd.difference(p.flipDate!).inDays.toString()
          : '';
      buf.writeln([
        _escape(p.name),
        _escape(p.strain),
        _escape(spaceName),
        _escape(p.status.name),
        p.startDate.toIso8601String().split('T')[0],
        p.flipDate?.toIso8601String().split('T')[0] ?? '',
        p.harvestedDate?.toIso8601String().split('T')[0] ?? '',
        p.targetHarvestDate?.toIso8601String().split('T')[0] ?? '',
        p.daysGrowing.toString(),
        vegDays,
        flowerDays,
        p.dryWeight?.toStringAsFixed(1) ?? '',
        p.isAutoflower ? '1' : '0',
        p.isClone ? '1' : '0',
        _escape(p.medium ?? ''),
        _escape(p.lightType ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  static String _buildHarvestLogsCsv(List<HarvestLog> logs) {
    final buf = StringBuffer();
    buf.writeln(
      'plant_name,strain,harvested_date,'
      'wet_weight_g,dry_weight_g,yield_pct,'
      'quality_rating,smell_rating,effect_rating,bag_appeal_rating,'
      'aroma_note,flavor_notes,effect_notes,'
      'phenotype_tag,is_draft,notes',
    );
    for (final log in logs) {
      buf.writeln([
        _escape(log.plantName),
        _escape(log.strain),
        log.harvestedDate.toIso8601String().split('T')[0],
        log.wetWeight?.toStringAsFixed(1) ?? '',
        log.dryWeight?.toStringAsFixed(1) ?? '',
        log.yieldPercentage?.toStringAsFixed(1) ?? '',
        log.qualityRating?.toStringAsFixed(1) ?? '',
        log.smellRating?.toStringAsFixed(1) ?? '',
        log.effectRating?.toStringAsFixed(1) ?? '',
        log.bagAppealRating?.toStringAsFixed(1) ?? '',
        _escape(log.aromaNote ?? ''),
        _escape(log.flavorNotes ?? ''),
        _escape(log.effectNotes ?? ''),
        _escape(log.phenotypeTag ?? ''),
        log.isDraft ? '1' : '0',
        _escape(log.notes ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  // ── Expenses ──────────────────────────────────

  /// Build an expenses CSV.  Joins plant name and space name when the
  /// expense is attributed; leaves the column blank for orphaned rows.
  static String _buildExpensesCsv(
    List<GrowExpense> expenses,
    List<Plant> plants,
    List<GrowSpace> spaces,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'date,category,description,amount,plant_name,space_name,notes',
    );
    final plantById = {for (final p in plants) p.id: p};
    final spaceById = {for (final s in spaces) s.id: s};
    for (final e in expenses) {
      final plant = e.plantId != null ? plantById[e.plantId] : null;
      final space = e.growSpaceId != null ? spaceById[e.growSpaceId] : null;
      buf.writeln([
        e.date.toIso8601String().split('T')[0],
        _escape(e.category.label),
        _escape(e.description),
        e.amount.toStringAsFixed(2),
        _escape(plant?.name ?? ''),
        _escape(space?.name ?? ''),
        _escape(e.notes ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  /// Public single-collection export for expenses.  Matches the pattern
  /// of [exportPlants] / [exportHarvestLogs] so the Settings screen can
  /// surface an "Export Expenses" tile.
  static Future<void> exportExpenses(
    List<GrowExpense> expenses,
    List<Plant> plants,
    List<GrowSpace> spaces,
  ) async {
    await _share(_buildExpensesCsv(expenses, plants, spaces), 'expenses.csv');
  }

  static String _buildEnvLogsCsv(
      List<EnvironmentLog> logs, List<GrowSpace> spaces) {
    final buf = StringBuffer();
    buf.writeln(
      'space_name,recorded_at,temperature_c,'
      'humidity_pct,status,notes',
    );
    for (final log in logs) {
      final space =
          spaces.where((s) => s.id == log.growSpaceId).firstOrNull;
      buf.writeln([
        _escape(space?.name ?? 'Unknown'),
        log.recordedAt.toIso8601String(),
        log.temperature?.toStringAsFixed(1) ?? '',
        log.humidity?.toStringAsFixed(1) ?? '',
        _escape(log.getStatus()),
        _escape(log.notes ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  static String _buildNotesCsv(
      List<PlantNote> notes, List<Plant> plants) {
    final buf = StringBuffer();
    buf.writeln(
      'plant_name,strain,date,category,content,issue_name,'
      'is_resolved,photo_count,'
      'water_volume_l,watering_ph,runoff_ph,'
      'feed_ec,feed_ph,feed_product,'
      'ipm_product,ipm_target',
    );
    final plantById = {for (final p in plants) p.id: p};
    for (final n in notes) {
      final plant = plantById[n.plantId];
      buf.writeln([
        _escape(plant?.name ?? ''),
        _escape(plant?.strain ?? ''),
        n.createdAt.toIso8601String(),
        _escape(n.category.name),
        _escape(n.content),
        _escape(n.issueName ?? ''),
        n.isResolved ? '1' : '0',
        n.photoUrls.length.toString(),
        n.wateringDetails?.volumeLitres?.toStringAsFixed(2) ?? '',
        n.wateringDetails?.phIn?.toStringAsFixed(1) ?? '',
        n.wateringDetails?.runoffPh?.toStringAsFixed(1) ?? '',
        n.feedingDetails?.ecIn?.toStringAsFixed(2) ?? '',
        n.feedingDetails?.phIn?.toStringAsFixed(1) ?? '',
        _escape(n.feedingDetails?.productName ?? ''),
        _escape(n.ipmDetails?.product ?? ''),
        _escape(n.ipmDetails?.targetPest ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  // ── Helpers ───────────────────────────────────

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static Future<void> _share(String content, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Kultivar export — $filename',
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
