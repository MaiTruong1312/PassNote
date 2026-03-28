// lib/viewmodels/dashboard_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../services/secure_storage_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;
  int currentIndex = 0;
  List<Map<String, dynamic>> passwords = [];
  bool isLoadingPasswords = true;

  DashboardViewModel() {
    loadPasswords();
  }

  // Chuyển tab
  void setTabIndex(int index) {
    currentIndex = index;
    notifyListeners();
  }

  // Lấy danh sách mật khẩu (Trang chủ)
  Future<void> loadPasswords() async {
    isLoadingPasswords = true;
    notifyListeners();
    try {
        final response = await _client.from('passwords').select().order('app_name');
        passwords = List<Map<String, dynamic>>.from(response);
    } catch (e) {
        debugPrint("Lỗi tải mật khẩu: $e");
    }
    isLoadingPasswords = false;
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

  // Xóa mật khẩu
  Future<bool> deletePassword(String id) async {
    try {
      await _client.from('passwords').delete().eq('id', id);
      
      // Log audit
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client.from('audit_log').insert({
          'user_id': user.id,
          'action_type': 'DELETE_PASSWORD',
          'resource_type': 'password',
          'status': 'success',
          'action_details': {'password_id': id}
        });
      }
      await loadPasswords(); // Tự động load lại trang
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
          'model_name': 'Facenet',
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
        debugPrint("CRITICAL Lỗi update users: \$e");
      }

      try {
        await _client.from('face_templates').delete().eq('user_id', user.id);
      } catch (e) {}

      await SecureStorageService.clearFaceEncoding();
      return true;
    } catch (e) {
      debugPrint("Lỗi xóa khuôn mặt: $e");
      return false;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}