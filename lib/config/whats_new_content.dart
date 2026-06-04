/// Per-build content registry for the What's New sheet.
///
/// Each entry is keyed by `versionCode` (the integer Play Store uses
/// to order builds).  The sheet only fires when `WhatsNewService`
/// detects an upgrade, AND a matching entry exists here.  Builds
/// without an entry (the `==` case, or a hotfix where the user-
/// facing surface didn't change) silently no-op.
///
/// ## Editing checklist when shipping a new build
///
/// 1. Bump `version: 1.0.0+1` in `pubspec.yaml`.  The `+N` suffix is
///    `versionCode`; this map keys off it.
/// 2. Add the new entry below.  Keep `highlights` to **3–5 bullets**
///    -- a screen full of bullets is unreadable; pick the things a
///    user actually wants to know about.
/// 3. Match `versionName` to the semantic version (the part before
///    `+`).  The sheet uses it for the pill header.
/// 4. Update `store_metadata/android/en-US/changelogs/<versionCode>.txt`
///    with the same highlights so the Play "What's new" listing
///    stays in sync.
///
/// ## Why v1.0 is absent
///
/// Per the "Option A" decision (PR discussion), v1.0 ships the
/// infrastructure but **no first-install content**.  The welcome
/// onboarding already covers v1 first launch -- a second What's New
/// sheet on top would feel like double-onboarding.  The first user-
/// visible firing will be when v1.0.1 (or v1.1) updates land.
const Map<int, WhatsNewEntry> kWhatsNewByBuild = {
  // Build 2 (v1.0.1) and later go here.  Empty until then.
};

/// User-facing copy for one What's New presentation.
class WhatsNewEntry {
  /// Semantic version string used in the sheet header pill,
  /// e.g. `'1.0.1'`.  Pulled from `pubspec.yaml`'s `version:` line
  /// (the part before `+`).
  final String versionName;

  /// One-line celebratory header above the bullets, e.g.
  /// `'Faster harvests.'`.  Keep it short -- it sits above the
  /// bullets at a larger font size.
  final String headline;

  /// 3-5 bullet strings.  Each ideally fits on one line at 16 sp.
  /// Lead with the user-visible value, not the technical change.
  ///
  /// Good:  `'Photo journal scrolls 30 % faster'`
  /// Bad:   `'Migrated thumbnails to ListView.builder + cacheWidth'`
  final List<String> highlights;

  const WhatsNewEntry({
    required this.versionName,
    required this.headline,
    required this.highlights,
  });
}
