import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/grow_space.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../repository/grow_repository.dart';
import '../theme/app_spacing.dart';

/// Bulk PDF report generator.
///
/// Used by the plant list multi-select to produce a single PDF document
/// covering every selected plant.  Each plant gets a compact one-page
/// summary — start / flip / harvest dates, yield, quality rating, and
/// the five most recent notes — so a 20-plant selection is still under
/// 25 printable pages.
///
/// For the full deep-dive report on a single plant, use
/// `GrowSessionReportScreen` instead.
class BulkReportService {
  /// Builds the PDF in memory and hands it to the platform share sheet.
  ///
  /// Returns when the share sheet is dismissed (or immediately on web).
  static Future<void> buildAndShare({
    required GrowRepository repo,
    required List<Plant> plants,
  }) async {
    if (plants.isEmpty) return;
    final bytes = await _buildBytes(repo: repo, plants: plants);
    final date = _shortDate(DateTime.now());
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Kultivar_bulk_report_$date.pdf',
    );
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildBytes({
    required GrowRepository repo,
    required List<Plant> plants,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();

    // ── Title page ──
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Kultivar — Grow Report',
              style: pw.TextStyle(
                  fontSize: 28, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: AppSpacing.xxs),
          pw.Text(
            'Generated ${_longDate(now)}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: AppSpacing.lg),
          pw.Text('Plants in this report:',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: AppSpacing.xs),
          ...plants.map((p) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: AppSpacing.xxs),
                child: pw.Text(
                  '• ${p.name} — ${p.strain}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              )),
          pw.Spacer(),
          pw.Text(
            '${plants.length} plants · one-page summaries follow',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    ));

    // ── One page per plant ──
    for (final plant in plants) {
      final notes = repo.notes.where((n) => n.plantId == plant.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final harvest = repo.harvestLogs
          .where((l) => l.plantId == plant.id)
          .fold<HarvestLog?>(null, (_, l) => l);
      final space = repo.growSpaces
          .where((s) => s.id == plant.growSpaceId)
          .fold<GrowSpace?>(null, (_, s) => s);

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => _plantPage(plant, harvest, space, notes.take(5).toList()),
      ));
    }

    return doc.save();
  }

  static pw.Widget _plantPage(
    Plant plant,
    HarvestLog? harvest,
    GrowSpace? space,
    List<PlantNote> recentNotes,
  ) {
    final yieldGrams = harvest?.dryWeight;
    final daysTotal = (plant.harvestedDate ?? DateTime.now())
        .difference(plant.startDate)
        .inDays;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Text(plant.name,
            style: pw.TextStyle(
                fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.Text(
          '${plant.strain}${plant.phenotypeTag != null ? ' · ${plant.phenotypeTag}' : ''}',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        if (space != null)
          pw.Text(
            '${space.name} · ${space.type}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        pw.Divider(),

        // Stats
        pw.SizedBox(height: AppSpacing.xs),
        _kvRow('Status', plant.statusLabel),
        _kvRow('Start date', _shortDate(plant.startDate)),
        if (plant.flipDate != null)
          _kvRow('Flip date', _shortDate(plant.flipDate!)),
        if (plant.harvestedDate != null)
          _kvRow('Harvested', _shortDate(plant.harvestedDate!)),
        _kvRow('Days', '$daysTotal'),
        if (plant.isClone) _kvRow('Source', 'Clone'),
        if (plant.isAutoflower) _kvRow('Type', 'Autoflower'),
        if (plant.medium != null) _kvRow('Medium', plant.medium!),
        if (plant.lightType != null) _kvRow('Light type', plant.lightType!),
        if (yieldGrams != null)
          _kvRow('Dry yield', '${yieldGrams.toStringAsFixed(1)} g'),

        // Quality
        if (harvest?.qualityRating != null) ...[
          pw.SizedBox(height: AppSpacing.sm),
          pw.Text('Quality',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: AppSpacing.xxs),
          pw.Text(
            'Rating: ${harvest!.qualityRating!.toStringAsFixed(1)} / 5',
            style: const pw.TextStyle(fontSize: 11),
          ),
          if (harvest.aromaNote != null)
            pw.Text('Aroma: ${harvest.aromaNote}',
                style: const pw.TextStyle(fontSize: 11)),
          if (harvest.flavorNotes != null)
            pw.Text('Flavor: ${harvest.flavorNotes}',
                style: const pw.TextStyle(fontSize: 11)),
          if (harvest.effectNotes != null)
            pw.Text('Effects: ${harvest.effectNotes}',
                style: const pw.TextStyle(fontSize: 11)),
        ],

        // Recent notes
        if (recentNotes.isNotEmpty) ...[
          pw.SizedBox(height: AppSpacing.sm),
          pw.Text('Recent notes',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: AppSpacing.xxs),
          for (final n in recentNotes)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 10),
                  children: [
                    pw.TextSpan(
                      text: '${_shortDate(n.createdAt)} · ${n.categoryLabel}: ',
                      style: pw.TextStyle(
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(text: n.content),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  static pw.Widget _kvRow(String key, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 100,
              child: pw.Text(key,
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
            ),
            pw.Expanded(
              child: pw.Text(value,
                  style: const pw.TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );

  static String _shortDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _longDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
