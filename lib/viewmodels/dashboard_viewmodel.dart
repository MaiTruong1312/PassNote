// lib/viewmodels/dashboard_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../services/secure_storage_service.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../models/password_model.dart';

class DashboardViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;
  int currentIndex = 0;
  List<Password> passwords = [];
  bool isLoadingPasswords = true;
  final _localDb = LocalDatabaseService();
  final _syncService = SyncService();

  DashboardViewModel() {
    loadPasswords();
  }

  // Chuyển tab
  void setTabIndex(int index) {
    currentIndex = index;
    notifyListeners();
  }

  // Lấy danh sách mật khẩu (Ưu tiên Local First)
  Future<void> loadPasswords() async {
    isLoadingPasswords = true;
    notifyListeners();
    
    // 1. Load từ Local DB ngay lập tức
    passwords = await _localDb.getAllPasswords();
    isLoadingPasswords = false;
    notifyListeners();

    // 2. Kích hoạt Sync ngầm từ Cloud
    syncWithCloud();
  }

  // Đồng bộ hóa với Cloud
  Future<void> syncWithCloud() async {
    await _syncService.pullFromSupabase();
    passwords = await _localDb.getAllPasswords();
    notifyListeners();
  }

  // Lấy lịch sử hoạt động (Trang Lịch sử)
  Future<List<Map<String, dynamic>>> fetchAuditLogs() async {
    final response = await _client
        .from('audit_log')
        .select()
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(response);
  }

  // Xóa mật khẩu (Local first)
  Future<bool> deletePassword(String? supabaseId, int localId) async {
    try {
      // 1. Xóa Local trước
      await _localDb.deleteByLocalId(localId);
      passwords.removeWhere((p) => p.localId == localId);
      notifyListeners();

      // 2. Xóa trên Cloud (ngầm)
      if (supabaseId != null) {
        _syncService.deleteFromSupabase(supabaseId);
        
        // Log audit
        final user = _client.auth.currentUser;
        if (user != null) {
          _client.from('audit_log').insert({
            'user_id': user.id,
            'action_type': 'DELETE_PASSWORD',
            'resource_type': 'password',
            'status': 'success',
            'action_details': {'password_id': supabaseId}
          }).then((_) => null);
        }
      }
      return true;
    } catch (e) {
      debugPrint("Lỗi xóa mật khẩu: $e");
      return false;
    }
  }

  // Cập nhật khuôn mặt
  Future<bool> updateFaceEncoding(List<double> encoding) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      
      // 1. Cố gắng cập nhật vào bảng users
      try {
        await _client.from('users').update({
          'face_encoding': encoding
        }).eq('id', user.id);
      } catch (e) {
        debugPrint("Cảnh báo cập nhật bảng users: $e");
      }

      // 2. Lưu log / template vào bảng face_templates theo đúng Schema bạn cung cấp
      try {
        await _client.from('face_templates').insert({
          'user_id': user.id,
          'template_data': encoding,
          'template_type': 'primary',
          'angle_type': 'straight', 
          'model_name': 'ArcFace',
          'embedding_dimension': encoding.length,
        });
      } catch (e) {
        debugPrint("Cảnh báo lưu face_templates: $e");
        // Đôi khi người dùng chưa tạo bảng hoặc xài RLS nên cứ tiếp tục
      }

      // 3. Quan trọng nhất: Phải lưu vào bộ nhớ nội bộ để màn hình Đăng nhập (Login Page) lấy ra so sánh!
      await SecureStorageService.saveFaceEncoding(jsonEncode(encoding));
      
      return true;
    } catch (e) {
      debugPrint("Lỗi cập nhật khuôn mặt: $e");
      return false;
    }
  }

  // Cập nhật bộ mỏ neo đa góc độ (Multi-view Anchors)
  Future<bool> updateMultiViewFace(Map<String, List<double>> vectors) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      // 1. Xóa bộ mỏ neo cũ (nếu có) để làm sạch
      await _client.from('face_templates').delete().eq('user_id', user.id);

      // 2. Chèn bộ mỏ neo mới
      final List<Map<String, dynamic>> inserts = vectors.entries.map((entry) {
        return {
          'user_id': user.id,
          'template_data': entry.value,
          'template_type': entry.key == 'straight' ? 'primary' : 'alternative',
          'angle_type': entry.key,
          'model_name': 'ArcFace',
          'embedding_dimension': entry.value.length,
        };
      }).toList();

      await _client.from('face_templates').insert(inserts);

      // 3. Đồng bộ hóa mỏ neo xuống Local Cache
      await SecureStorageService.saveMultiViewAnchors(jsonEncode(vectors));
      
      return true;
    } catch (e) {
      debugPrint("Lỗi cập nhật đa góc độ: $e");
      return false;
    }
  }

  // Xóa khuôn mặt
  Future<bool> deleteFaceEncoding() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      
      try {
        await _client.from('users').update({
          'face_encoding': [] // 🌟 Bản vá lỗi: Gửi mảng rỗng thay vì null để Supabase không vứt bỏ params 
        }).eq('id', user.id);
      } catch (e) {
        debugPrint("CRITICAL Lỗi update users: $e");
      }

      try {
        await _client.from('face_templates').delete().eq('user_id', user.id);
      } catch (e) {}

      // Xóa các bản mẫu khuôn mặt động (Dynamic Templates) trên Cloud để tránh nhiễm độc
      try {
        await _client.from('face_dynamic_templates').delete().eq('user_id', user.id);
        debugPrint("Cleared face_dynamic_templates from Cloud.");
      } catch (e) {
        debugPrint("Lỗi xóa face_dynamic_templates: $e");
      }

      await SecureStorageService.clearFaceEncoding();
      return true;
    } catch (e) {
      debugPrint("Lỗi xóa khuôn mặt: $e");
      return false;
    }
  }

  Future<bool> isFaceOnCloud() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      
      final response = await _client
          .from('users')
          .select('face_encoding')
          .eq('id', user.id)
          .maybeSingle();
          
      if (response != null && response['face_encoding'] != null) {
        final list = response['face_encoding'] as List;
        return list.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint("Lỗi kiểm tra cloud face: $e");
      return false;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}