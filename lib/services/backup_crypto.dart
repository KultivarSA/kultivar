import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// F6 — Backup encryption envelope.
///
/// Wraps a backup ZIP's bytes (or any plaintext) in a versioned,
/// authenticated envelope using AES-256-GCM with a PBKDF2-derived key.
///
/// ## Envelope format (binary, little-endian where multibyte)
///
/// ```text
/// Offset  Bytes  Field
/// ------  -----  -----------------------------------------------
///   0      4     Magic 'KVTB'  ('K','V','T','B' = 0x4B 0x56 0x54 0x42)
///   4      2     Version  (uint16 LE, currently = 1)
///   6      1     KDF id   (uint8, 1 = PBKDF2-HMAC-SHA256)
///   7      1     Cipher id (uint8, 1 = AES-256-GCM)
///   8      4     PBKDF2 iterations (uint32 LE)
///  12     16     Salt
///  28     12     AES-GCM nonce
///  40     ..     Ciphertext  (length = plaintext length)
///   ..    16     GCM authentication tag
/// ```
///
/// Header length = 40 bytes.  Output length = 40 + plaintext.length + 16.
///
/// ## Why this layer (vs ZIP password)
///
/// The `archive` package's `ZipEncoder(password:)` uses the ZIP
/// specification's AES extension whose security properties vary across
/// implementations.  This envelope is platform-agnostic, uses a single
/// well-vetted AEAD primitive, and detects tampering on decrypt — the
/// MAC verification step raises [SecretBoxAuthenticationError] on bit
/// flips or wrong passphrase, so the caller never gets partially
/// decrypted gibberish.
///
/// ## Migration from existing encrypted backups
///
/// Older backups produced by `ZipEncoder(password:)` are still
/// importable — the restore flow first tries `BackupCrypto.isEncrypted`
/// on the picked file's bytes, decrypts via this layer if so, and
/// otherwise falls back to the legacy `ZipDecoder().decodeBytes(...,
/// password: ...)` path.
class BackupCrypto {
  BackupCrypto._();

  // ── Envelope constants ─────────────────────────
  static const List<int> _magic = [0x4B, 0x56, 0x54, 0x42]; // 'KVTB'
  static const int _version = 1;
  static const int _kdfPbkdf2HmacSha256 = 1;
  static const int _cipherAesGcm256 = 1;

  /// PBKDF2 iteration count.  200k is the OWASP 2023 minimum for SHA-256
  /// and stays well under a second on modern phones.  Stored in the
  /// envelope so future bumps don't break decryption of older backups.
  static const int _defaultIterations = 200000;

  static const int _saltLen = 16;
  static const int _nonceLen = 12;
  static const int _macLen = 16;
  static const int headerLen =
      4 /*magic*/ + 2 /*ver*/ + 1 /*kdf*/ + 1 /*cipher*/ +
      4 /*iters*/ + _saltLen + _nonceLen;

  // ── Public API ─────────────────────────────────

  /// Returns true if [bytes] starts with the KVTB magic header.
  ///
  /// Constant-time vs. an attacker-controlled file: the file picker is
  /// the only input source, so timing is irrelevant here — a normal
  /// `==` comparison is fine.
  static bool isEncrypted(List<int> bytes) {
    if (bytes.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  /// Encrypt [plaintext] with [passphrase] and return the envelope bytes.
  ///
  /// Random salt + nonce are freshly generated on every call so two
  /// identical backups encrypt to different ciphertexts — important
  /// because users often run "Export Backup" repeatedly.
  static Future<Uint8List> encryptBackup(
    List<int> plaintext,
    String passphrase,
  ) async {
    if (passphrase.isEmpty) {
      throw ArgumentError('passphrase must not be empty');
    }

    final rng = Random.secure();
    final salt = _randomBytes(rng, _saltLen);
    final nonce = _randomBytes(rng, _nonceLen);

    final key = await _deriveKey(passphrase, salt, _defaultIterations);

    final algo = AesGcm.with256bits();
    final box = await algo.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
    );

    // Build the envelope: header + ciphertext + 16-byte MAC.
    final out = BytesBuilder(copy: false);
    out.add(_magic);
    out.add(_u16le(_version));
    out.addByte(_kdfPbkdf2HmacSha256);
    out.addByte(_cipherAesGcm256);
    out.add(_u32le(_defaultIterations));
    out.add(salt);
    out.add(nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.toBytes();
  }

  /// Decrypt an envelope produced by [encryptBackup].
  ///
  /// Throws:
  ///  * [FormatException] when the magic / version / algorithm IDs
  ///    don't match (corrupt or non-KVTB file).
  ///  * [SecretBoxAuthenticationError] when the passphrase is wrong or
  ///    the ciphertext has been tampered with.
  static Future<Uint8List> decryptBackup(
    List<int> envelope,
    String passphrase,
  ) async {
    if (passphrase.isEmpty) {
      throw ArgumentError('passphrase must not be empty');
    }
    if (envelope.length < headerLen + _macLen) {
      throw const FormatException('Envelope too short to be a KVTB backup.');
    }
    if (!isEncrypted(envelope)) {
      throw const FormatException('Missing KVTB magic header.');
    }

    final bytes = envelope is Uint8List
        ? envelope
        : Uint8List.fromList(envelope);

    final version = _readU16le(bytes, 4);
    if (version != _version) {
      throw FormatException(
          'Unsupported KVTB backup version: $version (expected $_version).');
    }
    final kdfId = bytes[6];
    final cipherId = bytes[7];
    if (kdfId != _kdfPbkdf2HmacSha256) {
      throw FormatException('Unsupported KDF id: $kdfId.');
    }
    if (cipherId != _cipherAesGcm256) {
      throw FormatException('Unsupported cipher id: $cipherId.');
    }
    final iterations = _readU32le(bytes, 8);
    final salt = bytes.sublist(12, 12 + _saltLen);
    const nonceStart = 12 + _saltLen;
    final nonce = bytes.sublist(nonceStart, nonceStart + _nonceLen);

    const cipherStart = nonceStart + _nonceLen;
    final macStart = bytes.length - _macLen;
    if (macStart < cipherStart) {
      throw const FormatException('Truncated KVTB envelope.');
    }
    final cipherText = bytes.sublist(cipherStart, macStart);
    final macBytes = bytes.sublist(macStart);

    final key = await _deriveKey(passphrase, salt, iterations);
    final algo = AesGcm.with256bits();
    final clear = await algo.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: key,
    );
    return Uint8List.fromList(clear);
  }

  // ── Internals ──────────────────────────────────

  static Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt,
    int iterations,
  ) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return kdf.deriveKey(
      secretKey: SecretKey(passphrase.codeUnits),
      nonce: salt,
    );
  }

  static Uint8List _randomBytes(Random rng, int n) {
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = rng.nextInt(256);
    }
    return out;
  }

  static List<int> _u16le(int v) => [v & 0xFF, (v >> 8) & 0xFF];

  static List<int> _u32le(int v) => [
        v & 0xFF,
        (v >> 8) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 24) & 0xFF,
      ];

  static int _readU16le(Uint8List b, int off) =>
      b[off] | (b[off + 1] << 8);

  static int _readU32le(Uint8List b, int off) =>
      b[off] |
      (b[off + 1] << 8) |
      (b[off + 2] << 16) |
      (b[off + 3] << 24);
}
