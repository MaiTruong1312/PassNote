// lib/viewmodels/login_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';
import '../services/face_api_service.dart';

// lib/viewmodels/login_viewmodel.dart
class LoginViewModel extends ChangeNotifier {
  final _authService = AuthService();
  final _client = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final savedCreds = await SecureStorageService.getAccountCredentials();
      final savedEmail = savedCreds['email'];

      await _authService.signIn(email, password);
      if (savedEmail != null && savedEmail.trim().toLowerCase() != email.trim().toLowerCase()) {
        await SecureStorageService.clearPasskey();
        await SecureStorageService.clearAccountCredentials();
      }

      await SecureStorageService.saveAccountCredentials(email, password);
      
      // Fetch face encoding after login
      final user = _client.auth.currentUser;
      if (user != null) {
        final userData = await _client.from('users').select('face_encoding').eq('id', user.id).maybeSingle();
        if (userData != null && userData['face_encoding'] != null) {
          final dynamic faceData = userData['face_encoding'];
          if (faceData is List && faceData.isNotEmpty) {
            await SecureStorageService.saveFaceEncoding(jsonEncode(faceData));
          }
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = "Đăng nhập thất bại: Kiểm tra lại tài khoản/mật khẩu";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithPasskey(String pin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final savedPin = await SecureStorageService.getPasskey();
      if (savedPin == pin) {
        final creds = await SecureStorageService.getAccountCredentials();
        final email = creds['email'];
        final password = creds['password'];
        if (email != null && password != null) {
          await _authService.signIn(email, password);
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      _error = "Invalid PIN or session expired.";
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = "Login failed: Please try again later.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithFace(File faceImage) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final savedStr = await SecureStorageService.getFaceEncoding();
      final creds = await SecureStorageService.getAccountCredentials();
      final email = creds['email'];
      final password = creds['password'];

      if (savedStr != null && email != null && password != null) {
        final List<double> savedEncoding = List<double>.from(jsonDecode(savedStr));
        
        final vector = await FaceApiService.extractFace(faceImage);
        if (vector != null) {
           double distance = FaceApiService.calculateCosineDistance(vector, savedEncoding);
           debugPrint("Face distance: $distance");
           if (distance < 0.40) {
              await _authService.signIn(email, password);
              _isLoading = false;
              notifyListeners();
              return true;
           } else {
             _error = "Khôn mặt không khớp.";
           }
        } else {
          _error = "Không nhận diện được khuôn mặt.";
        }
      } else {
        _error = "Vui lòng đăng nhập bằng mật khẩu để kích hoạt sinh trắc học.";
      }
    } catch (e) {
      _error = "Lỗi xác thực: ${e.toString()}";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> loginWithFaceVector(List<double> vector) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final savedStr = await SecureStorageService.getFaceEncoding();
      final creds = await SecureStorageService.getAccountCredentials();
      final email = creds['email'];
      final password = creds['password'];

      if (savedStr != null && email != null && password != null) {
        final List<double> savedEncoding = List<double>.from(jsonDecode(savedStr));
        
        double distance = FaceApiService.calculateCosineDistance(vector, savedEncoding);
        debugPrint("Face distance: \$distance");
        if (distance < 0.40) {
           await _authService.signIn(email, password);
           _isLoading = false;
           notifyListeners();
           return true;
        } else {
           _error = "Khuôn mặt không khớp.";
        }
      } else {
        _error = "Vui lòng đăng nhập bằng mật khẩu để kích hoạt sinh trắc học.";
      }
    } catch (e) {
      _error = "Lỗi xác thực: \${e.toString()}";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}