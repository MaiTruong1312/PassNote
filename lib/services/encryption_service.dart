// lib/services/encryption_service.dart
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'dart:math';

class EncryptionService {
  // Tạm thời dùng một Key cố định 32 ký tự (256-bit)
  static final _key = encrypt.Key.fromUtf8('my_super_secret_key_32_chars_123');

  // Hàm tạo IV ngẫu nhiên 16 ký tự
  static String generateRandomIV() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values).substring(0, 16);
  }

  // Hàm mã hóa
  static String encryptPassword(String plainText, String ivString) {
    final iv = encrypt.IV.fromUtf8(ivString);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  // Hàm giải mã
  static String decryptPassword(String encryptedBase64, String ivString) {
    final iv = encrypt.IV.fromUtf8(ivString);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    return encrypter.decrypt64(encryptedBase64, iv: iv);
  }
}