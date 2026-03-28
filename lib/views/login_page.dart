import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components/realtime_camera_scanner.dart';
import '../utils/app_theme.dart';
import '../viewmodels/login_viewmodel.dart';
import '../services/secure_storage_service.dart';
import 'register_page.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _pinController = TextEditingController();
  bool _hasPasskey = false;
  bool _hasFace = false;
  bool _isCheckingPasskey = true;
  bool _isRealtimeScanning = false;
  String? _savedEmail;

  @override
  void initState() {
    super.initState();
    _checkPasskey();
  }

  Future<void> _checkPasskey() async {
    final usePasskey = await SecureStorageService.getUsePasskeyLogin();
    final useFace = await SecureStorageService.getUseFaceLogin();
    final passkey = usePasskey ? await SecureStorageService.getPasskey() : null;
    final faceEncoding = useFace ? await SecureStorageService.getFaceEncoding() : null;
    final creds = await SecureStorageService.getAccountCredentials();

    if (mounted) {
      setState(() {
        _hasPasskey = passkey != null;
        _hasFace = faceEncoding != null;
        _savedEmail = creds['email'];
        _isCheckingPasskey = false;
      });
    }
  }

  Future<void> _handleSwitchAccount() async {
    await Provider.of<LoginViewModel>(context, listen: false).loginWithPasskey("");
    await SecureStorageService.clearPasskey();
    await SecureStorageService.clearAccountCredentials();
    setState(() {
      _hasPasskey = false;
      _hasFace = false;
      _pinController.clear();
    });
  }

  // Tiện ích vẽ input tối giản
  InputDecoration _minimalInput(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 2),
      prefixIcon: icon != null ? Icon(icon, color: Colors.black, size: 18) : null,
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPasskey) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1)));
    }

    final viewModel = Provider.of<LoginViewModel>(context);
    final theme = Theme.of(context);

    // GIAO DIỆN KHI ĐÃ CÓ PASSKEY / FACE
    if (_hasPasskey || _hasFace) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 60, color: Colors.black),
                const SizedBox(height: 30),
                const Text("IDENTIFIED", style: TextStyle(letterSpacing: 8, fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 10),
                Text(_savedEmail?.toUpperCase() ?? "", 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300, letterSpacing: 1),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),

                if (_hasPasskey) ...[
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(letterSpacing: 15, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: _minimalInput("SECURITY PIN", null),
                    onChanged: (val) async {
                      if (val.length == 6 && !viewModel.isLoading) {
                        bool success = await viewModel.loginWithPasskey(val);
                        if (success && mounted) {
                           _navigateToDashboard(context);
                        } else {
                          _pinController.clear();
                        }
                      }
                    },
                  ),
                ],

                if (_hasFace) ...[
                  const SizedBox(height: 20),
                  if (!_isRealtimeScanning)
                    OutlinedButton.icon(
                      onPressed: viewModel.isLoading ? null : () => setState(() => _isRealtimeScanning = true),
                      icon: const Icon(Icons.face_unlock_outlined, color: Colors.black, size: 20),
                      label: const Text("BIOMETRIC SCAN", style: TextStyle(color: Colors.black, letterSpacing: 2)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                    ),

                  if (_isRealtimeScanning && !viewModel.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Column(
                        children: [
                          // Tạo khung vuông 1:1 cho Camera
                          Container(
                            width: 260, // Độ rộng khung
                            height: 300, // Chiều cao khung (đảm bảo 1:1 cho sang trọng)
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 1), // Viền đen mảnh
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.zero,
                              child: RealtimeCameraScanner(
                                promptText: "SCANNING FACE...",
                                onFaceDetected: (vector) async {
                                  setState(() => _isRealtimeScanning = false);
                                  bool success = await viewModel.loginWithFaceVector(vector);
                                  if (success && mounted) _navigateToDashboard(context);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text("ALGN FACE WITHIN FRAME",
                              style: TextStyle(fontSize: 9, letterSpacing: 2, color: Colors.grey)),
                        ],
                      ),
                    ),
                ],

                const SizedBox(height: 40),
                if (viewModel.isLoading) const CircularProgressIndicator(color: Colors.black, strokeWidth: 1),
                if (viewModel.error != null)
                  Text(viewModel.error!.toUpperCase(), style: const TextStyle(color: Colors.red, fontSize: 10, letterSpacing: 1)),

                const SizedBox(height: 60),
                TextButton(
                  onPressed: _handleSwitchAccount,
                  child: const Text("SWITCH IDENTITY", style: TextStyle(color: Colors.black54, fontSize: 10, letterSpacing: 2, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // GIAO DIỆN ĐĂNG NHẬP LẦN ĐẦU (EMAIL/PASS)
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 2),
            const Text("THE\nVAULT.", style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, height: 1, letterSpacing: -2)),
            const SizedBox(height: 15),
            Container(height: 3, width: 40, color: Colors.black),
            const SizedBox(height: 60),

            TextField(
              controller: _emailController,
              cursorColor: Colors.black,
              decoration: _minimalInput("ACCESS KEY (EMAIL)", Icons.alternate_email),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _passController,
              obscureText: true,
              cursorColor: Colors.black,
              decoration: _minimalInput("SECRET KEY (PASSWORD)", Icons.lock_outline_rounded),
            ),

            const SizedBox(height: 50),
            if (viewModel.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(viewModel.error!.toUpperCase(), style: const TextStyle(color: Colors.red, fontSize: 10, letterSpacing: 1)),
              ),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: viewModel.isLoading ? null : () async {
                  bool success = await viewModel.login(_emailController.text, _passController.text);
                  if (success && mounted) _navigateToDashboard(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                ),
                child: viewModel.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1))
                    : const Text("AUTHENTICATE", style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: Colors.black, fontSize: 11, letterSpacing: 1),
                    children: [
                      TextSpan(text: "NEW SYSTEM? "),
                      TextSpan(text: "CREATE IDENTITY", style: TextStyle(fontWeight: FontWeight.w900, decoration: TextDecoration.underline)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _navigateToDashboard(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const DashboardPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 1000),
      ),
    );
  }
}