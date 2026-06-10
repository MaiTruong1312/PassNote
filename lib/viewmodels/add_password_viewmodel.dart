// lib/viewmodels/add_password_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/encryption_service.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../models/password_model.dart';

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

      final String iv = EncryptionService.generateRandomIV();
      final String encryptedPassword = EncryptionService.encryptPassword(password, iv);

      // 1. Lưu Local trước (Isar)
      final newPassword = Password()
        ..appName = appName
        ..appUsername = username
        ..encryptedPassword = encryptedPassword
        ..iv = iv
        ..isFavorite = requiresFace
        ..createdAt = DateTime.now()
        ..isSynced = false;

      await LocalDatabaseService().savePassword(newPassword);

      // 2. Đồng bộ lên Supabase ngầm
      SyncService().pushToSupabase(newPassword).then((success) {
        if (success) {
           // Log Audit ngầm
           _client.from('audit_log').insert({
              'user_id': user.id,
              'action_type': 'ADD_PASSWORD',
              'resource_type': 'password',
              'status': 'success',
              'action_details': {'app': appName}
           }).then((_) => null);
        }
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