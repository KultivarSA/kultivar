import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;

import '../main.dart';
import '../models/harvest_log.dart';
import '../models/plant.dart';
import '../repository/grow_repository.dart';
import '../services/notification_service.dart';

class PlantWorkflowService {
  final GrowRepository repo;
  final NotificationService notifications;

  PlantWorkflowService(this.repo, this.notifications);

  // ── 🌾 Growing → Harvested ───────────────────

  void harvestPlant({
    required Plant plant,
    double? wetWeight,
    String? notes,
    DateTime? harvestedDate,
  }) {
    final now = harvestedDate ?? DateTime.now();
    repo.addHarvestLog(HarvestLog(
      id: repo.newId(),
      plantId: plant.id,
      plantName: plant.name,
      strain: plant.strain,
      harvestedDate: now,
      wetWeight: wetWeight,
      notes: notes,
      isDraft: true,
      phenotypeTag: plant.phenotypeTag,
    ));
    repo.updatePlant(plant.copyWith(
      status: PlantStatus.harvested,
      harvestedDate: now,
      wetWeight: wetWeight,
    ));
  }

  // ── 🌬 Harvested → Drying ────────────────────

  void startDrying({
    required Plant plant,
    required DateTime dryingEndDate,
  }) {
    repo.updatePlant(plant.copyWith(
      status: PlantStatus.drying,
      dryingEndDate: dryingEndDate,
    ));

    // Schedule drying check reminder if enabled
    if (plant.dryingCheckNotification &&
        KultivarApp.notifDryingEnabled.value) {
      final checkTime = DateTime.now().add(const Duration(days: 3));
      unawaited(notifications.scheduleDryingCheckReminder(
        plant.name,
        checkTime,
        plant.id.hashCode + 1,
      ));
    }

    // Schedule drying complete notification
    if (KultivarApp.notifDryingEnabled.value) {
      unawaited(notifications.scheduleDryingCheckReminder(
        plant.name,
        dryingEndDate,
        plant.id.hashCode + 10,
      ));
    }
  }

  // ── 🫙 Drying → Curing ───────────────────────

  void completeDrying({
    required Plant plant,
    required double dryWeight,
    DateTime? dryingEndDate,
    bool enableBurpingReminders = false,
    String burpingSchedule = 'week1',
    TimeOfDay? burpingTime,
  }) {
    final curingEnd = DateTime.now().add(const Duration(days: 28));

    repo.updatePlant(plant.copyWith(
      status: PlantStatus.curing,
      dryWeight: dryWeight,
      dryingEndDate: dryingEndDate ?? plant.dryingEndDate,
      curingEndDate: curingEnd,
      burpingRemindersEnabled: enableBurpingReminders,
      burpingSchedule: burpingSchedule,
      burpingTime: burpingTime,
    ));
    repo.updateHarvestDryWeight(plant.id, dryWeight);

    if (KultivarApp.notifCuringEnabled.value) {
      unawaited(notifications.scheduleCuringComplete(
        plant.name,
        curingEnd,
        plant.id.hashCode,
      ));
    }

    if (enableBurpingReminders && KultivarApp.notifBurpingEnabled.value) {
      unawaited(notifications.scheduleBurpingReminders(
        plantId: plant.id,
        plantName: plant.name,
        schedule: burpingSchedule,
        preferredTime: burpingTime,
      ));
    }
  }

  // ── ✅ Curing → Completed ────────────────────
// ── Cancel this plant's notifications only ────

  void _cancelPlantNotifications(Plant plant) {
    notifications.cancelNotification(plant.id.hashCode);
    notifications.cancelNotification(plant.id.hashCode + 1);
    notifications.cancelNotification(plant.id.hashCode + 2);
    notifications.cancelNotification(plant.id.hashCode + 3); // week1 2nd daily
    notifications.cancelNotification(plant.id.hashCode + 10);
    // Cancel care-schedule reminders (watering + feeding slots)
    notifications.cancelWateringReminder(plant.id);
    notifications.cancelFeedingReminder(plant.id);
    // Cancel target harvest reminders (7-day and 1-day-before slots)
    notifications.cancelHarvestReminder(plant.id);
  }

  void completeCure(Plant plant) {
    final now = DateTime.now();
    repo.updatePlant(plant.copyWith(
      status: PlantStatus.completed,
      isArchived: true,
      archivedAt: now,
      archiveReason: 'Curing completed successfully',
    ));
    repo.finalizeHarvest(plant.id);
    _cancelPlantNotifications(plant);
  }

  // ── ❌ Cull / Remove ─────────────────────────

  void removePlant({
    required Plant plant,
    required String reason,
  }) {
    repo.updatePlant(plant.copyWith(
      status: PlantStatus.removed,
      isArchived: true,
      archivedAt: DateTime.now(),
      archiveReason: reason,
    ));
    _cancelPlantNotifications(plant);
  }
}
