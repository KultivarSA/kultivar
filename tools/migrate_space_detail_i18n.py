"""i18n round 3 part 2 (task #176) — swap hardcoded strings in
space_detail_screen.dart for AppLocalizations getters.  Same pattern as
migrate_plant_detail_i18n.py: every (old, new, count) tuple asserts its
occurrence count so source drift fails loudly.
Run from repo root:  python tools/migrate_space_detail_i18n.py
"""
import io

PATH = "lib/screens/space_detail_screen.dart"
LOC = "AppLocalizations.of(context)"

pairs = [
    # ── DLI label helper ────────────────────────────────────────────
    ("""  String _dliLabel(double dli) {
    if (dli < 12) return 'Too Low';
    if (dli < 20) return 'Seedling';
    if (dli < 40) return 'Vegetative';
    if (dli <= 65) return 'Flowering';
    return 'Too High';
  }""",
     f"""  String _dliLabel(double dli) {{
    if (dli < 12) return {LOC}.spaceDetailDliTooLow;
    if (dli < 20) return {LOC}.spaceDetailStageSeedling;
    if (dli < 40) return {LOC}.spaceDetailStageVegetative;
    if (dli <= 65) return {LOC}.spaceDetailStageFlowering;
    return {LOC}.spaceDetailDliTooHigh;
  }}""", 1),
    # ── Edit Space sheet ────────────────────────────────────────────
    ("title: 'Edit Space',", f"title: {LOC}.spaceDetailEditSpace,", 1),
    ("subtitle: 'Update name, type & hardware',",
     f"subtitle: {LOC}.spaceDetailEditSpaceSubtitle,", 1),
    ("""decoration: const InputDecoration(
                  labelText: 'Space Name *',
                  prefixIcon: Icon(Icons.label_rounded, size: 18),
                ),""",
     f"""decoration: InputDecoration(
                  labelText: {LOC}.spaceDetailSpaceNameLabel,
                  prefixIcon: const Icon(Icons.label_rounded, size: 18),
                ),""", 1),
    ("Text('Type',", f"Text({LOC}.spaceDetailTypeLabel,", 1),
    ("""decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_rounded, size: 18),
                ),""",
     f"""decoration: InputDecoration(
                  labelText: {LOC}.spaceDetailNotesOptionalLabel,
                  prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                ),""", 1),
    ("Text('Hardware (optional)',",
     f"Text({LOC}.spaceDetailHardwareOptional,", 1),
    ("""decoration: const InputDecoration(
                      labelText: 'Wattage',
                      suffixText: 'W',
                      prefixIcon: Icon(Icons.wb_incandescent_rounded,
                          size: 18),
                    ),""",
     f"""decoration: InputDecoration(
                      labelText: {LOC}.spaceDetailWattageLabel,
                      suffixText: 'W',
                      prefixIcon: const Icon(Icons.wb_incandescent_rounded,
                          size: 18),
                    ),""", 1),
    ("""decoration: const InputDecoration(
                      labelText: 'Area',
                      suffixText: 'm²',
                      prefixIcon:
                          Icon(Icons.square_foot_rounded, size: 18),
                    ),""",
     f"""decoration: InputDecoration(
                      labelText: {LOC}.spaceDetailAreaLabel,
                      suffixText: 'm²',
                      prefixIcon:
                          const Icon(Icons.square_foot_rounded, size: 18),
                    ),""", 1),
    ("label: const Text('Save Changes'),",
     f"label: Text({LOC}.spaceDetailSaveChanges),", 1),
    ("AppToast.show(context, 'Space updated');",
     f"AppToast.show(context, {LOC}.spaceDetailSpaceUpdatedToast);", 1),
    # ── Log Environment sheet ───────────────────────────────────────
    ("title: 'Log Environment',", f"title: {LOC}.fabLogEnvironment,", 1),
    ("""decoration: const InputDecoration(
                labelText: 'Humidity (%)',
                hintText: '55.0',
                suffixText: '%',
                prefixIcon: Icon(Icons.water_drop_rounded, size: 18),
              ),""",
     f"""decoration: InputDecoration(
                labelText: {LOC}.spaceDetailHumidityPctLabel,
                hintText: '55.0',
                suffixText: '%',
                prefixIcon: const Icon(Icons.water_drop_rounded, size: 18),
              ),""", 1),
    ("""decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
              ),""",
     f"""decoration: InputDecoration(
                labelText: {LOC}.spaceDetailNotesOptionalLabel,
                prefixIcon: const Icon(Icons.notes_rounded, size: 18),
              ),""", 1),
    ("label: const Text('Save Reading'),",
     f"label: Text({LOC}.spaceDetailSaveReading),", 1),
    ("'Enter at least a temperature or humidity value',",
     f"{LOC}.spaceDetailEnterTempOrHumidity,", 1),
    ("child: Text('Cancel',", f"child: Text({LOC}.commonCancel,", 2),
    # ── Gauges + log entries ────────────────────────────────────────
    ("hasValue ? (isOptimal ? 'Optimal' : 'Check') : 'No data',",
     f"hasValue\n                      ? (isOptimal ? {LOC}.spaceDetailOptimal : {LOC}.spaceDetailCheck)\n                      : {LOC}.spaceDetailNoData,", 1),
    ("isOptimal ? 'Optimal' : 'Check',",
     f"isOptimal ? {LOC}.spaceDetailOptimal : {LOC}.spaceDetailCheck,", 1),
    ("""'Ideal ${optimalMin.toStringAsFixed(0)}–'
                  '${optimalMax.toStringAsFixed(0)}$unit',""",
     f"""{LOC}.spaceDetailIdealRange(
                      '${{optimalMin.toStringAsFixed(0)}}–'
                      '${{optimalMax.toStringAsFixed(0)}}$unit'),""", 1),
    # ── Delete space flow ───────────────────────────────────────────
    ("title: 'Delete \"${space.name}\"?',",
     f"title: {LOC}.spaceDetailDeleteSpaceTitle(space.name),", 1),
    ("body: 'This action cannot be undone.',",
     f"body: {LOC}.spaceDetailCannotBeUndone,", 1),
    ("""'$activePlantCount active '
                    '${activePlantCount == 1 ? 'plant' : 'plants'} '
                    'will be archived as removed.',""",
     f"{LOC}.spaceDetailPlantsWillBeArchived(activePlantCount),", 1),
    ("confirmLabel: 'Delete Space',",
     f"confirmLabel: {LOC}.spaceDetailDeleteSpace,", 1),
    ("""final msg = archived > 0
          ? '"${space.name}" deleted · $archived '
              '${archived == 1 ? 'plant' : 'plants'} archived'
          : '"${space.name}" deleted';""",
     f"""final msg = archived > 0
          ? {LOC}.spaceDetailDeletedWithArchived(archived, space.name)
          : {LOC}.spaceDetailDeleted(space.name);""", 1),
    # ── AppBar tooltips + popup menu ────────────────────────────────
    ("tooltip: 'View plant timeline',",
     f"tooltip: {LOC}.spaceDetailViewPlantTimelineTooltip,", 1),
    ("tooltip: 'Nutrient Calculator',",
     f"tooltip: {LOC}.spaceDetailNutrientCalculatorTooltip,", 1),
    ("tooltip: 'Log care for all plants',",
     f"tooltip: {LOC}.spaceDetailLogCareAllTooltip,", 1),
    ("""              const PopupMenuItem(
                value: _SpaceAction.edit,
                child: Row(children: [
                  Icon(Icons.edit_rounded,
                      color: AppColors.secondary, size: 20),
                  SizedBox(width: AppSpacing.xs),
                  Text('Edit Space'),
                ]),
              ),
              const PopupMenuItem(
                value: _SpaceAction.delete,
                child: Row(children: [
                  Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                  SizedBox(width: AppSpacing.xs),
                  Text('Delete Space',
                      style: TextStyle(color: AppColors.danger)),
                ]),
              ),""",
     f"""              PopupMenuItem(
                value: _SpaceAction.edit,
                child: Row(children: [
                  const Icon(Icons.edit_rounded,
                      color: AppColors.secondary, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text({LOC}.spaceDetailEditSpace),
                ]),
              ),
              PopupMenuItem(
                value: _SpaceAction.delete,
                child: Row(children: [
                  const Icon(Icons.delete_outline,
                      color: AppColors.danger, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text({LOC}.spaceDetailDeleteSpace,
                      style: const TextStyle(color: AppColors.danger)),
                ]),
              ),""", 1),
    ("label: Text('Log Environment',",
     f"label: Text({LOC}.fabLogEnvironment,", 1),
    # ── Current conditions ──────────────────────────────────────────
    ("Text('Current Conditions',",
     f"Text({LOC}.spaceDetailCurrentConditions,", 1),
    ("""latest != null
                  ? 'Last reading: ${fmtShortDateTime(latest.recordedAt)}'
                  : 'No readings logged yet',""",
     f"""latest != null
                  ? {LOC}.spaceDetailLastReading(
                      fmtShortDateTime(latest.recordedAt))
                  : {LOC}.spaceDetailNoReadingsYet,""", 1),
    ("label: 'Temperature',", f"label: {LOC}.spaceDetailTemperature,", 1),
    ("label: 'Humidity',", f"label: {LOC}.spaceDetailHumidity,", 1),
    ("'View Full Analytics',", f"{LOC}.spaceDetailViewFullAnalytics,", 1),
    ("'phase breakdown · VPD · streaks',",
     f"{LOC}.spaceDetailAnalyticsSubtitle,", 1),
    ("AppToast.show(context, 'Thresholds saved');",
     f"AppToast.show(context, {LOC}.spaceDetailThresholdsSaved);", 1),
    # ── Light calculator ────────────────────────────────────────────
    ("Text('Light Calculator',", f"Text({LOC}.spaceDetailLightCalculator,", 1),
    ("'Calculate Daily Light Integral from PPFD and photoperiod.',",
     f"{LOC}.spaceDetailLightCalcSubtitle,", 1),
    ("""decoration: const InputDecoration(
                    labelText: 'PPFD',
                    suffixText: 'µmol/m²/s',
                  ),""",
     f"""decoration: InputDecoration(
                    labelText: {LOC}.spaceDetailPpfd,
                    suffixText: 'µmol/m²/s',
                  ),""", 1),
    ("labelText: 'Photoperiod',", f"labelText: {LOC}.spaceDetailPhotoperiod,", 1),
    ("Text('Stage',", f"Text({LOC}.spaceDetailStage,", 1),
    ("Text('PPFD',", f"Text({LOC}.spaceDetailPpfd,", 1),
    ("Text('Hours',", f"Text({LOC}.spaceDetailHours,", 1),
    ("_ppfdRow(context, 'Seedling', '100–300', '18 h/day'),",
     f"_ppfdRow(context, {LOC}.spaceDetailStageSeedling, '100–300', '18 h/day'),", 1),
    ("_ppfdRow(context, 'Vegetative', '300–600', '18 h/day'),",
     f"_ppfdRow(context, {LOC}.spaceDetailStageVegetative, '300–600', '18 h/day'),", 1),
    ("_ppfdRow(context, 'Flowering', '600–900', '12 h/day'),",
     f"_ppfdRow(context, {LOC}.spaceDetailStageFlowering, '600–900', '12 h/day'),", 1),
    ("_ppfdRow(context, 'Late Flower', '800–1000', '12 h/day'),",
     f"_ppfdRow(context, {LOC}.spaceDetailStageLateFlower, '800–1000', '12 h/day'),", 1),
    ("_dliRef('Seedling DLI', '12–20'),",
     f"_dliRef({LOC}.spaceDetailSeedlingDli, '12–20'),", 1),
    ("_dliRef('Vegetative DLI', '20–40'),",
     f"_dliRef({LOC}.spaceDetailVegetativeDli, '20–40'),", 1),
    ("_dliRef('Flowering DLI', '40–65'),",
     f"_dliRef({LOC}.spaceDetailFloweringDli, '40–65'),", 1),
    # ── History ─────────────────────────────────────────────────────
    ("'History (${logs.length})',",
     f"{LOC}.spaceDetailHistoryCount(logs.length),", 1),
    ("""'No readings yet\\n'
                    'Tap Log Environment to start',""",
     f"{LOC}.spaceDetailNoReadingsEmpty,", 1),
    ("title: 'Log Entry Deleted',",
     f"title: {LOC}.spaceDetailLogEntryDeleted,", 1),
    ("subtitle: 'The environment log entry\\nhas been removed.',",
     f"subtitle: {LOC}.spaceDetailLogEntryDeletedSubtitle,", 1),
    ("""_showAllLogs
                            ? 'Show less'
                            : 'Show all ${logs.length} readings',""",
     f"""_showAllLogs
                            ? {LOC}.spaceDetailShowLess
                            : {LOC}.spaceDetailShowAllReadings(logs.length),""", 1),
    # ── Care schedule card ──────────────────────────────────────────
    ("AppToast.show(context, 'Care schedule saved');",
     f"AppToast.show(context, {LOC}.spaceDetailCareScheduleSaved);", 1),
    ("'Every $interval ${interval == 1 ? 'day' : 'days'}',",
     f"{LOC}.spaceDetailEveryNDays(interval),", 1),
    ("Text('Care Schedule',", f"Text({LOC}.spaceDetailCareSchedule,", 1),
    ("'Space-wide',", f"{LOC}.spaceDetailSpaceWide,", 1),
    ("'One schedule for all plants in this space.',",
     f"{LOC}.spaceDetailOneScheduleAll,", 1),
    ("label: 'Watering',", f"label: {LOC}.spaceDetailWatering,", 1),
    ("label: 'Feeding',", f"label: {LOC}.spaceDetailFeeding,", 1),
    ("label: 'IPM / Pest Inspection',",
     f"label: {LOC}.spaceDetailIpmInspection,", 1),
    ("label: const Text('Save Schedule'),",
     f"label: Text({LOC}.spaceDetailSaveSchedule),", 1),
    # ── Plants section ──────────────────────────────────────────────
    ("'Plants (${plants.length})',",
     f"{LOC}.spaceDetailPlantsCount(plants.length),", 1),
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
