import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/environment_log.dart';
import '../../models/grow_expense.dart';
import '../../models/grow_space.dart';
import '../../models/harvest_log.dart';
import '../../models/note_template.dart';
import '../../models/plant.dart';
import '../../models/plant_note.dart';
import '../../models/strain.dart';
import '../../services/backup_crypto.dart';
import '../../services/backup_encryption_service.dart';
import '../../services/error_reporter.dart';
import '../../services/hive_service.dart';
import '../../services/storage_service.dart';
import '../../services/ui_preferences_service.dart';

/// Q6 — Stateless backup/restore sub-controller composed inside
/// [GrowRepository].
///
/// The two public methods used to live as ~250 LOC of inline logic on
/// the repo.  Splitting them here:
///
///  * Keeps `GrowRepository` focused on in-memory state + collection
///    composition.
///  * Lets the backup logic evolve (cloud mirror, partial restore,
///    new envelope versions) without touching the repo's call sites.
///  * Gives tests a much simpler surface — pass the right lists in,
///    assert on the file system or returned error string out.
///
/// Both methods receive their inputs explicitly rather than reading
/// from a repo instance, so the controller is trivially testable
/// with synthetic data.
abstract final class BackupController {
  BackupController._();

  /// Builds the backup payload + media bundle and routes it to the
  /// system share sheet.  When a passphrase is set in
  /// [BackupEncryptionService] the bytes are wrapped in the F6
  /// AES-256-GCM envelope before sharing.
  ///
  /// On web there is no filesystem, so the JSON-only path is taken
  /// (no images / audio bundled, no ZIP).
  ///
  /// Rethrows after reporting through [ErrorReporter] so the caller
  /// can show its own toast / dialog.
  static Future<void> exportBackup({
    required List<Plant> plants,
    required List<GrowSpace> growSpaces,
    required List<HarvestLog> harvestLogs,
    required List<PlantNote> notes,
    required List<Strain> strains,
    required List<NoteTemplate> noteTemplates,
    required List<GrowExpense> expenses,
  }) async {
    try {
      final payload = await StorageService.buildBackupPayload(
        plants: plants,
        growSpaces: growSpaces,
        harvestLogs: harvestLogs,
        notes: notes,
        strains: strains,
        noteTemplates: noteTemplates,
        environmentLogs: HiveService.allEnvironmentLogs(),
        expenses: expenses,
      );

      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
      final date =
          DateTime.now().toLocal().toString().split(' ')[0].replaceAll('-', '');

      if (kIsWeb) {
        // Web has no filesystem; share JSON only.
        final bytes =
            Uint8List.fromList(const Utf8Encoder().convert(jsonString));
        await Share.shareXFiles(
          [
            XFile.fromData(bytes,
                mimeType: 'application/json',
                name: 'Kultivar_backup_$date.json')
          ],
          subject: 'Kultivar Backup',
        );
        await UiPreferencesService.saveLastBackupTime(DateTime.now());
        return;
      }

      // ── Build ZIP: data/backup.json + images/* + audio/* ──
      final archive = Archive();

      final jsonBytes = const Utf8Encoder().convert(jsonString);
      archive.addFile(
          ArchiveFile('data/backup.json', jsonBytes.length, jsonBytes));

      final dir = await getApplicationDocumentsDirectory();
      const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};
      // F7 — voice-note files live next to the photos in the same
      // Documents directory.  Bundle them under `audio/` inside the
      // backup ZIP so restore can drop them back in place.
      const audioExtensions = {'.m4a', '.aac', '.mp3', '.wav', '.ogg'};
      final addedFilenames = <String>{};
      Future<void> addMediaFile(String nameOrPath, String archiveDir,
          Set<String> allowedExts) async {
        final filename = p.basename(nameOrPath);
        if (addedFilenames.contains(filename)) return;
        final ext = p.extension(filename).toLowerCase();
        if (!allowedExts.contains(ext)) return;
        final mediaFile = File(p.join(dir.path, filename));
        if (!mediaFile.existsSync()) return;
        final bytes = await mediaFile.readAsBytes();
        archive.addFile(
            ArchiveFile('$archiveDir/$filename', bytes.length, bytes));
        addedFilenames.add(filename);
      }

      for (final note in notes) {
        for (final ref in note.photoUrls) {
          await addMediaFile(ref, 'images', imageExtensions);
        }
        for (final ref in note.audioUrls) {
          await addMediaFile(ref, 'audio', audioExtensions);
        }
      }

      // F6 — encryption envelope.  Build a plain ZIP first (no
      // ZipEncoder password), then if the user has set a backup
      // passphrase, wrap the bytes with [BackupCrypto.encryptBackup]
      // which produces a versioned AES-256-GCM envelope.  Filename
      // suffix '_enc' preserved so users can spot encrypted files at
      // a glance in their Files app.
      final plainZip = ZipEncoder().encode(archive);
      final passphrase = await BackupEncryptionService.currentPassphrase();
      final List<int> finalBytes = passphrase == null
          ? plainZip
          : await BackupCrypto.encryptBackup(plainZip, passphrase);

      final suffix = passphrase != null ? '_enc' : '';
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(finalBytes),
            // Encrypted envelope is not a ZIP — use octet-stream so
            // recipients don't try to unzip it with system tooling.
            mimeType: passphrase != null
                ? 'application/octet-stream'
                : 'application/zip',
            name: 'Kultivar_backup_$date$suffix.zip',
          )
        ],
        subject: 'Kultivar Backup',
      );

      await UiPreferencesService.saveLastBackupTime(DateTime.now());
    } catch (e, stack) {
      ErrorReporter.report('BackupController.exportBackup', e, stack);
      rethrow;
    }
  }

  /// Restores from a backup file picked by the user.
  ///
  /// Encrypted ZIPs require a passphrase.  [onRequestPassphrase] is
  /// invoked when one is needed — typically wired to a dialog in the
  /// UI layer.  The callback is retried with the user's input when
  /// the supplied passphrase doesn't decrypt successfully, up to
  /// [maxPassphraseAttempts].  Returning `null` from the callback
  /// cancels the import.
  ///
  /// [reload] is called after the payload has been restored to disk
  /// — it triggers [GrowRepository.load] which repopulates every
  /// in-memory collection from the freshly-written backing store.
  ///
  /// Returns:
  ///   * `null` on success.
  ///   * A non-null error string on failure (suitable for showing
  ///     directly to the user).
  static Future<String?> importBackup({
    Future<String?> Function()? onRequestPassphrase,
    int maxPassphraseAttempts = 3,
    required Future<void> Function() reload,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final pickedFile = result.files.first;
      final bytes = pickedFile.bytes;
      if (bytes == null) return 'Could not read the selected file.';

      Map<String, dynamic> payload;
      final List<ArchiveFile> imageFiles = [];

      final name = pickedFile.name.toLowerCase();
      final bool looksKvtb = BackupCrypto.isEncrypted(bytes);

      if (looksKvtb || name.endsWith('.zip') || name.endsWith('.kvbk')) {
        // ── ZIP backup (plain, KVTB-encrypted, or legacy ZIP-encrypted) ──
        //
        // Resolution order:
        //   1. If bytes start with the KVTB magic → BackupCrypto.decrypt
        //      → plain inner ZIP.
        //   2. Else try to open as a plain ZIP.
        //   3. Else fall back to legacy `ZipDecoder(password:)` for ZIPs
        //      produced before the F6 envelope was introduced.
        Archive? archive;
        ArchiveFile? jsonEntry;

        String? attemptedPassphrase =
            await BackupEncryptionService.currentPassphrase();
        int attempts = 0;

        while (true) {
          try {
            List<int> zipBytes = bytes;

            if (looksKvtb) {
              if (attemptedPassphrase == null) {
                // Need a passphrase before we can even start.
                if (onRequestPassphrase == null) {
                  return 'This backup is encrypted. Enter the passphrase '
                      'used when it was created.';
                }
                attempts++;
                if (attempts > maxPassphraseAttempts) {
                  return 'Too many incorrect passphrase attempts.';
                }
                attemptedPassphrase = await onRequestPassphrase();
                if (attemptedPassphrase == null) return null;
              }
              zipBytes =
                  await BackupCrypto.decryptBackup(bytes, attemptedPassphrase);
              // Reset password attempt so the inner ZIP decode below
              // doesn't pass a stale legacy password into ZipDecoder.
              archive = ZipDecoder().decodeBytes(zipBytes);
            } else {
              // Try plain decode first; if it fails AND the user has a
              // stored passphrase, attempt legacy ZIP-password decode.
              try {
                archive = ZipDecoder().decodeBytes(zipBytes);
              } catch (_) {
                archive = ZipDecoder()
                    .decodeBytes(zipBytes, password: attemptedPassphrase);
              }
            }

            jsonEntry = null;
            imageFiles.clear();
            for (final entry in archive) {
              if (!entry.isFile) continue;
              if (entry.name == 'data/backup.json') {
                jsonEntry = entry;
              } else if ((entry.name.startsWith('images/') &&
                      entry.name.length > 'images/'.length) ||
                  // F7 — bundled voice notes restore alongside images.
                  // The restore step below writes both back to the
                  // Documents directory with their bare filenames.
                  (entry.name.startsWith('audio/') &&
                      entry.name.length > 'audio/'.length)) {
                imageFiles.add(entry);
              }
            }
            if (jsonEntry == null) {
              return 'Invalid backup: missing data/backup.json inside ZIP.';
            }
            // Force-read the JSON content here so encryption errors
            // surface synchronously inside this try-block.  Without
            // this the read would happen below and would short-circuit
            // the retry loop.
            final jsonString = utf8.decode(jsonEntry.content as List<int>);
            payload = jsonDecode(jsonString) as Map<String, dynamic>;
            break;
          } catch (e) {
            // SecretBoxAuthenticationError (KVTB wrong passphrase) and
            // ArchiveException / FormatException (legacy wrong password)
            // both land here.  Re-prompt up to [maxPassphraseAttempts].
            if (onRequestPassphrase == null ||
                attempts >= maxPassphraseAttempts) {
              return attemptedPassphrase == null
                  ? 'This backup is encrypted. Enable backup encryption '
                      'in Settings or use the passphrase originally set.'
                  : 'Could not decrypt backup — incorrect passphrase '
                      'after $attempts attempts.';
            }
            attempts++;
            attemptedPassphrase = await onRequestPassphrase();
            if (attemptedPassphrase == null) return null; // user cancelled
          }
        }
      } else {
        // ── Legacy JSON backup ──────────────────────
        final jsonString = utf8.decode(bytes);
        payload = jsonDecode(jsonString) as Map<String, dynamic>;
      }

      final version = payload['version'] as int? ?? 0;
      if (version < 1) return 'Unrecognised backup format.';

      await StorageService.restoreFromPayload(payload);

      final rawLogs = payload['environmentLogs'] as List<dynamic>? ?? [];
      final envLogs = rawLogs
          .map((e) => EnvironmentLog.fromJson(e as Map<String, dynamic>))
          .toList();

      await HiveService.clearAllLogs();
      if (envLogs.isNotEmpty) {
        await HiveService.addEnvironmentLogs(envLogs);
      }

      // ── Restore photos + voice notes (native only) ────────────
      if (!kIsWeb && imageFiles.isNotEmpty) {
        final dir = await getApplicationDocumentsDirectory();
        for (final imgEntry in imageFiles) {
          final filename = p.basename(imgEntry.name);
          if (filename.isEmpty) continue;
          final dest = File(p.join(dir.path, filename));
          await dest.writeAsBytes(imgEntry.content as List<int>);
        }
      }

      await reload();
      return null; // null = success
    } catch (e, stack) {
      ErrorReporter.report('BackupController.importBackup', e, stack);
      return 'Failed to restore backup: $e';
    }
  }
}
