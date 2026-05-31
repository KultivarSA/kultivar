// P1.4 — `cacheWidth` / `cacheHeight` helper for Image.file thumbnails.
//
// Flutter's `Image.file` decodes the source file at its native pixel
// resolution by default.  A modern iPhone photo is 4032 × 3024 ≈
// 48 MB once decoded into an ARGB888 surface.  A 30-tile photo
// timeline grid would peak at ~1.4 GB of bitmap memory — guaranteed
// OOM on iPhone SE / iPad mini, and a real risk even on M-series
// iPads under memory pressure.
//
// Passing `cacheWidth` (in *physical* pixels) tells the decoder to
// down-sample at decode time, so we only ever hold a bitmap that
// matches the on-screen pixel budget.  A 96 px thumbnail at 3×
// devicePixelRatio decodes to 288 × 288 px ≈ 0.33 MB instead of 48 MB
// — a ~150× win, paid for once per image load.
//
// Usage:
//
//   Image.file(
//     File(photo.path),
//     cacheWidth: imageCacheWidth(context, 96),
//     fit: BoxFit.cover,
//   );
//
// Pass the *logical* width the widget will actually occupy.  The
// helper multiplies by devicePixelRatio so you get a physical-pixel
// cap.  For square thumbnails, only `cacheWidth` is needed — Flutter
// preserves aspect ratio and `cacheHeight` becomes redundant.
//
// Skip cacheWidth on the full-screen photo viewer / slideshow / the
// shareable PDF report — those genuinely need native resolution.

import 'package:flutter/widgets.dart';

/// Returns the physical-pixel cap to pass as `cacheWidth` for an
/// image that will display at `logicalWidth` logical pixels in
/// the current context.
///
/// Returns `null` if `logicalWidth` is null or zero (lets the caller
/// degrade to default decoding rather than caching at 0 px).
int? imageCacheWidth(BuildContext context, double? logicalWidth) {
  if (logicalWidth == null || logicalWidth <= 0) return null;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  // Round up so we never undershoot the display resolution — at the
  // boundary, half a physical pixel of undersample is visible as
  // softness on Retina screens.
  return (logicalWidth * dpr).ceil();
}

/// Same as [imageCacheWidth] but for `cacheHeight`.  Use only when
/// the image is letterboxed by height (e.g. a 16:9 banner inside a
/// fixed-height row).  For square / aspect-ratio-cover thumbnails,
/// cacheWidth alone is enough.
int? imageCacheHeight(BuildContext context, double? logicalHeight) {
  if (logicalHeight == null || logicalHeight <= 0) return null;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalHeight * dpr).ceil();
}
