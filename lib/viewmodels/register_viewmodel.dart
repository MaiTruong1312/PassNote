// lib/viewmodels/register_viewmodel.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterViewModel extends ChangeNotifier {
  final _authService = AuthService();
  bool isLoading = false;
  String? errorMessage;

  Future<bool> register(String email, String password, String fullName) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authService.signUp(email, password, fullName);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = "Lỗi: Email đã tồn tại hoặc không hợp lệ.";
      isLoading = false;
      notifyListeners();
      return false;
    }
  }
}