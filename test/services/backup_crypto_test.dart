import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivar/services/backup_crypto.dart';

void main() {
  group('BackupCrypto envelope', () {
    test('encrypt → decrypt round-trip recovers the original bytes', () async {
      final plaintext = utf8.encode('hello kultivar backup payload 🌱');
      final envelope =
          await BackupCrypto.encryptBackup(plaintext, 'correct horse');
      expect(BackupCrypto.isEncrypted(envelope), isTrue,
          reason: 'envelope must carry the KVTB magic header');
      final recovered =
          await BackupCrypto.decryptBackup(envelope, 'correct horse');
      expect(recovered, equals(plaintext));
    });

    test('isEncrypted returns false for plain bytes', () {
      // Plain ZIP starts with PK\x03\x04.  We just need anything non-KVTB.
      final plain = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]);
      expect(BackupCrypto.isEncrypted(plain), isFalse);
    });

    test('isEncrypted returns false for too-short input', () {
      expect(BackupCrypto.isEncrypted(<int>[]), isFalse);
      expect(BackupCrypto.isEncrypted([0x4B, 0x56, 0x54]), isFalse);
    });

    test('two encrypts of the same plaintext produce different envelopes',
        () async {
      // Random salt + nonce are regenerated per call, so two encrypts
      // of the same plaintext should never collide.  This matters
      // because users run "Export Backup" repeatedly.
      final plaintext = utf8.encode('static data');
      final a = await BackupCrypto.encryptBackup(plaintext, 'pw');
      final b = await BackupCrypto.encryptBackup(plaintext, 'pw');
      expect(a, isNot(equals(b)));
      // Both must still decrypt correctly.
      expect(await BackupCrypto.decryptBackup(a, 'pw'), equals(plaintext));
      expect(await BackupCrypto.decryptBackup(b, 'pw'), equals(plaintext));
    });

    test('wrong passphrase throws SecretBoxAuthenticationError', () async {
      final envelope =
          await BackupCrypto.encryptBackup(utf8.encode('secret'), 'right');
      await expectLater(
        BackupCrypto.decryptBackup(envelope, 'wrong'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('tampering with ciphertext bytes is detected (AEAD)', () async {
      final envelope = Uint8List.fromList(
          await BackupCrypto.encryptBackup(utf8.encode('payload'), 'pw'));
      // Flip a bit in the ciphertext section (anywhere past the 40-byte
      // header).  GCM should reject on MAC verification.
      envelope[envelope.length - 20] ^= 0x01;
      await expectLater(
        BackupCrypto.decryptBackup(envelope, 'pw'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('non-KVTB envelope throws FormatException', () async {
      final junk = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, ...List.filled(60, 0)]);
      await expectLater(
        BackupCrypto.decryptBackup(junk, 'pw'),
        throwsA(isA<FormatException>()),
      );
    });

    test('empty passphrase is rejected on both encrypt and decrypt', () async {
      expect(
        () => BackupCrypto.encryptBackup(utf8.encode('x'), ''),
        throwsA(isA<ArgumentError>()),
      );
      // For decrypt, the envelope-shape check happens before passphrase
      // check, so we feed it a valid envelope first.
      final env = await BackupCrypto.encryptBackup(utf8.encode('x'), 'pw');
      expect(
        () => BackupCrypto.decryptBackup(env, ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    // ── Q10 backlog — additional edge cases ──────────────────────────

    test('truncated envelope (header-sized but missing MAC) is rejected',
        () async {
      // headerLen = 40, MAC = 16, so an envelope must be ≥ 56 bytes.
      // Build a header-only blob with the right magic but no ciphertext
      // and no MAC.  decryptBackup should refuse with FormatException
      // BEFORE attempting the AEAD decrypt (or anywhere it might emit
      // a less helpful SecretBoxAuthenticationError).
      final headerOnly = Uint8List(40);
      headerOnly[0] = 0x4B; // K
      headerOnly[1] = 0x56; // V
      headerOnly[2] = 0x54; // T
      headerOnly[3] = 0x42; // B
      await expectLater(
        BackupCrypto.decryptBackup(headerOnly, 'pw'),
        throwsA(isA<FormatException>()),
      );
    });

    test('unsupported version byte is rejected with FormatException',
        () async {
      final envelope = Uint8List.fromList(
          await BackupCrypto.encryptBackup(utf8.encode('payload'), 'pw'));
      // Flip the version field (bytes 4..5, little-endian) to a value
      // we don't know how to decode.  This is the migration safety net
      // — future readers that don't recognise our envelope must refuse
      // rather than try and produce garbage.
      envelope[4] = 0xFF;
      envelope[5] = 0xFF;
      await expectLater(
        BackupCrypto.decryptBackup(envelope, 'pw'),
        throwsA(isA<FormatException>()),
      );
    });

    test('unsupported KDF id is rejected with FormatException',
        () async {
      final envelope = Uint8List.fromList(
          await BackupCrypto.encryptBackup(utf8.encode('payload'), 'pw'));
      // Byte 6 = KDF id (1 = PBKDF2-HMAC-SHA256).  Bump it to a value
      // we don't claim to understand.
      envelope[6] = 99;
      await expectLater(
        BackupCrypto.decryptBackup(envelope, 'pw'),
        throwsA(isA<FormatException>()),
      );
    });

    test('unsupported cipher id is rejected with FormatException',
        () async {
      final envelope = Uint8List.fromList(
          await BackupCrypto.encryptBackup(utf8.encode('payload'), 'pw'));
      // Byte 7 = cipher id (1 = AES-256-GCM).
      envelope[7] = 42;
      await expectLater(
        BackupCrypto.decryptBackup(envelope, 'pw'),
        throwsA(isA<FormatException>()),
      );
    });

    test('large payload (256 KB) round-trips correctly', () async {
      // Real backups are tens to hundreds of KB.  Verifying a sizable
      // payload survives the AEAD round-trip catches anything that
      // accidentally chunks / drops bytes at boundaries.
      final big = List<int>.generate(256 * 1024, (i) => i % 256);
      final envelope = await BackupCrypto.encryptBackup(big, 'pw');
      final recovered = await BackupCrypto.decryptBackup(envelope, 'pw');
      expect(recovered.length, big.length);
      expect(recovered, equals(big));
    });

    test('envelope length matches headerLen + plaintext + MAC',
        () async {
      // The envelope's size is a public contract — used by progress
      // estimators that show a backup-encryption spinner.  Lock it in.
      final plaintext = utf8.encode('hello, kultivar.');
      final envelope =
          await BackupCrypto.encryptBackup(plaintext, 'pw');
      expect(envelope.length,
          BackupCrypto.headerLen + plaintext.length + 16,
          reason:
              'header + ciphertext + 16-byte GCM MAC — see envelope-format doc');
    });

    test('isEncrypted accepts a valid envelope', () async {
      final env =
          await BackupCrypto.encryptBackup(utf8.encode('x'), 'pw');
      expect(BackupCrypto.isEncrypted(env), isTrue);
    });
  });
}
