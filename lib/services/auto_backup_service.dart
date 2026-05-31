import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../repository/grow_repository.dart';
import '../services/backup_crypto.dart';
import '../services/backup_encryption_service.dart';
import '../services/error_reporter.dart';
import '../services/hive_service.dart';
import '../services/storage_service.dart';
import '../services/ui_preferences_service.dart';

/// Result returned by [AutoBackupService.maybeAutoBackup].
enum AutoBackupResult {
  /// Backup was skipped — last backup is still fresh or platform is web.
  skipped,

  /// A new backup ZIP was written successfully.
  success,

  /// Backup attempted but failed; original error is printed to the console.
  failed,
}

/// Writes automatic backup ZIPs to the app's Documents directory.
///
/// ## How it works
/// 1. On every app resume, [maybeAutoBackup] checks whether the last backup
///    (manual or automatic) is older than [staleThresholdDays].
/// 2. If stale, a full backup ZIP is written to
///    `<Documents>/Kultivar Backups/Kultivar_backup_<date>.zip`.
/// 3. The three most recent backups are kept; older files are pruned.
/// 4. [UiPreferencesService.saveLastBackupTime] is updated on success.
///
/// ## Platform accessibility
/// - **iOS**: with `UIFileSharingEnabled` in Info.plist, the Kultivar Backups
///   folder appears in the Files app under "On My iPhone/iPad → Kultivar".
///   If the user has enabled "iCloud Drive → Kultivar" in Settings → iCloud,
///   files also sync across all their Apple devices automatically.
/// - **Android**: files are written to internal app storage which is included
///   in Google's Auto Backup (configured in backup_rules.xml).
class AutoBackupService {
  AutoBackupService._();

  /// How many auto-backup ZIPs to keep before pruning the oldest.
  static const int _keepCount = 3;

  /// Number of days after which a backup is considered stale and a new
  /// automatic backup will be triggered on app resume.
  static const int staleThresholdDays = 7;

  /// Returns the `Kultivar Backups` directory inside the app's Documents
  /// folder, creating it if it doesn't exist.
  static Future<Directory> backupDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'Kultivar Backups'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Checks whether an automatic backup is due and, if so, writes one.
  ///
  /// Silent by design — callers should check [AutoBackupResult] and surface
  /// feedback at their discretion (e.g. a passive toast on success).
  static Future<AutoBackupResult> maybeAutoBackup(
      GrowRepository repo) async {
    if (kIsWeb) return AutoBackupResult.skipped;

    // Only run if data has actually been loaded.
    if (repo.growSpaces.isEmpty && repo.plants.isEmpty) {
      return AutoBackupResult.skipped;
    }

    final lastBackup = await UiPreferencesService.loadLastBackupTime();
    if (lastBackup != null) {
      final daysSince = DateTime.now().difference(lastBackup).inDays;
      if (daysSince < staleThresholdDays) return AutoBackupResult.skipped;
    }

    try {
      await _writeBackup(repo);
      await UiPreferencesService.saveLastBackupTime(DateTime.now());
      return AutoBackupResult.success;
    } catch (e, stack) {
      ErrorReporter.report('AutoBackupService.maybeAutoBackup', e, stack);
      return AutoBackupResult.failed;
    }
  }

  // ── Internal ──────────────────────────────────

  static Future<void> _writeBackup(GrowRepository repo) async {
    // Build JSON payload — same source of truth as manual export.
    final payload = await StorageService.buildBackupPayload(
      plants: repo.plants,
      growSpaces: repo.growSpaces,
      harvestLogs: repo.harvestLogs,
      notes: repo.notes,
      strains: repo.strains,
      noteTemplates: repo.noteTemplates,
      environmentLogs: HiveService.allEnvironmentLogs(),
    );
    final jsonString =
        const JsonEncoder.withIndent('  ').convert(payload);

    // Build ZIP archive.
    final archive = Archive();

    final jsonBytes = const Utf8Encoder().convert(jsonString);
    archive.addFile(
        ArchiveFile('data/backup.json', jsonBytes.length, jsonBytes));

    // Bundle photos + F7 voice notes.  Same Documents directory, same
    // archive structure as `GrowRepository.exportBackup`.
    final docs = await getApplicationDocumentsDirectory();
    const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};
    const audioExtensions = {'.m4a', '.aac', '.mp3', '.wav', '.ogg'};
    final addedFilenames = <String>{};
    Future<void> addMediaFile(String nameOrPath, String archiveDir,
        Set<String> allowedExts) async {
      final filename = p.basename(nameOrPath);
      if (addedFilenames.contains(filename)) return;
      final ext = p.extension(filename).toLowerCase();
      if (!allowedExts.contains(ext)) return;
      final mediaFile = File(p.join(docs.path, filename));
      if (!mediaFile.existsSync()) return;
      final bytes = await mediaFile.readAsBytes();
      archive.addFile(
          ArchiveFile('$archiveDir/$filename', bytes.length, bytes));
      addedFilenames.add(filename);
    }

    for (final note in repo.notes) {
      for (final ref in note.photoUrls) {
        await addMediaFile(ref, 'images', imageExtensions);
      }
      for (final ref in note.audioUrls) {
        await addMediaFile(ref, 'audio', audioExtensions);
      }
    }

    // When the user has set a backup passphrase, the ZIP is AES-256
    // encrypted at the archive package level.  Without it, contents would
    // be readable by anyone with file-system access (iCloud Drive, Google
    // Auto Backup, etc.).
    // F6 — encryption envelope.  Build a plain ZIP, then wrap with
    // BackupCrypto.encryptBackup when the user has set a passphrase.
    // See lib/services/backup_crypto.dart for the envelope format.
    final plainZip = ZipEncoder().encode(archive);
    final passphrase = await BackupEncryptionService.currentPassphrase();
    final List<int> finalBytes = passphrase == null
        ? plainZip
        : await BackupCrypto.encryptBackup(plainZip, passphrase);

    // Write to Kultivar Backups folder.  Encrypted backups get a distinct
    // suffix so users (and the import flow) can see at a glance which
    // files require a passphrase.
    final date = DateTime.now()
        .toLocal()
        .toString()
        .split(' ')[0]
        .replaceAll('-', '');
    final dir = await backupDirectory();
    final suffix = passphrase != null ? '_enc' : '';
    final destFile =
        File(p.join(dir.path, 'Kultivar_backup_$date$suffix.zip'));
    await destFile.writeAsBytes(finalBytes, flush: true);

    // Prune old backups, keeping the [_keepCount] most recent.
    await _pruneOldBackups(dir);
  }

  static Future<void> _pruneOldBackups(Directory dir) async {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList()
      ..sort((a, b) => b
          .statSync()
          .modified
          .compareTo(a.statSync().modified)); // newest first

    for (int i = _keepCount; i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (e, stack) {
        ErrorReporter.report('AutoBackupService.prune', e, stack,
            {'path': files[i].path});
      }
    }
  }
}
