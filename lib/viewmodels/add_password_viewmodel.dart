// lib/viewmodels/add_password_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/encryption_service.dart';

class AddPasswordViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;
  bool isLoading = false;

  Future<bool> savePassword({
    required String appName,
    required String username,
    required String password,
    bool requiresFace = false,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      // 1. Chèn mật khẩu vào bảng public.passwords
      final String iv = EncryptionService.generateRandomIV();
      final String encryptedPassword = EncryptionService.encryptPassword(password, iv);

      await _client.from('passwords').insert({
        'user_id': user.id,
        'app_name': appName,
        'app_username': username,
        'encrypted_password': encryptedPassword,
        'iv': iv,
        'password_strength': 50,
        'is_favorite': requiresFace,
      });

      // 2. Ghi Log vào public.audit_log
      await _client.from('audit_log').insert({
        'user_id': user.id,
        'action_type': 'ADD_PASSWORD',
        'resource_type': 'password',
        'status': 'success',
        'action_details': {'app': appName}
      });

      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Lỗi lưu mật khẩu: $e");
      isLoading = false;
      notifyListeners();
      return false;
    }
  }
}