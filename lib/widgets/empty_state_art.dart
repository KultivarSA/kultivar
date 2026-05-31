import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// A3 — Empty-state line-art set
//
// Replaces the previous "single Material icon in a circle" empty-state
// heroes (🌿/📷/etc.) with a curated, theme-aware line-art set
// rendered through `CustomPainter`.  Picking CustomPainter over
// `flutter_svg` keeps the dep tree lean and the strokes recolourable
// from theme — line colour follows `context.colTextMuted` and the
// accent fill uses `AppColors.primary` (or an override).
//
// Each illustration paints to a 120×120 logical viewport.  The
// canvas is uniform-scaled to whatever size `LineArtIllustration`
// is laid out at, so calls in tight rows (e.g. the inline empty
// state on Plant Notes) can shrink the same artwork without
// re-tweaking coordinates.
//
// To add a new illustration:
//   1. Add a value to [EmptyArt].
//   2. Implement its painter as a `static void _paintXxx(Canvas, Size, Paint stroke, Paint accent)`.
//   3. Dispatch from `_EmptyArtPainter.paint`.
//
// All paths use stroke (no fill) except for small accent dots / leaf
// interiors which are painted with the accent colour at 22 % alpha.
// ─────────────────────────────────────────────────────────────────────────────

/// Curated set of line-art illustrations shipped with the empty-state
/// widget.  Each value maps to one painter in `_EmptyArtPainter`.
enum EmptyArt {
  /// Potted seedling — home, plant lists, "no spaces yet" states.
  plant,

  /// Lined note page — Notes tab when the user has no plants yet.
  note,

  /// Storage box with a leaf — Harvest Archive.
  archive,

  /// DNA-helix-on-leaf — Strain library.
  strain,

  /// Landscape rectangle with sun — Photo timeline.
  photo,

  /// Receipt with amount lines — Cost / expense tracker.
  receipt,

  /// Thermometer + droplet — Environment logs.
  thermo,

  /// Magnifying glass — Search.
  search,

  /// Two side-by-side cards with arrow — Cross-grow comparison.
  compare,
}

// ─────────────────────────────────────────────────────────────────────────────
// LineArtIllustration
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a single [EmptyArt] inside a soft circular surface that
/// mirrors the previous icon-in-circle hero — keeping the visual
/// rhythm of the empty-state widget while swapping the icon out for
/// custom art.
class LineArtIllustration extends StatelessWidget {
  /// Which illustration to render.
  final EmptyArt art;

  /// Edge length of the outer circle in logical pixels.
  ///
  /// The internal artwork scales proportionally — values from 64–160
  /// work well; 96 is the default to match the previous 80px hero
  /// circle with a touch more presence.
  final double size;

  /// Accent colour used for the interior "fill" elements (leaf
  /// silhouette, sun disc, etc.).  Defaults to [AppColors.primary]
  /// so the art picks up the app's brand green; pass a different
  /// colour when the surface already uses an accent (e.g. amber on
  /// the archive screen) so the illustration sits in the same family.
  final Color? accent;

