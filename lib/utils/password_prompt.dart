// lib/utils/password_prompt.dart
import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';

class PasswordPrompt {
  static Future<bool> verify(BuildContext context) async {
    bool isVerified = false;
    final creds = await SecureStorageService.getAccountCredentials();
    final actualPassword = creds['password'];
    
    // Nếu không có mật khẩu lưu cục bộ, bỏ qua xác thực 
    if (actualPassword == null) return true; 

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final controller = TextEditingController();
        String? error;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("XÁC THỰC BẢO MẬT"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Vui lòng nhập mật khẩu đăng nhập để thay đổi cài đặt này."),
                  const SizedBox(height: 15),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: "Mật khẩu",
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("HỦY BỎ", style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    if (controller.text == actualPassword) {
                      isVerified = true;
                      Navigator.pop(ctx);
                    } else {
                      setDialogState(() => error = "Mật khẩu không đúng");
                    }
                  },
                  child: const Text("XÁC NHẬN"),
                ),
              ],
            );
          }
        );
      }
    );
    
    return isVerified;
  }
}
