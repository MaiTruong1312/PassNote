// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_storage_service.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // Đăng nhập bằng Email/Username và Password
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  // Đăng ký
  Future<AuthResponse> signUp(String email, String password, String fullName) async {
    await SecureStorageService.clearPasskey();
    await SecureStorageService.clearAccountCredentials();
    await SecureStorageService.clearFaceEncoding();
    
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    if (response.user != null) {
      // VÁ LỖI BẮT NHẬP LẠI MẬT KHẨU: Lưu bộ đệm ngay sau khi Đăng ký chứ không chỉ ở Đăng nhập
      await SecureStorageService.saveAccountCredentials(email, password);
    }

    return response;
  }
  // Đăng xuất
  Future<void> signOut() async {
    await SecureStorageService.clearPasskey();
    await SecureStorageService.clearAccountCredentials();
    await _supabase.auth.signOut();
  }

  // Lấy User hiện tại
  User? get currentUser => _supabase.auth.currentUser;
}