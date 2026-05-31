import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/environment_log.dart';
import '../models/grow_expense.dart';
import '../models/grow_space.dart';
import '../models/harvest_log.dart';
import '../models/note_template.dart';
import '../models/plant.dart';
import '../models/plant_note.dart';
import '../models/strain.dart';
import 'error_reporter.dart';

class StorageService {
  static const _keyPlants = 'plants';
  static const _keyGrowSpaces = 'grow_spaces';
  static const _keyHarvestLogs = 'harvest_logs';
  static const _keyNotes = 'plant_notes';
  static const _keyStrains = 'strains';
  static const _keyNoteTemplates = 'note_templates';
  static const _keyStreak = 'streak_data';
  static const _keyExpenses = 'grow_expenses';

  // ── Save ─────────────────────────────────────

  static Future<void> savePlants(List<Plant> plants) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyPlants, jsonEncode(plants.map((p) => p.toJson()).toList()));
  }

  static Future<void> saveGrowSpaces(List<GrowSpace> spaces) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyGrowSpaces, jsonEncode(spaces.map((s) => s.toJson()).toList()));
  }

  static Future<void> saveHarvestLogs(List<HarvestLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyHarvestLogs, jsonEncode(logs.map((l) => l.toJson()).toList()));
  }

  static Future<void> saveNotes(List<PlantNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyNotes, jsonEncode(notes.map((n) => n.toJson()).toList()));
  }

  static Future<void> saveStrains(List<Strain> strains) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyStrains, jsonEncode(strains.map((s) => s.toJson()).toList()));
  }

  static Future<void> saveNoteTemplates(List<NoteTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNoteTemplates,
        jsonEncode(templates.map((t) => t.toJson()).toList()));
  }

  static Future<void> saveExpenses(List<GrowExpense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyExpenses, jsonEncode(expenses.map((e) => e.toJson()).toList()));
  }

  static Future<void> saveStreakData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStreak, jsonEncode(data));
  }

  static Future<void> saveAll({
    required List<Plant> plants,
    required List<GrowSpace> growSpaces,
    required List<HarvestLog> harvestLogs,
    required List<PlantNote> notes,
    required List<Strain> strains,
    required List<NoteTemplate> noteTemplates,
  }) async {
    try {
      await Future.wait([
        savePlants(plants),
        saveGrowSpaces(growSpaces),
        saveHarvestLogs(harvestLogs),
        saveNotes(notes),
        saveStrains(strains),
        saveNoteTemplates(noteTemplates),
      ]);
    } catch (e, stack) {
      ErrorReporter.report('StorageService.saveAll', e, stack);
    }
  }

  // ── Load ─────────────────────────────────────

  static Future<List<Plant>> loadPlants() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPlants);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Plant.fromJson(e)).toList();
    } catch (e, stack) {
      ErrorReporter.report('StorageService.loadPlants', e, stack);
      return [];
    }
  }

  static Future<List<GrowSpace>> loadGrowSpaces() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyGrowSpaces);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => GrowSpace.fromJson(e))
          .toList();
    } catch (e, stack) {
      ErrorReporter.report('StorageService.loadGrowSpaces', e, stack);
      return [];
    }
  }

  static Future<List<HarvestLog>> loadHarvestLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyHarvestLogs);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => HarvestLog.fromJson(e))
          .toList();
    } catch (e, stack) {
      ErrorReporter.report('StorageService.loadHarvestLogs', e, stack);
      return [];
    }
  }

  static Future<List<PlantNote>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyNotes);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => PlantNote.fromJson(e))
          .toList();
    } catch (e, stack) {
      ErrorReporter.report('StorageService.loadNotes', e, stack);
      return [];
    }
  }

  static Future<List<Strain>> loadStrains() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyStrains);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Strain.fromJson(e))
          .toList();
    } catch (e, stack) {
      ErrorReporter.report('StorageService.loadStrains', e, stack);
      return [];
    }
  }

  static Future<List<NoteTemplate>> loadNoteTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyNoteTemplates);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => NoteTemplate.fromJson(e))
          .toList();
    } catch (e, stack) {
      ErrorReporter.report('StorageService.loadNoteTemplates', e, stack);
      return [];
    }
  }

  static Future<List<GrowExpense>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyExpenses);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => GrowExpense.fromJson(e))
          .toList();
    } catch (e, stack) {
      ErrorReporter.report('StorageService.loadExpenses', e, stack);
      return [];
    }
  }

  static Future<List<EnvironmentLog>> loadLegacyEnvironmentLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('environment_logs');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => EnvironmentLog.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

