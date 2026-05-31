import 'plant_note.dart';

enum PlantHistoryEventType {
  planted,
  flipToFlower,
  moved,
  harvested,
  dryingStarted,
  dryingCompleted,
  curingStarted,
  curingCompleted,
  removed,
  note,
}

class PlantHistoryEvent {
  final DateTime timestamp;
  final PlantHistoryEventType type;
  final String title;
  final String? description;
  final String? photoUrl; // ✅ first photo from note

  /// When [type] is [PlantHistoryEventType.note], carries the note's
  /// category so the timeline can render category-specific icons +
  /// colours (water drop for watering, scissors for training, etc.)
  /// instead of the generic "edit note" glyph.
  ///
  /// Also used by the timeline's Milestones filter — notes with
  /// `category == NoteCategory.milestone` are surfaced under the
  /// milestone filter rather than the generic notes bucket.
  final NoteCategory? noteCategory;

  const PlantHistoryEvent({
    required this.timestamp,
    required this.type,
    required this.title,
    this.description,
    this.photoUrl,
    this.noteCategory,
  });
}
