import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  static const String _defaultPassphrase = 'BT_CHAT_SECURE_KEY_2024';
  late enc.Key _key;
  late enc.IV _iv;
  late enc.Encrypter _encrypter;

  EncryptionService({String? passphrase}) {
    _initKeys(passphrase ?? _defaultPassphrase);
  }

  void _initKeys(String passphrase) {
    // Derive a 32-byte key from the passphrase using SHA-256
    final keyBytes = sha256.convert(utf8.encode(passphrase)).bytes;
    _key = enc.Key(Uint8List.fromList(keyBytes));

    // Use first 16 bytes of MD5 hash as IV
    final ivBytes = md5.convert(utf8.encode(passphrase)).bytes;
    _iv = enc.IV(Uint8List.fromList(ivBytes));

    _encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
  }

  /// Encrypt plaintext → base64 ciphertext
  String encrypt(String plaintext) {
    try {
      final encrypted = _encrypter.encrypt(plaintext, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      throw EncryptionException('Encryption failed: $e');
    }
  }

  /// Decrypt base64 ciphertext → plaintext
  String decrypt(String ciphertext) {
    try {
      final encrypted = enc.Encrypted.fromBase64(ciphertext);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      throw EncryptionException('Decryption failed: $e');
    }
  }

  /// Change the shared passphrase (must match on both devices)
  void updatePassphrase(String newPassphrase) {
    _initKeys(newPassphrase);
  }

  /// Generate a secure random passphrase
  static String generatePassphrase() {
    final random = enc.SecureRandom(32);
    return base64Url.encode(random.bytes).substring(0, 20);
  }

  /// Hash a passphrase for display/comparison (first 8 chars)
  static String hashPreview(String passphrase) {
    final hash = sha256.convert(utf8.encode(passphrase)).toString();
    return hash.substring(0, 8).toUpperCase();
  }
}

class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);

  @override
  String toString() => message;
}