// ── Backup ───────────────────────────────────

  static Future<Map<String, dynamic>> buildBackupPayload({
    required List<Plant> plants,
    required List<GrowSpace> growSpaces,
    required List<HarvestLog> harvestLogs,
    required List<PlantNote> notes,
    required List<Strain> strains,
    required List<NoteTemplate> noteTemplates,
    required List<EnvironmentLog> environmentLogs,
    List<GrowExpense> expenses = const [],
  }) async {
    final streak = await loadStreakData();
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'plants': plants.map((p) => p.toJson()).toList(),
      'growSpaces': growSpaces.map((s) => s.toJson()).toList(),
      'harvestLogs': harvestLogs.map((l) => l.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'strains': strains.map((s) => s.toJson()).toList(),
      'noteTemplates': noteTemplates.map((t) => t.toJson()).toList(),
      'environmentLogs': environmentLogs.map((l) => l.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'streak': streak,
    };
  }

  static Future<void> restoreFromPayload(Map<String, dynamic> payload) async {
    final plants = (payload['plants'] as List<dynamic>? ?? [])
        .map((e) => Plant.fromJson(e as Map<String, dynamic>))
        .toList();
    final growSpaces = (payload['growSpaces'] as List<dynamic>? ?? [])
        .map((e) => GrowSpace.fromJson(e as Map<String, dynamic>))
        .toList();
    final harvestLogs = (payload['harvestLogs'] as List<dynamic>? ?? [])
        .map((e) => HarvestLog.fromJson(e as Map<String, dynamic>))
        .toList();
    final notes = (payload['notes'] as List<dynamic>? ?? [])
        .map((e) => PlantNote.fromJson(e as Map<String, dynamic>))
        .toList();
    final strains = (payload['strains'] as List<dynamic>? ?? [])
        .map((e) => Strain.fromJson(e as Map<String, dynamic>))
        .toList();
    final noteTemplates = (payload['noteTemplates'] as List<dynamic>? ?? [])
        .map((e) => NoteTemplate.fromJson(e as Map<String, dynamic>))
        .toList();

    final expenses = (payload['expenses'] as List<dynamic>? ?? [])
        .map((e) => GrowExpense.fromJson(e as Map<String, dynamic>))
        .toList();

    await Future.wait([
      saveAll(
        plants: plants,
        growSpaces: growSpaces,
        harvestLogs: harvestLogs,
        notes: notes,
        strains: strains,
        noteTemplates: noteTemplates,
      ),
      saveExpenses(expenses),
    ]);

    if (payload['streak'] is Map<String, dynamic>) {
      await saveStreakData(payload['streak'] as Map<String, dynamic>);
    }
  }

  static Future<void> clearLegacyEnvironmentLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('environment_logs');
  }

  static Future<Map<String, dynamic>> loadStreakData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyStreak);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<Map<String, dynamic>> loadAll() async {
    final results = await Future.wait([
      loadPlants(),
      loadGrowSpaces(),
      loadHarvestLogs(),
      loadNotes(),
      loadStrains(),
      loadNoteTemplates(),
      loadExpenses(),
    ]);
    return {
      'plants': results[0] as List<Plant>,
      'growSpaces': results[1] as List<GrowSpace>,
      'harvestLogs': results[2] as List<HarvestLog>,
      'notes': results[3] as List<PlantNote>,
      'strains': results[4] as List<Strain>,
      'noteTemplates': results[5] as List<NoteTemplate>,
      'expenses': results[6] as List<GrowExpense>,
    };
  }
}
