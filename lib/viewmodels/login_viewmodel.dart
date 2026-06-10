// lib/viewmodels/login_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';

import '../services/face_inference_service.dart';
import '../services/biometric_service.dart';

// lib/viewmodels/login_viewmodel.dart
class LoginViewModel extends ChangeNotifier {
  final _authService = AuthService();
  final _client = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;
  double? _lastMatchDistance;
  String? _lastMatchSource;
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  double? get lastMatchDistance => _lastMatchDistance;
  String? get lastMatchSource => _lastMatchSource;

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
        // 1. Fetch Primary Encoding
        final userData = await _client.from('users').select('face_encoding').eq('id', user.id).maybeSingle();
        if (userData != null && userData['face_encoding'] != null) {
          final dynamic faceData = userData['face_encoding'];
          if (faceData is List && faceData.isNotEmpty) {
            await SecureStorageService.saveFaceEncoding(jsonEncode(faceData));
          }
        }

        // 2. Fetch Multi-view Anchors
        final multiViewData = await _client
            .from('face_templates')
            .select('angle_type, template_data')
            .eq('user_id', user.id);
        
        if (multiViewData != null) {
          Map<String, List<double>> anchors = {};
          for (var item in (multiViewData as List)) {
            anchors[item['angle_type']] = List<double>.from(item['template_data']);
          }
          await SecureStorageService.saveMultiViewAnchors(jsonEncode(anchors));
        }

        // 3. Fetch Dynamic Templates (Last 5)
        final dynamicData = await _client
            .from('face_dynamic_templates')
            .select('encoding')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(5);
        
        if (dynamicData != null) {
           List<List<double>> templates = (dynamicData as List).map((item) {
             return List<double>.from(item['encoding']);
           }).toList();
           await SecureStorageService.saveDynamicTemplates(jsonEncode(templates));
        }

        // 4. Fetch User Settings (Threshold & other options)
        try {
          final settingsData = await _client
              .from('user_settings')
              .select('settings')
              .eq('user_id', user.id)
              .maybeSingle();
          if (settingsData != null && settingsData['settings'] != null) {
            final settings = settingsData['settings'] as Map<String, dynamic>;
            final faceRec = settings['face_recognition'] as Map<String, dynamic>?;
            if (faceRec != null && faceRec['threshold'] != null) {
              final threshold = (faceRec['threshold'] as num).toDouble();
              await SecureStorageService.setFaceThreshold(threshold);
              debugPrint("Synced dynamic face threshold from DB: $threshold");
            }
          }
        } catch (e) {
          debugPrint("Failed to fetch user settings: $e");
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
        
        final vector = await FaceInferenceService().extractEmbedding(faceImage);
        if (vector != null) {
           double distance = FaceInferenceService.calculateCosineDistance(vector, savedEncoding);
           debugPrint("Face distance (Local API): $distance");
           
           final threshold = await SecureStorageService.getFaceThreshold();
           if (distance < threshold) { 
              await _authService.signIn(email, password);
              _isLoading = false;
              notifyListeners();
              return true;
           } else {
             _error = "Không khớp khuôn mặt (Dist: ${distance.toStringAsFixed(3)}).";
           }
        } else {
          _error = "Server nhận diện không phản hồi.";
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

  Future<bool> loginWithBiometrics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final creds = await SecureStorageService.getAccountCredentials();
      final email = creds['email'];
      final password = creds['password'];

      if (email != null && password != null) {
        final success = await BiometricService.authenticate();
        if (success) {
          await _authService.signIn(email, password);
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _error = "Hệ thống hủy hoặc từ chối sinh trắc học.";
        }
      } else {
        _error = "Vui lòng đăng nhập mật khẩu trước để kích hoạt vân tay.";
      }
    } catch (e) {
      _error = "Lỗi vân tay: ${e.toString()}";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// CẬP NHẬT TEMPLATE ĐỘNG (FIFO + Drift Prevention)
  Future<void> _updateDynamicTemplate(List<double> newVector, List<double> primaryEncoding, String angleType) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. CHỐNG TRÔI DẠT (Drift Prevention): 
      // Chỉ "học" nếu khuôn mặt mới cực kỳ giống ảnh gốc (Drift Prevention)
      double distToPrimary = FaceInferenceService.calculateCosineDistance(newVector, primaryEncoding);
      if (distToPrimary > FaceInferenceService.driftThreshold) {
        debugPrint("Dynamic Update Ignored: Face drift detected (Dist: $distToPrimary > ${FaceInferenceService.driftThreshold})");
        return; 
      }

      // 2. INSERT VECTOR MỚI
      await _client.from('face_dynamic_templates').insert({
        'user_id': user.id,
        'encoding': newVector,
        'angle_type': angleType, // Lưu lại góc độ AI vừa nhận diện được
      });

      // 3. CHIẾN THUẬT FIFO: Kiểm tra và xóa bản ghi cũ nhất nếu vượt quá 5
      final allTemplates = await _client
          .from('face_dynamic_templates')
          .select('id')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (allTemplates != null && (allTemplates as List).length > 5) {
        List<dynamic> list = allTemplates;
        // Lấy danh sách các ID cần xóa (từ vị trí thứ 6 trở đi)
        List<String> idsToDelete = list.sublist(5).map((item) => item['id'].toString()).toList();
        
        await _client
            .from('face_dynamic_templates')
            .delete()
            .inFilter('id', idsToDelete);
        
        debugPrint("FIFO Cleanup: Deleted ${idsToDelete.length} old templates.");
      }

      // 4. CẬP NHẬT LẠI CACHE CỤC BỘ
      final dynamicData = await _client
          .from('face_dynamic_templates')
          .select('encoding')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(5);
      
      if (dynamicData != null) {
         List<List<double>> templates = (dynamicData as List).map((item) {
           return List<double>.from(item['encoding']);
         }).toList();
         await SecureStorageService.saveDynamicTemplates(jsonEncode(templates));
      }
    } catch (e) {
      debugPrint("Dynamic Template Update Error: $e");
    }
  }

