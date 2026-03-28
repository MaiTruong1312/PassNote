// lib/views/face_setup_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components/realtime_camera_scanner.dart';
import '../services/face_api_service.dart';
import '../services/secure_storage_service.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../utils/app_theme.dart';
import '../utils/password_prompt.dart';

class FaceSetupPage extends StatefulWidget {
  const FaceSetupPage({super.key});

  @override
  State<FaceSetupPage> createState() => _FaceSetupPageState();
}

class _FaceSetupPageState extends State<FaceSetupPage> {
  File? _image;
  List<double>? _extractedVector;
  bool _isLoading = false;
  String? _statusMessage;
  bool _hasExisting = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final face = await SecureStorageService.getFaceEncoding();
    if (mounted) {
      setState(() {
        _hasExisting = face != null;
        _isChecking = false;
      });
    }
  }

  Future<void> _saveFace(BuildContext context) async {
    if (_extractedVector == null) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = "Saving face to secure vault...";
    });

    final viewModel = Provider.of<DashboardViewModel>(context, listen: false);
    bool success = await viewModel.updateFaceEncoding(_extractedVector!);
    
    setState(() {
      _isLoading = false;
      _statusMessage = success ? "FACE REGISTERED SUCCESSFULLY!" : "FAILED TO SAVE FACE.";
      if (success) {
        _extractedVector = null; // Cất nút lưu đi sau khi thành công
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_hasExisting) {
      return Scaffold(
        appBar: AppBar(title: const Text("SETUP FACE RECOGNITION"), centerTitle: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              const Text("FACE AUTHENTICATION ACTIVE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Your face is currently registered to secure this vault.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                   if (await PasswordPrompt.verify(context)) {
                      setState(() => _hasExisting = false);
                   }
                },
                child: const Text("TẠO LẠI KHUÔN MẶT MỚI / CHANGE FACE"),
              ),
              const SizedBox(height: 15),
              TextButton.icon(
                onPressed: () async {
                   if (await PasswordPrompt.verify(context)) {
                      final viewModel = Provider.of<DashboardViewModel>(context, listen: false);
                      bool success = await viewModel.deleteFaceEncoding();
                      if (success && mounted) {
                         setState(() {
                            _hasExisting = false;
                            _extractedVector = null;
                            _image = null;
                         });
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Face data deleted successfully.")));
                      }
                   }
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text("XÓA DỮ LIỆU KHUÔN MẶT", style: TextStyle(color: Colors.red)),
              )
            ]
          )
        )
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("SETUP FACE RECOGNITION"), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.face_retouching_natural, size: 80, color: AppTheme.primaryBlack),
              const SizedBox(height: 30),
              const Text("FACE AUTHENTICATION", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 15),
              const Text("Enhance your security by registering your face for quick access to the vault.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              
              if (_extractedVector == null)
                RealtimeCameraScanner(
                  promptText: "ĐANG QUÉT KHUÔN MẶT...",
                  onFaceDetected: (vector) {
                     setState(() {
                       _extractedVector = vector;
                       _statusMessage = "FACE DETECTED! READY TO SAVE.";
                     });
                  },
                ),

              if (_isLoading) const CircularProgressIndicator(color: AppTheme.primaryBlack),
              
              if (_statusMessage != null && !_isLoading) ...[
                const SizedBox(height: 20),
                Text(_statusMessage!, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _statusMessage!.contains("SUCCESS") ? Colors.green : Colors.red,
                  )
                ),
              ],
              
              const SizedBox(height: 40),
              
              if (_extractedVector != null && !_isLoading) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _saveFace(context),
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text("LƯU KHUÔN MẶT (SAVE FACE)"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() {
                      _extractedVector = null;
                      _statusMessage = null;
                    }),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text("SCAN AGAIN"),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
