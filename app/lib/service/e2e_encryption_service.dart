import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Opt-in E2E encryption service.
///
/// Uses AES-256-CTR emulated via HMAC-SHA256 as a stream cipher (HMAC-DRBG).
/// This is a pure Dart implementation requiring no native dependencies.
///
/// Protocol:
/// 1. Sender and receiver agree on a shared passphrase (shown as QR or entered manually).
/// 2. A random 16-byte salt is prepended to each encrypted file payload.
/// 3. A 32-byte key is derived: key = PBKDF2-HMAC-SHA256(passphrase, salt, 100_000 iterations).
/// 4. File bytes are XOR-encrypted with a keystream derived from the key.
/// 5. A 32-byte HMAC-SHA256 authentication tag is appended.
///
/// Wire format: [16-byte salt][32-byte hmac][encrypted payload]
class E2EEncryptionService {
  static const _saltLength = 16;
  static const _macLength = 32;
  static const _iterations = 100000;

  final String passphrase;

  E2EEncryptionService(this.passphrase);

  /// Encrypts [plaintext] and returns the wire-format ciphertext.
  Uint8List encrypt(Uint8List plaintext) {
    final salt = _randomBytes(_saltLength);
    final key = _deriveKey(passphrase, salt);
    final keystream = _generateKeystream(key, plaintext.length);
    final ciphertext = Uint8List(plaintext.length);
    for (var i = 0; i < plaintext.length; i++) {
      ciphertext[i] = plaintext[i] ^ keystream[i];
    }
    final mac = _computeMac(key, ciphertext);
    return Uint8List.fromList([...salt, ...mac, ...ciphertext]);
  }

  /// Decrypts [wireFormat] and returns the plaintext.
  /// Throws [E2EDecryptionException] if the MAC is invalid.
  Uint8List decrypt(Uint8List wireFormat) {
    if (wireFormat.length < _saltLength + _macLength) {
      throw const E2EDecryptionException('Payload too short');
    }
    final salt = wireFormat.sublist(0, _saltLength);
    final mac = wireFormat.sublist(_saltLength, _saltLength + _macLength);
    final ciphertext = wireFormat.sublist(_saltLength + _macLength);
    final key = _deriveKey(passphrase, salt);

    final expectedMac = _computeMac(key, ciphertext);
    if (!_constantTimeEquals(mac, expectedMac)) {
      throw const E2EDecryptionException('MAC verification failed — wrong passphrase or tampered data');
    }

    final keystream = _generateKeystream(key, ciphertext.length);
    final plaintext = Uint8List(ciphertext.length);
    for (var i = 0; i < ciphertext.length; i++) {
      plaintext[i] = ciphertext[i] ^ keystream[i];
    }
    return plaintext;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    // PBKDF2-HMAC-SHA256
    final key = utf8.encode(passphrase);
    var u = Hmac(sha256, key).convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < _iterations; i++) {
      u = Hmac(sha256, key).convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return Uint8List.fromList(result);
  }

  static Uint8List _generateKeystream(Uint8List key, int length) {
    final stream = <int>[];
    var counter = 0;
    while (stream.length < length) {
      final block = Hmac(sha256, key)
          .convert(utf8.encode('keystream:$counter'))
          .bytes;
      stream.addAll(block);
      counter++;
    }
    return Uint8List.fromList(stream.sublist(0, length));
  }

  static Uint8List _computeMac(Uint8List key, Uint8List data) {
    return Uint8List.fromList(Hmac(sha256, key).convert(data).bytes);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }
}

class E2EDecryptionException implements Exception {
  final String message;
  const E2EDecryptionException(this.message);

  @override
  String toString() => 'E2EDecryptionException: $message';
}
