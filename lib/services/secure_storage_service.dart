// lib/services/secure_storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _keyPasskey = 'user_passkey';
  static const _keySavedEmail = 'saved_email';
  static const _keySavedPassword = 'saved_password';
  static const _keyFaceEncoding = 'face_encoding';
  
  static const _keyUsePasskeyLogin = 'use_passkey_login';
  static const _keyUseFaceLogin = 'use_face_login';

  // --- Login Preferences ---
  static Future<void> setUsePasskeyLogin(bool val) async => await _storage.write(key: _keyUsePasskeyLogin, value: val.toString());
  static Future<bool> getUsePasskeyLogin() async => (await _storage.read(key: _keyUsePasskeyLogin)) != 'false';

  static Future<void> setUseFaceLogin(bool val) async => await _storage.write(key: _keyUseFaceLogin, value: val.toString());
  static Future<bool> getUseFaceLogin() async => (await _storage.read(key: _keyUseFaceLogin)) != 'false';

  // --- Passkey Management ---
  static Future<void> savePasskey(String pin) async {
    await _storage.write(key: _keyPasskey, value: pin);
  }

  static Future<String?> getPasskey() async {
    return await _storage.read(key: _keyPasskey);
  }

  static Future<void> clearPasskey() async {
    await _storage.delete(key: _keyPasskey);
  }

  // --- Session Account Management ---
  static Future<void> saveAccountCredentials(String email, String password) async {
    await _storage.write(key: _keySavedEmail, value: email);
    await _storage.write(key: _keySavedPassword, value: password);
  }

  static Future<Map<String, String?>> getAccountCredentials() async {
    final email = await _storage.read(key: _keySavedEmail);
    final password = await _storage.read(key: _keySavedPassword);
    return {'email': email, 'password': password};
  }

  static Future<void> clearAccountCredentials() async {
    await _storage.delete(key: _keySavedEmail);
    await _storage.delete(key: _keySavedPassword);
    await _storage.delete(key: _keyFaceEncoding);
  }

  // --- Face Encoding Management ---
  static Future<void> saveFaceEncoding(String encodingJson) async {
    await _storage.write(key: _keyFaceEncoding, value: encodingJson);
  }

  static Future<String?> getFaceEncoding() async {
    final val = await _storage.read(key: _keyFaceEncoding);
    if (val == '') return null;
    return val;
  }

  static Future<void> clearFaceEncoding() async {
    await _storage.write(key: _keyFaceEncoding, value: '');
    await _storage.delete(key: _keyFaceEncoding);
  }
}
