// P2.6 — AppOpacity constants.
//
// Standardised alpha values for `Color.withValues(alpha: …)` calls.
// The codebase had grown a long tail of raw literals (0.08, 0.12,
// 0.15, 0.18, 0.25, 0.28, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80) that
// nominally meant the same thing — "muted border", "tinted fill",
// "scrim over photo" — but drifted by ±0.02 between widgets.  The
// inconsistency was visible on the photo grid (1.5 px / α 0.6
// borders) sitting next to plain cards (1 px / α 0.4).
//
// These tokens give a single source of truth.  When you need a new
// alpha, add a name here and use the token; don't sprinkle another
// raw 0.17 literal at the call site.
//
// Naming convention:
//   - `tint*`  — coloured fill behind an icon / chip / badge.
//                Always low alpha (8–18%).
//   - `border*` — divider / outline alpha, mostly used with the
//                category color of the surrounding element.
//   - `scrim*` — overlay on top of a photo or full-screen image.
//   - `text*`  — desaturated text alpha (dim labels, captions).
//
// Migration policy: theme chrome (this file, app_theme, app_sheet,
// app_toast) uses the tokens.  Feature widgets are migrated
// opportunistically as they're touched — no flag-day rewrite.

class AppOpacity {
  AppOpacity._();

  // ── Tinted backgrounds (icon chips, category badges) ──────────────
  /// 6 % — barely-there blush of category colour.  Used for the
  /// faintest "category background" on tile-sized chips.
  static const tintFaint = 0.06;

  /// 8 % — default category chip background.
  static const tintLight = 0.08;

  /// 12 % — the most common tinted-fill alpha in the codebase.
  /// Use this for icon-square backgrounds, status pills, and any
  /// "container that hints at a category colour".
  static const tintMedium = 0.12;

  /// 18 % — a touch louder; appears in confetti and celebration
  /// overlays where the tint should read at a glance.
  static const tintStrong = 0.18;

  // ── Borders / dividers ────────────────────────────────────────────
  /// 25 % — bottom-shadow under a hovering button / focused chip.
  static const borderShadow = 0.25;

  /// 30 % — a category-tinted divider between sections.
  static const borderFaint = 0.30;

  /// 40 % — default "muted" border on a tinted tile.
  static const borderMuted = 0.40;

  /// 60 % — the loudest the border alpha ever needs to go (photo
  /// grid tiles, where the category ring is the dominant signal).
  static const borderHover = 0.60;

  // ── Scrims / overlays ─────────────────────────────────────────────
  /// 30 % — soft gradient overlay over a photo to keep white text
  /// legible without darkening the image.
  static const scrimSoft = 0.30;

  /// 50 % — standard half-tone scrim for bottom sheets above content.
  static const scrimMedium = 0.50;

  /// 70 % — heavy scrim under modal dialogs.
  static const scrimHeavy = 0.70;

  /// 80 % — near-opaque overlay for hero treatments and the
  /// celebration confetti's brightest particles.
  static const scrimSolid = 0.80;

  // ── Text on coloured surfaces ─────────────────────────────────────
  /// 38 % — placeholder / hint text on dim surfaces.
  static const textPlaceholder = 0.38;

  /// 70 % — secondary text (caption beneath a label).
  static const textSecondary = 0.70;
}
