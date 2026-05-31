class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs  = 8;
  static const double sm  = 12;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  static const double radiusSm  = 8;
  static const double radiusMd  = 12;
  static const double radiusLg  = 16;
  static const double radiusXl  = 24;
  static const double radiusFull = 999;

  static const double cardPadding  = 16;
  static const double pagePadding  = 20;
  static const double sectionGap   = 28;

  /// P3.9 — Bottom padding to reserve inside a scrollable so the
  /// last row is fully visible above a floating action button.
  /// 96 = FAB diameter (56) + bottom margin (16) + breathing room (24).
  /// Use as `EdgeInsets.only(bottom: AppSpacing.fabClearance)` on
  /// any list/scroll view whose host screen also shows a FAB.
  static const double fabClearance = 96;

  // ── Border widths ────────────────────────────
  //
  // P3.8 — Two canonical border widths.  `borderHair` is the default
  // 1 px line used on cards, dividers, inputs, and anywhere the
  // border is a structural cue rather than a category signal.
  // `borderEmphasis` is the louder 1.5 px line used when the border
  // *itself* carries semantic information — currently only the photo
  // timeline grid's category-tinted rings (A8 scan-readability) and
  // the AppToast outer ring.  Default to `borderHair`; opt into
  // `borderEmphasis` deliberately.
  static const double borderHair = 1.0;
  static const double borderEmphasis = 1.5;
}