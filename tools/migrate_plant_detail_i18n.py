"""i18n round 3 (task #176) — swap hardcoded strings in plant_detail_screen.dart
for AppLocalizations getters.  One-shot helper; each (old, new, count) tuple
asserts how many occurrences it expects so silent drift fails loudly.
Run from repo root:  python tools/migrate_plant_detail_i18n.py
"""
import io

PATH = "lib/screens/plant_detail_screen.dart"
LOC = "AppLocalizations.of(context)"

pairs = [
    # ── Harvest sheet ────────────────────────────────────────────────
    ("title: 'Harvest Plant',", f"title: {LOC}.plantDetailHarvestPlant,", 1),
    ("Text('WET WEIGHT  ·  OPTIONAL',",
     f"Text({LOC}.plantDetailWetWeightHeader,", 1),
    ("""decoration: const InputDecoration(
                    labelText: 'Wet weight (g) — leave blank to skip',
                    helperText: 'Skip if you only weigh post-dry',
                    prefixIcon: Icon(Icons.scale_rounded),
                  ),""",
     f"""decoration: InputDecoration(
                    labelText: {LOC}.plantDetailWetWeightLabel,
                    helperText: {LOC}.plantDetailWetWeightHelper,
                    prefixIcon: const Icon(Icons.scale_rounded),
                  ),""", 1),
    ("Text('HARVEST DATE',", f"Text({LOC}.plantDetailHarvestDateHeader,", 1),
    ("label: const Text('Harvest Plant'),",
     f"label: Text({LOC}.plantDetailHarvestPlant),", 1),
    # ── Start-drying sheet ───────────────────────────────────────────
    ("title: 'Start Drying',", f"title: {LOC}.plantDetailStartDrying,", 1),
    ("Text('ESTIMATED DRY DATE',",
     f"Text({LOC}.plantDetailEstimatedDryDateHeader,", 1),
    # Sheet CTA + lifecycle CTA share the exact literal.
    ("label: const Text('Start Drying'),",
     f"label: Text({LOC}.plantDetailStartDrying),", 2),
    # ── Complete-drying sheet ────────────────────────────────────────
    ("title: 'Complete Drying',", f"title: {LOC}.plantDetailCompleteDrying,", 1),
    ("Text('DRY WEIGHT',", f"Text({LOC}.plantDetailDryWeightHeader,", 1),
    ("""decoration: const InputDecoration(
                    labelText: 'Dry weight (g)',
                    prefixIcon: Icon(Icons.scale_rounded),
                  ),""",
     f"""decoration: InputDecoration(
                    labelText: {LOC}.plantDetailDryWeightLabel,
                    prefixIcon: const Icon(Icons.scale_rounded),
                  ),""", 1),
    ("Text('DRYING END DATE (OPTIONAL)',",
     f"Text({LOC}.plantDetailDryingEndDateHeader,", 1),
    (": 'Set end date (optional)',",
     f": {LOC}.plantDetailSetEndDateOptional,", 1),
    ("label: const Text('Start Curing'),",
     f"label: Text({LOC}.plantDetailStartCuring),", 1),
    ("label: const Text('Complete Drying'),",
     f"label: Text({LOC}.plantDetailCompleteDrying),", 1),
    # ── Shared Cancel (3 sheets) ─────────────────────────────────────
    ("child: Text('Cancel',", f"child: Text({LOC}.commonCancel,", 3),
    # ── Photo journal tile ───────────────────────────────────────────
    ("Text('Photo Journal',", f"Text({LOC}.plantDetailPhotoJournal,", 1),
    ("""photoCount == 0
                        ? 'No photos yet'
                        : '$photoCount '
                            '${photoCount == 1 ? 'photo' : 'photos'}',""",
     f"""photoCount == 0
                        ? {LOC}.plantDetailNoPhotosYet
                        : {LOC}.plantDetailPhotoCount(photoCount),""", 1),
    # ── Note deleted confirmation ────────────────────────────────────
    ("title: 'Note Deleted',", f"title: {LOC}.plantDetailNoteDeletedTitle,", 1),
    ("subtitle: 'The note has been permanently\\nremoved from this plant.',",
     f"subtitle: {LOC}.plantDetailNoteDeletedSubtitle,", 1),
    # ── AppBar tooltips ──────────────────────────────────────────────
    ("tooltip: 'Edit Plant',", f"tooltip: {LOC}.plantDetailEditPlantTooltip,", 1),
    ("tooltip: 'Add Note',", f"tooltip: {LOC}.plantDetailAddNoteTooltip,", 1),
    ("tooltip: 'Take Clones',",
     f"tooltip: {LOC}.plantDetailTakeClonesTooltip,", 1),
    ("tooltip: 'Grow Report',",
     f"tooltip: {LOC}.plantDetailGrowReportTooltip,", 1),
    ("'Compare strains',", f"{LOC}.plantDetailCompareStrains,", 1),
    # ── Clone / seed / mother ────────────────────────────────────────
    ("""message: currentPlant.isClone
                            ? 'Propagated from a cutting — shares the mother plant\\'s genetics.'
                            : 'Started from seed — has its own genetic expression.',""",
     f"""message: currentPlant.isClone
                            ? {LOC}.plantDetailCloneOrigin
                            : {LOC}.plantDetailSeedOrigin,""", 1),
    ("""message:
                                  'This plant is a mother — $cloneCount '
                                  '${cloneCount == 1 ? 'cutting has' : 'cuttings have'} been taken '
                                  'and tracked as separate plants.',""",
     f"""message:
                                  {LOC}.plantDetailMotherSummary(cloneCount),""", 1),
    # ── Status banners ───────────────────────────────────────────────
    (": 'Target harvest date reached'",
     f": {LOC}.plantDetailTargetHarvestReached", 1),
    ("'This plant was removed.',", f"{LOC}.plantDetailPlantRemoved,", 1),
    # ── Stat chips ───────────────────────────────────────────────────
    ("'Day $daysInFlower of flower', AppColors.drying)",
     f"{LOC}.plantDetailDayOfFlower(daysInFlower), AppColors.drying)", 1),
    ("'Watered ${DateTime.now().difference(lastWatered).inDays}d ago',",
     f"{LOC}.plantDetailWateredAgo(DateTime.now().difference(lastWatered).inDays),", 1),
    ("'Fed ${DateTime.now().difference(lastFed).inDays}d ago',",
     f"{LOC}.plantDetailFedAgo(DateTime.now().difference(lastFed).inDays),", 1),
    ("'Trained ${DateTime.now().difference(lastTrained).inDays}d ago',",
     f"{LOC}.plantDetailTrainedAgo(DateTime.now().difference(lastTrained).inDays),", 1),
    ("'${latestHeightNote.heightCm!.toStringAsFixed(1)} cm tall',",
     f"{LOC}.plantDetailHeightTall(latestHeightNote.heightCm!.toStringAsFixed(1)),", 1),
    # ── Lazy sections ────────────────────────────────────────────────
    ("title: 'Yield insights',", f"title: {LOC}.plantDetailYieldInsights,", 1),
    ("subtitle: 'Projection + dry-weight maths',",
     f"subtitle: {LOC}.plantDetailYieldInsightsSubtitle,", 1),
    ("title: 'Community benchmark',",
     f"title: {LOC}.plantDetailCommunityBenchmark,", 1),
    ("subtitle: 'Compare to anonymous community yields',",
     f"subtitle: {LOC}.plantDetailCommunityBenchmarkSubtitle,", 1),
    ("title: 'Health score',", f"title: {LOC}.plantDetailHealthScore,", 1),
    ("subtitle: 'Issues, environment & care frequency',",
     f"subtitle: {LOC}.plantDetailHealthScoreSubtitle,", 1),
    ("title: 'Environment',", f"title: {LOC}.plantDetailEnvironmentSection,", 1),
    ("subtitle: 'Temp / humidity / VPD over time',",
     f"subtitle: {LOC}.plantDetailEnvironmentSectionSubtitle,", 1),
    ("title: 'Nutrient & pH trends',",
     f"title: {LOC}.plantDetailNutrientTrends,", 1),
    ("subtitle: 'EC / pH / N-P-K from feeding logs',",
     f"subtitle: {LOC}.plantDetailNutrientTrendsSubtitle,", 1),
    ("title: 'Height tracker',", f"title: {LOC}.plantDetailHeightTracker,", 1),
    ("subtitle: 'Growth curve from measurement notes',",
     f"subtitle: {LOC}.plantDetailHeightTrackerSubtitle,", 1),
    # ── Day counters ─────────────────────────────────────────────────
    ("label: 'Days\\nGrowing',", f"label: {LOC}.plantDetailDaysGrowing,", 1),
    ("label: 'Days\\nDrying',", f"label: {LOC}.plantDetailDaysDrying,", 1),
    ("label: 'Days\\nCuring',", f"label: {LOC}.plantDetailDaysCuring,", 1),
    ("label: overdue ? 'Overdue' : 'Left',",
     f"label: overdue ? {LOC}.plantDetailOverdue : {LOC}.plantDetailLeft,", 2),
    ("'${overdue ? 'since' : 'until'} ${fmtShortDate(end)}'",
     f"(overdue ? {LOC}.plantDetailSinceDate(fmtShortDate(end)) : {LOC}.plantDetailUntilDate(fmtShortDate(end)))", 2),
    # ── Lifecycle CTAs ───────────────────────────────────────────────
    ("label: const Text('Harvest'),",
     f"label: Text({LOC}.plantDetailHarvestCta),", 1),
    ("label: const Text('Complete Cure'),",
     f"label: Text({LOC}.plantDetailCompleteCure),", 1),
    ("Text('Lifecycle Complete',",
     f"Text({LOC}.plantDetailLifecycleComplete,", 1),
    ("label: const Text('View Report'),",
     f"label: Text({LOC}.plantDetailViewReport),", 2),
    ("label: const Text('Move'),", f"label: Text({LOC}.plantDetailMove),", 1),
    ("label: const Text('Cull'),", f"label: Text({LOC}.plantDetailCull),", 1),
    # ── Timeline + notes section ─────────────────────────────────────
    ("Text('Plant Timeline',", f"Text({LOC}.plantDetailPlantTimeline,", 1),
    ("""_noteFilter == null
                          ? 'Notes (${notes.length})'
                          : 'Notes (${filteredNotes.length}/${notes.length})',""",
     f"""_noteFilter == null
                          ? {LOC}.plantDetailNotesCount(notes.length)
                          : {LOC}.plantDetailNotesFiltered(
                              filteredNotes.length, notes.length),""", 1),
    ("label: Text('Templates',", f"label: Text({LOC}.plantDetailTemplates,", 1),
    ("label: Text('Add',", f"label: Text({LOC}.commonAdd,", 1),
    ("Text('No notes — tap Add to start',",
     f"Text({LOC}.plantDetailNoNotes,", 1),
    ("'No ${_noteFilter?.categoryLabel ?? ''} notes yet',",
     f"{LOC}.plantDetailNoCategoryNotes(_noteFilter?.categoryLabel ?? ''),", 1),
    # ── Resolve flow ─────────────────────────────────────────────────
    ("message: 'Mark as resolved',",
     f"message: {LOC}.plantDetailMarkResolved,", 1),
    ("Text('Resolve',", f"Text({LOC}.plantDetailResolve,", 1),
    ("Text('Resolved',", f"Text({LOC}.plantDetailResolved,", 1),
    # ── Note detail rows ─────────────────────────────────────────────
    ("'Product', note.feedingDetails!.productName)",
     f"{LOC}.plantDetailNoteProduct, note.feedingDetails!.productName)", 1),
    ("'Volume',", f"{LOC}.plantDetailNoteVolume,", 2),
    ("'NPK',", f"{LOC}.plantDetailNoteNpk,", 1),
    ("'Amendments', note.feedingDetails!.amendments)",
     f"{LOC}.plantDetailNoteAmendments, note.feedingDetails!.amendments)", 1),
    ("'pH In',", f"{LOC}.plantDetailNotePhIn,", 1),
    ("'Runoff pH',", f"{LOC}.plantDetailNoteRunoffPh,", 1),
    ("_noteDetailRow('Product', note.ipmDetails!.product),",
     f"_noteDetailRow({LOC}.plantDetailNoteProduct, note.ipmDetails!.product),", 1),
    ("_noteDetailRow('Target', note.ipmDetails!.targetPest),",
     f"_noteDetailRow({LOC}.plantDetailNoteTarget, note.ipmDetails!.targetPest),", 1),
    ("_noteDetailRow('Method', note.ipmDetails!.method),",
     f"_noteDetailRow({LOC}.plantDetailNoteMethod, note.ipmDetails!.method),", 1),
    ("'Dilution',", f"{LOC}.plantDetailNoteDilution,", 1),
]


def main() -> None:
    with io.open(PATH, encoding="utf-8") as f:
        text = f.read()
    errors = []
    for old, new, count in pairs:
        found = text.count(old)
        if found != count:
            errors.append(f"expected {count}, found {found}: {old[:70]!r}")
            continue
        text = text.replace(old, new)
    if errors:
        for e in errors:
            print("MISMATCH:", e)
        raise SystemExit(1)
    with io.open(PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"applied {len(pairs)} replacements")


if __name__ == "__main__":
    main()