  Future<bool> loginWithFaceVector(List<double> vector) async {
    _isLoading = true;
    _error = null;
    _lastMatchDistance = null;
    _lastMatchSource = null;
    notifyListeners();

    try {
      final savedStr = await SecureStorageService.getFaceEncoding();
      final creds = await SecureStorageService.getAccountCredentials();
      final email = creds['email'];
      final password = creds['password'];

      if (savedStr != null && email != null && password != null) {
        String? userId;
        try {
          final res = await _client.from('users').select('id').eq('email', email).maybeSingle();
          if (res != null) {
            userId = res['id'] as String?;
          }
        } catch (e) {
          debugPrint("Failed to fetch userId for history logging: $e");
        }

        final List<double> primaryEncoding = List<double>.from(jsonDecode(savedStr));
        
        // CHỈ SO KHỚP VỚI BẢN MẪU THẲNG GỐC (PRIMARY STRAIGHT) ĐỂ ĐẢM BẢO BẢO MẬT TUYỆT ĐỐI
        double minDistance = FaceInferenceService.calculateCosineDistance(vector, primaryEncoding);
        String bestMatchSource = "PRIMARY (STRAIGHT)";
        debugPrint("--- FACE MATCH AUDIT ---");
        debugPrint("Match with Primary: $minDistance");

        _lastMatchDistance = minDistance;
        _lastMatchSource = bestMatchSource;
        debugPrint("FINAL BEST MATCH: $bestMatchSource (Dist: $minDistance)");
        debugPrint("------------------------");
        
        notifyListeners(); // Thông báo để UI cập nhật thông số real-time
        
        final threshold = await SecureStorageService.getFaceThreshold(); // Sử dụng threshold động từ settings
        if (minDistance < threshold) { 
          await _authService.signIn(email, password);
          
          // Ghi nhận lịch sử đăng nhập thành công
          if (userId != null) {
            _client.from('login_history').insert({
              'user_id': userId,
              'login_method': 'face',
              'login_status': 'success',
              'face_match_score': minDistance,
            }).then((_) => null).catchError((e) => debugPrint("Failed to save login history: $e"));

            // Cập nhật thống kê sử dụng mỏ neo ngầm
            _updateTemplateStats(userId, bestMatchSource, minDistance);
          }

          _isLoading = false;
          notifyListeners();
          return true;
        } else {
           _error = "Không khớp khuôn mặt (Min Dist: ${minDistance.toStringAsFixed(3)}).";
           
           // Ghi nhận lịch sử đăng nhập thất bại
           if (userId != null) {
             _client.from('login_history').insert({
               'user_id': userId,
               'login_method': 'face',
               'login_status': 'failed',
               'face_match_score': minDistance,
               'failure_reason': 'Face mismatch. Min dist: ${minDistance.toStringAsFixed(3)}',
             }).then((_) => null).catchError((e) => debugPrint("Failed to save login history: $e"));
           }
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

  /// Cập nhật thống kê hiệu suất sử dụng mỏ neo (face_templates) ngầm
  Future<void> _updateTemplateStats(String userId, String bestMatchSource, double distance) async {
    if (!bestMatchSource.startsWith("ANCHOR") && !bestMatchSource.startsWith("PRIMARY")) return;

    String angleType = "straight";
    if (bestMatchSource.contains("(")) {
      angleType = bestMatchSource.split("(")[1].replaceAll(")", "").toLowerCase();
    }

    try {
      final data = await _client
          .from('face_templates')
          .select('match_count, avg_match_score')
          .eq('user_id', userId)
          .eq('angle_type', angleType)
          .maybeSingle();

      if (data != null) {
        int count = (data['match_count'] ?? 0) + 1;
        double currentScore = 1.0 - distance; // Cosine Similarity
        double avgScore = (data['avg_match_score'] ?? 0.0).toDouble();
        avgScore = (avgScore * (count - 1) + currentScore) / count;

        await _client.from('face_templates').update({
          'match_count': count,
          'last_match_time': DateTime.now().toIso8601String(),
          'avg_match_score': avgScore,
        }).eq('user_id', userId).eq('angle_type', angleType);

        debugPrint("Updated template stats for $angleType: count=$count, avgScore=${avgScore.toStringAsFixed(3)}");
      }
    } catch (e) {
      debugPrint("Failed to update template stats: $e");
    }
  }
}