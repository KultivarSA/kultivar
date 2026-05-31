import '../models/plant.dart';
import '../models/plant_history_event.dart';
import '../models/plant_note.dart';

List<PlantHistoryEvent> buildPlantTimeline({
  required Plant plant,
  required List<PlantNote> notes,
}) {
  final events = <PlantHistoryEvent>[];

  // 🌱 Planted
  events.add(PlantHistoryEvent(
    timestamp: plant.startDate,
    type: PlantHistoryEventType.planted,
    title: plant.isClone ? 'Clone added' : 'Seed started',
    description: 'Added to the grow.',
  ));

  // 🌸 Flip to flower (photoperiod plants only)
  if (!plant.isAutoflower && plant.flipDate != null) {
    events.add(PlantHistoryEvent(
      timestamp: plant.flipDate!,
      type: PlantHistoryEventType.flipToFlower,
      title: 'Flipped to Flower',
      description: 'Light schedule changed to 12/12.',
    ));
  }

  // 🌾 Harvested
  if (plant.harvestedDate != null) {
    events.add(PlantHistoryEvent(
      timestamp: plant.harvestedDate!,
      type: PlantHistoryEventType.harvested,
      title: 'Harvested',
      description: plant.wetWeight != null
          ? 'Wet weight: '
              '${plant.wetWeight!.toStringAsFixed(1)} g'
          : null,
    ));

    events.add(PlantHistoryEvent(
      timestamp: plant.harvestedDate!,
      type: PlantHistoryEventType.dryingStarted,
      title: 'Drying started',
      description: plant.dryingEndDate != null
          ? 'Planned until '
              '${plant.dryingEndDate!.toLocal().toString().split(' ').first}'
          : null,
    ));
  }

  // 🫙 Drying completed → Curing started
  if (plant.dryingEndDate != null &&
      (plant.status == PlantStatus.curing ||
          plant.status == PlantStatus.completed)) {
    events.add(PlantHistoryEvent(
      timestamp: plant.dryingEndDate!,
      type: PlantHistoryEventType.dryingCompleted,
      title: 'Drying completed',
      description: plant.dryWeight != null
          ? 'Dry weight: '
              '${plant.dryWeight!.toStringAsFixed(1)} g'
          : null,
    ));

    events.add(PlantHistoryEvent(
      timestamp: plant.dryingEndDate!,
      type: PlantHistoryEventType.curingStarted,
      title: 'Curing started',
    ));
  }

  // ✅ Curing completed
  if (plant.status == PlantStatus.completed ||
      (plant.archivedAt != null &&
          plant.archiveReason == 'Curing completed successfully')) {
    events.add(PlantHistoryEvent(
      timestamp: plant.archivedAt ?? DateTime.now(),
      type: PlantHistoryEventType.curingCompleted,
      title: 'Curing completed',
      description: 'Lifecycle finished successfully.',
    ));
  }

  // ❌ Removed
  if (plant.status == PlantStatus.removed && plant.archivedAt != null) {
    events.add(PlantHistoryEvent(
      timestamp: plant.archivedAt!,
      type: PlantHistoryEventType.removed,
      title: 'Plant removed',
      description: plant.archiveReason,
    ));
  }

  // 📝 Notes — include first photo + category so the timeline can
  // render the right icon/colour and group milestones into the
  // milestone filter.
  for (final note in notes) {
    events.add(PlantHistoryEvent(
      timestamp: note.createdAt,
      type: PlantHistoryEventType.note,
      title: note.categoryLabel,
      description: note.content,
      photoUrl: note.photoUrls.isNotEmpty ? note.photoUrls.first : null,
      noteCategory: note.category,
    ));
  }

  events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return events;
}