  const LineArtIllustration({
    super.key,
    required this.art,
    this.size = 96,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? AppColors.primary;
    // A9 — every EmptyState that uses this illustration also renders
    // a title + subtitle right below it that already conveys the
    // meaning to screen readers ("No grows yet · Add your first
    // plant to get started").  The line-art is purely decorative,
    // so we wrap the whole hero in ExcludeSemantics to avoid
    // VoiceOver / TalkBack announcing a meaningless "image" node
    // before the actual copy.
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accentColor.withValues(alpha: 0.08),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.28),
            width: 1.2,
          ),
        ),
        child: Padding(
          // Inset the painter slightly so the strokes never touch the
          // border ring — the visual breathing room makes the
          // illustration feel intentional rather than cramped.
          padding: EdgeInsets.all(size * 0.16),
          child: CustomPaint(
            size: Size.square(size),
            painter: _EmptyArtPainter(
              art: art,
              strokeColor: context.colTextSecondary,
              accentColor: accentColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyArtPainter extends CustomPainter {
  final EmptyArt art;
  final Color strokeColor;
  final Color accentColor;

  const _EmptyArtPainter({
    required this.art,
    required this.strokeColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Normalise the painter to a 100×100 logical viewport so the
    // per-illustration coordinates can be hand-tuned in a stable
    // coordinate space regardless of the host's render size.
    final scale = size.shortestSide / 100;
    canvas.scale(scale);

    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accent = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    switch (art) {
      case EmptyArt.plant:
        _paintPlant(canvas, stroke, accent);
        break;
      case EmptyArt.note:
        _paintNote(canvas, stroke, accent);
        break;
      case EmptyArt.archive:
        _paintArchive(canvas, stroke, accent);
        break;
      case EmptyArt.strain:
        _paintStrain(canvas, stroke, accent);
        break;
      case EmptyArt.photo:
        _paintPhoto(canvas, stroke, accent);
        break;
      case EmptyArt.receipt:
        _paintReceipt(canvas, stroke, accent);
        break;
      case EmptyArt.thermo:
        _paintThermo(canvas, stroke, accent);
        break;
      case EmptyArt.search:
        _paintSearch(canvas, stroke, accent);
        break;
      case EmptyArt.compare:
        _paintCompare(canvas, stroke, accent);
        break;
    }
  }

  // ── Plant: pot trapezoid + two leaves + sprout ──────────────────────
  void _paintPlant(Canvas canvas, Paint stroke, Paint accent) {
    // Leaf silhouette (accent fill) — left leaf
    final leafL = Path()
      ..moveTo(50, 50)
      ..quadraticBezierTo(28, 32, 24, 48)
      ..quadraticBezierTo(28, 60, 50, 50)
      ..close();
    canvas.drawPath(leafL, accent);
    canvas.drawPath(leafL, stroke);

    // Leaf silhouette — right leaf
    final leafR = Path()
      ..moveTo(50, 50)
      ..quadraticBezierTo(72, 32, 76, 48)
      ..quadraticBezierTo(72, 60, 50, 50)
      ..close();
    canvas.drawPath(leafR, accent);
    canvas.drawPath(leafR, stroke);

    // Centre stem (down from leaf node into pot)
    canvas.drawLine(const Offset(50, 50), const Offset(50, 72), stroke);

    // Pot — trapezoid (wider at top)
    final pot = Path()
      ..moveTo(32, 72)
      ..lineTo(68, 72)
      ..lineTo(62, 92)
      ..lineTo(38, 92)
      ..close();
    canvas.drawPath(pot, stroke);

    // Rim highlight
    canvas.drawLine(const Offset(35, 76), const Offset(65, 76), stroke);
  }

  // ── Note: page outline + 3 lines + corner fold ──────────────────────
  void _paintNote(Canvas canvas, Paint stroke, Paint accent) {
    // Page body with folded corner
    final page = Path()
      ..moveTo(24, 20)
      ..lineTo(64, 20)
      ..lineTo(76, 32) // folded corner
      ..lineTo(76, 88)
      ..lineTo(24, 88)
      ..close();
    canvas.drawPath(page, stroke);

    // Folded-corner triangle (accent fill so it reads as a highlight)
    final fold = Path()
      ..moveTo(64, 20)
      ..lineTo(76, 32)
      ..lineTo(64, 32)
      ..close();
    canvas.drawPath(fold, accent);
    canvas.drawPath(fold, stroke);

    // Lines of text
    canvas.drawLine(const Offset(32, 46), const Offset(68, 46), stroke);
    canvas.drawLine(const Offset(32, 58), const Offset(68, 58), stroke);
    canvas.drawLine(const Offset(32, 70), const Offset(56, 70), stroke);
  }

  // ── Archive: storage box + leaf peeking out ─────────────────────────
  void _paintArchive(Canvas canvas, Paint stroke, Paint accent) {
    // Lid
    final lid = Path()
      ..moveTo(20, 40)
      ..lineTo(80, 40)
      ..lineTo(80, 52)
      ..lineTo(20, 52)
      ..close();
    canvas.drawPath(lid, stroke);

    // Box body
    final body = Path()
      ..moveTo(26, 52)
      ..lineTo(74, 52)
      ..lineTo(74, 88)
      ..lineTo(26, 88)
      ..close();
    canvas.drawPath(body, stroke);

    // Handle / cutout on lid
    final handle = Path()
      ..moveTo(44, 46)
      ..lineTo(56, 46);
    canvas.drawPath(handle, stroke);

    // Leaf peeking from inside (accent)
    final leaf = Path()
      ..moveTo(50, 40)
      ..quadraticBezierTo(38, 22, 44, 18)
      ..quadraticBezierTo(56, 24, 50, 40)
      ..close();
    canvas.drawPath(leaf, accent);
    canvas.drawPath(leaf, stroke);
  }

  // ── Strain: leaf + DNA helix crossbars ──────────────────────────────
  void _paintStrain(Canvas canvas, Paint stroke, Paint accent) {
    // Leaf body (accent fill)
    final leaf = Path()
      ..moveTo(50, 22)
      ..quadraticBezierTo(26, 36, 30, 62)
      ..quadraticBezierTo(50, 76, 70, 62)
      ..quadraticBezierTo(74, 36, 50, 22)
      ..close();
    canvas.drawPath(leaf, accent);
    canvas.drawPath(leaf, stroke);

    // Central vein
    canvas.drawLine(const Offset(50, 22), const Offset(50, 72), stroke);

    // Two side veins — slight curves outwards
    final veinL = Path()
      ..moveTo(50, 36)
      ..quadraticBezierTo(38, 44, 34, 56);
    final veinR = Path()
      ..moveTo(50, 36)
      ..quadraticBezierTo(62, 44, 66, 56);
    canvas.drawPath(veinL, stroke);
    canvas.drawPath(veinR, stroke);

    // Stem
    canvas.drawLine(const Offset(50, 72), const Offset(50, 88), stroke);
  }

  // ── Photo: landscape frame + sun + horizon ──────────────────────────
  void _paintPhoto(Canvas canvas, Paint stroke, Paint accent) {
    // Frame
    final frame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 26, 64, 50),
      const Radius.circular(4),
    );
    canvas.drawRRect(frame, stroke);

    // Sun (accent fill)
    canvas.drawCircle(const Offset(34, 42), 6, accent);
    canvas.drawCircle(const Offset(34, 42), 6, stroke);

    // Mountain silhouette (left-leaning triangle)
    final mountain = Path()
      ..moveTo(20, 70)
      ..lineTo(38, 50)
      ..lineTo(56, 70)
      ..close();
    canvas.drawPath(mountain, stroke);

    // Second smaller mountain (overlapping)
    final mountain2 = Path()
      ..moveTo(48, 70)
      ..lineTo(62, 56)
      ..lineTo(78, 70);
    canvas.drawPath(mountain2, stroke);
  }

  // ── Receipt: rectangle with tear bottom + amount lines ──────────────
  void _paintReceipt(Canvas canvas, Paint stroke, Paint accent) {
    // Body with zig-zag bottom edge (torn receipt)
    final body = Path()
      ..moveTo(30, 18)
      ..lineTo(70, 18)
      ..lineTo(70, 82)
      // zig-zag bottom: 4 V's
      ..lineTo(66, 88)
      ..lineTo(62, 82)
      ..lineTo(58, 88)
      ..lineTo(54, 82)
      ..lineTo(50, 88)
      ..lineTo(46, 82)
      ..lineTo(42, 88)
      ..lineTo(38, 82)
      ..lineTo(34, 88)
      ..lineTo(30, 82)
      ..close();
    canvas.drawPath(body, stroke);

    // Heading bar (accent — represents merchant logo / line)
    canvas.drawRect(const Rect.fromLTWH(36, 28, 28, 5), accent);

    // Amount lines — three rows of "item ........... price"
    void itemRow(double y) {
      canvas.drawLine(Offset(36, y), Offset(50, y), stroke);
      canvas.drawLine(Offset(56, y), Offset(64, y), stroke);
    }

    itemRow(46);
    itemRow(56);
    itemRow(66);
  }

  // ── Thermo: thermometer outline + droplet ───────────────────────────
  void _paintThermo(Canvas canvas, Paint stroke, Paint accent) {
    // Stem (capsule)
    final stem = RRect.fromRectAndRadius(
      const Rect.fromLTWH(36, 18, 14, 50),
      const Radius.circular(7),
    );
    canvas.drawRRect(stem, stroke);

    // Bulb
    canvas.drawCircle(const Offset(43, 76), 12, accent);
    canvas.drawCircle(const Offset(43, 76), 12, stroke);

    // Mercury fill (accent rectangle inside the stem, low)
    canvas.drawRect(const Rect.fromLTWH(40, 50, 6, 20), accent);

    // Scale ticks on the right of the stem
    for (int i = 0; i < 4; i++) {
      final y = 26 + i * 12.0;
      canvas.drawLine(Offset(52, y), Offset(58, y), stroke);
    }

    // Droplet (humidity glyph — top right corner)
    final drop = Path()
      ..moveTo(78, 22)
      ..quadraticBezierTo(86, 32, 78, 38)
      ..quadraticBezierTo(70, 32, 78, 22)
      ..close();
    canvas.drawPath(drop, accent);
    canvas.drawPath(drop, stroke);
  }

  // ── Search: magnifying glass on a soft card ─────────────────────────
  void _paintSearch(Canvas canvas, Paint stroke, Paint accent) {
    // Background card (subtle accent fill)
    final card = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 22, 64, 56),
      const Radius.circular(6),
    );
    canvas.drawRRect(card, accent);
    canvas.drawRRect(card, stroke);

    // Lens
    canvas.drawCircle(const Offset(46, 46), 14, stroke);

    // Handle
    canvas.drawLine(const Offset(56, 56), const Offset(70, 70), stroke);
  }

  // ── Compare: two cards + arrow connecting them ──────────────────────
  void _paintCompare(Canvas canvas, Paint stroke, Paint accent) {
    // Left card
    final cardL = RRect.fromRectAndRadius(
      const Rect.fromLTWH(14, 28, 28, 44),
      const Radius.circular(4),
    );
    canvas.drawRRect(cardL, accent);
    canvas.drawRRect(cardL, stroke);

    // Right card (slightly taller — visual variety so users read
    // "two different things" not "two identical things").
    final cardR = RRect.fromRectAndRadius(
      const Rect.fromLTWH(58, 22, 28, 50),
      const Radius.circular(4),
    );
    canvas.drawRRect(cardR, accent);
    canvas.drawRRect(cardR, stroke);

    // Bars inside left card
    canvas.drawLine(const Offset(20, 60), const Offset(20, 66), stroke);
    canvas.drawLine(const Offset(28, 56), const Offset(28, 66), stroke);
    canvas.drawLine(const Offset(36, 52), const Offset(36, 66), stroke);

    // Bars inside right card (taller — winning bars)
    canvas.drawLine(const Offset(64, 58), const Offset(64, 66), stroke);
    canvas.drawLine(const Offset(72, 50), const Offset(72, 66), stroke);
    canvas.drawLine(const Offset(80, 42), const Offset(80, 66), stroke);

    // Connecting arrow between cards (small chevron at midpoint)
    canvas.drawLine(const Offset(44, 50), const Offset(56, 50), stroke);
    canvas.drawLine(const Offset(52, 46), const Offset(56, 50), stroke);
    canvas.drawLine(const Offset(52, 54), const Offset(56, 50), stroke);
  }

  @override
  bool shouldRepaint(covariant _EmptyArtPainter old) =>
      old.art != art ||
      old.strokeColor != strokeColor ||
      old.accentColor != accentColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Convenience: standalone hero card so screens with bespoke empty
// states (e.g. Home's "what you'll unlock" list) can swap their
// icon-circle for the same line-art without going through the full
// `EmptyState` widget.  Wraps `LineArtIllustration` with a default
// margin block so the surrounding screen stays uniform.
// ─────────────────────────────────────────────────────────────────────────────

class LineArtHero extends StatelessWidget {
  final EmptyArt art;
  final double size;
  final Color? accent;

  const LineArtHero({
    super.key,
    required this.art,
    this.size = 96,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: LineArtIllustration(art: art, size: size, accent: accent),
      ),
    );
  }
}
