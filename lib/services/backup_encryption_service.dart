import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the user-chosen backup passphrase.
///
/// ## Threat model
///
/// Backup ZIPs are auto-written to the app's Documents folder, which iOS
/// exposes through the Files app (and optionally iCloud Drive) and Android
/// includes in Google Auto Backup.  Without encryption, anyone with file
/// access can read every note, photo and harvest record.
///
/// With encryption enabled:
///   • The ZIP itself is AES-256 encrypted (WinZip AE-2 spec) via the
///     `archive` package's password support.  Without the passphrase the
///     file contents are unrecoverable.
///   • The passphrase is stored in the platform keychain
///     (iOS Keychain / Android Keystore-backed encrypted prefs) so the
///     background auto-backup task can use it without user prompts.
///   • The keychain entry only unlocks after the device is unlocked
///     (`first_unlock` on iOS by default), so a powered-off / locked
///     stolen device cannot leak the passphrase.
///
/// **Limits**: A determined attacker with full device access while the
/// device is unlocked CAN extract the passphrase from the keychain.
/// This service raises the bar significantly — it does not provide
/// nation-state-level secrecy.  Users who need that should rotate keys
/// to a passphrase they only enter manually (we don't support that
/// flow yet, but the storage is decoupled enough that it'd be a small
/// addition).
class BackupEncryptionService {
  // Wrapped so tests / mocks can substitute the storage backend.
  static FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Inject a different storage backend (used by tests).
  @visibleForTesting
  static set storage(FlutterSecureStorage value) => _storage = value;

  static const _kPassphraseKey = 'backup_passphrase';

  /// Returns the current passphrase, or null when encryption is disabled.
  ///
  /// Reading is cheap (keychain access) but should be cached by callers
  /// when used in hot paths (none today).
  static Future<String?> currentPassphrase() async {
    if (kIsWeb) return null; // secure storage unavailable on web
    try {
      return await _storage.read(key: _kPassphraseKey);
    } catch (_) {
      // Reading can fail on first-launch race conditions or after the user
      // restores from a backup without the keychain coming over.  Treat as
      // "no passphrase set" rather than crashing.
      return null;
    }
  }

  /// True when a passphrase is currently stored — used by the Settings UI
  /// to render the encryption toggle and by export paths to know whether
  /// to encrypt.
  static Future<bool> isEnabled() async =>
      (await currentPassphrase())?.isNotEmpty ?? false;

  /// Persists [passphrase] in the platform keychain.  Replaces any
  /// existing value.  Empty input is rejected.
  static Future<void> setPassphrase(String passphrase) async {
    if (kIsWeb) return;
    final trimmed = passphrase.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Passphrase cannot be empty.');
    }
    await _storage.write(key: _kPassphraseKey, value: trimmed);
  }

  /// Removes the stored passphrase.  Future backups will be unencrypted.
  /// Existing encrypted backups remain usable as long as the user
  /// remembers the passphrase or re-enters it on restore.
  static Future<void> forgetPassphrase() async {
    if (kIsWeb) return;
    await _storage.delete(key: _kPassphraseKey);
  }
}
