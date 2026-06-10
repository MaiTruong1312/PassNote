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
  static const _keyUseFingerprintLogin = 'use_fingerprint_login';
  static const _keyFaceThreshold = 'face_threshold';
  static const _keyCameraRotation = 'camera_rotation';
  static const _keyFaceScanInterval = 'face_scan_interval';
  static const _keyFaceScanCount = 'face_scan_count';
  static const _keyDynamicTemplates = 'dynamic_face_templates';
  static const _keyMultiViewAnchors = 'multi_view_face_anchors';

  // --- Login Preferences ---
  static Future<void> setUsePasskeyLogin(bool val) async => await _storage.write(key: _keyUsePasskeyLogin, value: val.toString());
  static Future<bool> getUsePasskeyLogin() async => (await _storage.read(key: _keyUsePasskeyLogin)) != 'false';

  static Future<void> setUseFaceLogin(bool val) async => await _storage.write(key: _keyUseFaceLogin, value: val.toString());
  static Future<bool> getUseFaceLogin() async => (await _storage.read(key: _keyUseFaceLogin)) != 'false';

  static Future<void> setUseFingerprintLogin(bool val) async => await _storage.write(key: _keyUseFingerprintLogin, value: val.toString());
  static Future<bool> getUseFingerprintLogin() async => (await _storage.read(key: _keyUseFingerprintLogin)) == 'true';

  static Future<void> setFaceThreshold(double val) async => await _storage.write(key: _keyFaceThreshold, value: val.toString());
  static Future<double> getFaceThreshold() async {
    final val = await _storage.read(key: _keyFaceThreshold);
    if (val == null) return 0.65; 
    return double.tryParse(val) ?? 0.65;
  }

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
    await _storage.delete(key: _keyDynamicTemplates);
    await _storage.delete(key: _keyMultiViewAnchors); // Vá lỗi: Xóa bộ mỏ neo đa góc độ local
  }

  // --- Dynamic Templates Management ---
  static Future<void> saveDynamicTemplates(String json) async {
    await _storage.write(key: _keyDynamicTemplates, value: json);
  }

  static Future<String?> getDynamicTemplates() async {
    return await _storage.read(key: _keyDynamicTemplates);
  }

  // --- Multi-view Anchors Management ---
  static Future<void> saveMultiViewAnchors(String json) async {
    await _storage.write(key: _keyMultiViewAnchors, value: json);
  }

  static Future<String?> getMultiViewAnchors() async {
    return await _storage.read(key: _keyMultiViewAnchors);
  }
}
