// P2.5 — Terpene-to-colour mapping, single source of truth.
//
// The same 10-entry palette was duplicated across three files:
//   - lib/screens/strain_library_screen.dart
//   - lib/screens/strain_detail_screen.dart
//   - lib/widgets/strain_preview_sheet.dart
//
// Each copy had to be kept in sync by hand whenever the palette
// changed — a maintenance trap.  Centralising here turns it into
// one import + one lookup.
//
// Colour rationale:
//   - myrcene       → green   (most common in indica; "earthy")
//   - caryophyllene → orange  (peppery)
//   - limonene      → yellow  (citrus)
//   - linalool      → lilac   (floral)
//   - pinene        → sky-blue (pine)
//   - terpinolene   → amber   (smoky-floral)
//   - ocimene       → light green (sweet-herbal)
//   - humulene      → brown   (hops, woody)
//   - bisabolol     → pink    (chamomile)
//   - valencene     → coral   (sweet citrus)
//
// These are NOT brand colours — they exist purely to make the
// terpene chips on the strain library / preview surfaces glanceable.
// If the palette evolves (new terpenes, accessibility re-tuning),
// edit only this file.

import 'package:flutter/material.dart';

/// Lookup by lower-case terpene name.  Callers should default to
/// some neutral fallback (`AppColors.textMuted`) when a name is
/// absent — terpenes outside the canonical ten do exist.
const Map<String, Color> kTerpeneColors = {
  'myrcene': Color(0xFF4CAF50),
  'caryophyllene': Color(0xFFFF7043),
  'limonene': Color(0xFFFFEB3B),
  'linalool': Color(0xFFCE93D8),
  'pinene': Color(0xFF29B6F6),
  'terpinolene': Color(0xFFFFB300),
  'ocimene': Color(0xFF66BB6A),
  'humulene': Color(0xFFA1887F),
  'bisabolol': Color(0xFFF48FB1),
  'valencene': Color(0xFFFF8A65),
};
