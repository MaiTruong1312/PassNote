// lib/views/face_setup_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components/realtime_camera_scanner.dart';

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
  bool _isLoading = false;
  String? _statusMessage;
  bool _hasExisting = false;
  bool _existsOnCloud = false;
  bool _isChecking = true;

  // Multi-view state
  final Map<String, List<double>> _capturedAngles = {};
  final List<String> _angleSteps = ['straight', 'tilt_left', 'tilt_right', 'tilt_up', 'tilt_down'];
  int _currentStepIndex = 0;
  final Map<String, String> _stepInstructions = {
    'straight': 'NHÌN THẲNG VÀO CAMERA',
    'tilt_left': 'NGHIÊNG MẶT SANG TRÁI',
    'tilt_right': 'NGHIÊNG MẶT SANG PHẢI',
    'tilt_up': 'NGƯỚC MẶT LÊN TRÊN',
    'tilt_down': 'CÚI MẶT XUỐNG DƯỚI',
  };

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final localFace = await SecureStorageService.getFaceEncoding();
    final viewModel = Provider.of<DashboardViewModel>(context, listen: false);
    final cloudFace = await viewModel.isFaceOnCloud();
    
    if (mounted) {
      setState(() {
        _hasExisting = localFace != null;
        _existsOnCloud = cloudFace;
        _isChecking = false;
      });
    }
  }

  Future<void> _saveMultiViewFace(BuildContext context) async {
    if (_capturedAngles.length < 5) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = "Đang lưu bộ mỏ neo đa góc độ...";
    });

    final viewModel = Provider.of<DashboardViewModel>(context, listen: false);
    // Lưu vector chính (straight) vào bảng users
    bool successPrimary = await viewModel.updateFaceEncoding(_capturedAngles['straight']!);
    
    // Lưu toàn bộ 5 vector vào bảng face_templates (Multi-view Anchors)
    bool successMulti = await viewModel.updateMultiViewFace(_capturedAngles);
    
    setState(() {
      _isLoading = false;
      if (successPrimary && successMulti) {
        _hasExisting = true;
        _existsOnCloud = true;
        _statusMessage = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("XÁC THỰC ĐA GÓC ĐỘ ĐÃ KÍCH HOẠT!"), behavior: SnackBarBehavior.floating),
        );
      } else {
        _statusMessage = "LỖI KHI LƯU DỮ LIỆU ĐA GÓC.";
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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _existsOnCloud ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _existsOnCloud ? Colors.green : Colors.orange, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _existsOnCloud ? Icons.cloud_done : Icons.cloud_off, 
                      size: 14, 
                      color: _existsOnCloud ? Colors.green : Colors.orange
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _existsOnCloud ? "SYNCED WITH CLOUD" : "LOCAL ONLY (NOT SYNCED)", 
                      style: TextStyle(
                        fontSize: 9, 
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 1,
                        color: _existsOnCloud ? Colors.green : Colors.orange
                      )
                    ),
                  ],
                ),
              ),
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
                             _capturedAngles.clear();
                             _currentStepIndex = 0;
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_capturedAngles.length < 5) ...[
                Text(_stepInstructions[_angleSteps[_currentStepIndex]] ?? "", 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 5),
                Text("Tiến độ: ${_capturedAngles.length + 1}/5 góc độ", 
                  style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // Thanh tiến trình mini
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _angleSteps.map((step) {
                    bool isCaptured = _capturedAngles.containsKey(step);
                    bool isCurrent = _angleSteps[_currentStepIndex] == step;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isCurrent ? 20 : 10,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isCaptured ? Colors.green : (isCurrent ? Colors.black : Colors.black12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const Icon(Icons.face_retouching_natural, size: 60, color: AppTheme.primaryBlack),
                const SizedBox(height: 20),
                const Text("HOÀN TẤT QUÉT ĐA GÓC", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
              
              if (_capturedAngles.length < 5)
                Container(
                  height: MediaQuery.of(context).size.height * 0.65,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RealtimeCameraScanner(
                    key: ValueKey(_angleSteps[_currentStepIndex]), // Buộc re-init khi đổi step
                    mode: ScannerMode.registration,
                    targetAngle: _angleSteps[_currentStepIndex],
                    onFaceDetected: (vector, angle) {
                       setState(() {
                         _capturedAngles[angle] = vector;
                         if (_currentStepIndex < 4) {
                           _currentStepIndex++;
                         }
                       });
                       
                       if (_capturedAngles.length == 5) {
                         _saveMultiViewFace(context);
                       }
                    },
                  ),
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

              if (_capturedAngles.isNotEmpty && _capturedAngles.length < 5) ...[
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("CÁC GÓC ĐÃ THU THẬP:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _capturedAngles.keys.map((a) => Chip(
                          label: Text(a.toUpperCase(), style: const TextStyle(fontSize: 8)),
                          backgroundColor: Colors.green.withOpacity(0.1),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      )
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
