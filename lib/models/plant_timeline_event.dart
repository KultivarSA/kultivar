import 'package:flutter/material.dart';

enum TimelineEventType {
  start,
  move,
  note,
  harvest,
  drying,
  curing,
  archive,
}

class PlantTimelineEvent {
  final DateTime timestamp;
  final TimelineEventType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  PlantTimelineEvent({
    required this.timestamp,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
