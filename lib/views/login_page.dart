import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components/realtime_camera_scanner.dart';
import '../utils/app_theme.dart';
import '../viewmodels/login_viewmodel.dart';
import '../services/secure_storage_service.dart';
import 'register_page.dart';
import 'dashboard_page.dart';

enum LoginMethod { password, pin, face, fingerprint }

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
  bool _hasFingerprint = false;
  bool _isCheckingPasskey = true;
  bool _isRealtimeScanning = false;
  String? _savedEmail;
  LoginMethod _currentMethod = LoginMethod.password;
  List<LoginMethod> _availableMethods = [LoginMethod.password];

  @override
  void initState() {
    super.initState();
    _checkPasskey();
  }

  Future<void> _checkPasskey() async {
    final usePasskey = await SecureStorageService.getUsePasskeyLogin();
    final useFace = await SecureStorageService.getUseFaceLogin();
    final useFingerprint = await SecureStorageService.getUseFingerprintLogin();
    
    final passkey = usePasskey ? await SecureStorageService.getPasskey() : null;
    final faceEncoding = useFace ? await SecureStorageService.getFaceEncoding() : null;
    final creds = await SecureStorageService.getAccountCredentials();

    if (mounted) {
      List<LoginMethod> methods = [LoginMethod.password];
      if (passkey != null) methods.add(LoginMethod.pin);
      if (faceEncoding != null) methods.add(LoginMethod.face);
      if (useFingerprint && (creds['email'] != null)) methods.add(LoginMethod.fingerprint);

      setState(() {
        _hasPasskey = passkey != null;
        _hasFace = faceEncoding != null;
        _hasFingerprint = useFingerprint && (creds['email'] != null);
        _savedEmail = creds['email'];
        _availableMethods = methods;
        // Ưu tiên hiển thị phương thức bảo mật cao nhất trước
        _currentMethod = methods.length > 1 ? methods.last : LoginMethod.password;
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

    // GIAO DIỆN KHI ĐÃ NHẬN DIỆN ĐƯỢC TÀI KHOẢN (ĐÃ LƯU EMAIL)
    if (_savedEmail != null) {
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

                // HIỂN THỊ PHƯƠNG THỨC ĐANG CHỌN
                if (_currentMethod == LoginMethod.password) ...[
                  TextField(
                    controller: _passController,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(letterSpacing: 2, fontSize: 16),
                    decoration: _minimalInput("MASTER PASSWORD", null),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: viewModel.isLoading ? null : () async {
                        final creds = await SecureStorageService.getAccountCredentials();
                        if (creds['email'] != null) {
                          bool success = await viewModel.login(creds['email']!, _passController.text);
                          if (success && mounted) _navigateToDashboard(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                      child: const Text("UNLOCK VAULT", style: TextStyle(color: Colors.white, letterSpacing: 2)),
                    ),
                  ),
                ],

                if (_currentMethod == LoginMethod.pin) ...[
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(letterSpacing: 15, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: _minimalInput("PASSKEY PIN", null),
                    onChanged: (val) async {
                      if (val.length == 6 && !viewModel.isLoading) {
                        bool success = await viewModel.loginWithPasskey(val);
                        if (success && mounted) _navigateToDashboard(context);
                        else _pinController.clear();
                      }
                    },
                  ),
                ],

                if (_currentMethod == LoginMethod.face) ...[
                  if (!_isRealtimeScanning)
                    OutlinedButton.icon(
                      onPressed: viewModel.isLoading ? null : () => setState(() => _isRealtimeScanning = true),
                      icon: const Icon(Icons.face_unlock_outlined, color: Colors.black, size: 20),
                      label: const Text("START FACE SCAN", style: TextStyle(color: Colors.black, letterSpacing: 2)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                    ),
                  if (_isRealtimeScanning && !viewModel.isLoading)
                    Column(
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height * 0.55,
                          width: double.infinity,
                          decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                          child: RealtimeCameraScanner(
                            mode: ScannerMode.login,
                            onFaceDetected: (vector, angle) async {
                              bool success = await viewModel.loginWithFaceVector(vector);
                              if (success && mounted) {
                                setState(() => _isRealtimeScanning = false);
                                _navigateToDashboard(context);
                              }
                            },
                          ),
                        ),
                        if (viewModel.lastMatchDistance != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Text("MATCH: ${viewModel.lastMatchSource}", 
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                Text("DIST: ${viewModel.lastMatchDistance?.toStringAsFixed(4)}", 
                                  style: TextStyle(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.w900, 
                                    color: (viewModel.lastMatchDistance ?? 1.0) < 0.4 ? Colors.green : Colors.red
                                  )),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],

                if (_currentMethod == LoginMethod.fingerprint) ...[
                  OutlinedButton.icon(
                    onPressed: viewModel.isLoading ? null : () async {
                      bool success = await viewModel.loginWithBiometrics();
                      if (success && mounted) _navigateToDashboard(context);
                    },
                    icon: const Icon(Icons.fingerprint_outlined, color: Colors.black, size: 20),
                    label: const Text("BIOMETRIC ACCESS", style: TextStyle(color: Colors.black, letterSpacing: 2)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
                if (viewModel.isLoading) const CircularProgressIndicator(color: Colors.black, strokeWidth: 1),
                if (viewModel.error != null)
                  Text(viewModel.error!.toUpperCase(), style: const TextStyle(color: Colors.red, fontSize: 10, letterSpacing: 1)),

                const SizedBox(height: 60),
                if (_availableMethods.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _availableMethods.map((method) {
                      IconData icon;
                      switch (method) {
                        case LoginMethod.password: icon = Icons.password_outlined; break;
                        case LoginMethod.pin: icon = Icons.key_outlined; break;
                        case LoginMethod.face: icon = Icons.face_retouching_natural_outlined; break;
                        case LoginMethod.fingerprint: icon = Icons.fingerprint_outlined; break;
                      }
                      bool isSelected = _currentMethod == method;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: isSelected ? const Border(bottom: BorderSide(color: Colors.black, width: 2)) : null,
                        ),
                        child: IconButton(
                          icon: Icon(icon, color: isSelected ? Colors.black : Colors.black26, size: 22),
                          onPressed: () => setState(() {
                            _currentMethod = method;
                            _pinController.clear();
                            _passController.clear();
                            _isRealtimeScanning = false;
                          }),
                        ),
                      );
                    }).toList(),
                  ),
                
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _handleSwitchAccount,
                  child: const Text("TERMINATE & SWITCH IDENTITY", style: TextStyle(color: Colors.redAccent, fontSize: 8, letterSpacing: 2)),
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