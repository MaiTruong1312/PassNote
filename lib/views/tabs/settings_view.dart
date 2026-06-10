// lib/views/tabs/settings_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../utils/app_theme.dart';
import '../../services/secure_storage_service.dart';
import '../passkey_setup_page.dart';
import '../face_setup_page.dart';
import '../../services/biometric_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _usePasskey = true;
  bool _useFace = true;
  bool _useFingerprint = false;
  bool _isLoading = true;
  bool _isBiometricSupported = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _usePasskey = await SecureStorageService.getUsePasskeyLogin();
    _useFace = await SecureStorageService.getUseFaceLogin();
    _useFingerprint = await SecureStorageService.getUseFingerprintLogin();
    _isBiometricSupported = await BiometricService.isBiometricAvailable();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1)),
      );
    }

    final viewModel = Provider.of<DashboardViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "PREFERENCES", 
          style: TextStyle(color: Colors.black, letterSpacing: 4, fontSize: 14, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          _sectionHeader("AUTHENTICATION"),
          _buildSwitchTile(
            title: "BIOMETRIC LOGIN",
            subtitle: "Use face recognition to access vault",
            value: _useFace,
            onChanged: (v) => _handleToggle("face", v),
          ),
          if (_isBiometricSupported)
            _buildSwitchTile(
              title: "FINGERPRINT LOGIN",
              subtitle: "Use system biometrics (Fingerprint/FaceID)",
              value: _useFingerprint,
              onChanged: (v) => _handleToggle("fingerprint", v),
            ),
          _buildSwitchTile(
            title: "PASSKEY ACCESS",
            subtitle: "Secondary 6-digit pin security",
            value: _usePasskey,
            onChanged: (v) => _handleToggle("passkey", v),
          ),
          
          const SizedBox(height: 30),
          _sectionHeader("SECURITY SETUP"),
          _buildListTile(
            icon: Icons.fingerprint_outlined,
            title: "CONFIGURE PASSKEY",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PasskeySetupPage())),
          ),
          _buildListTile(
            icon: Icons.face_unlock_outlined,
            title: "MANAGE FACE IDENTITY",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FaceSetupPage())),
          ),

          const SizedBox(height: 30),
          _sectionHeader("SYSTEM"),
          _buildListTile(
            icon: Icons.logout_outlined,
            title: "TERMINATE SESSION",
            isDestructive: true,
            onTap: () async {
              // Hiển thị dialog xác nhận trước khi đăng xuất để tăng tính trang trọng
              _showLogoutDialog(context, viewModel);
            },
          ),
          
          const SizedBox(height: 40),
          const Center(
            child: Text(
              "THE VAULT v1.0.4 - SECURED ECOSYSTEM",
              style: TextStyle(fontSize: 8, color: Colors.grey, letterSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.w900, 
          color: Colors.black, 
          letterSpacing: 2
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title, 
    required String subtitle, 
    required bool value, 
    required Function(bool) onChanged
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: value ? Colors.black.withOpacity(0.02) : Colors.transparent,
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.black,
        activeTrackColor: Colors.black12,
        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon, 
    required String title, 
    required VoidCallback onTap,
    bool isDestructive = false
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.red[900] : Colors.black, size: 20),
        title: Text(
          title, 
          style: TextStyle(
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 1.5,
            color: isDestructive ? Colors.red[900] : Colors.black
          )
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.black26),
        onTap: onTap,
      ),
    );
  }

  Widget _buildParamTile({required String title, required String subtitle, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              child,
            ],
          ),
        ],
      ),
    );
  }

  void _handleToggle(String type, bool newValue) async {
    final passwordController = TextEditingController();
    bool confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text("SECURITY VERIFICATION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your master password to confirm changes.", style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "PASSWORD",
                hintStyle: TextStyle(fontSize: 10, letterSpacing: 2),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontSize: 10)),
          ),
          TextButton(
            onPressed: () async {
              final creds = await SecureStorageService.getAccountCredentials();
              if (creds['password'] == passwordController.text) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("INVALID PASSWORD", style: TextStyle(fontSize: 10, letterSpacing: 1)))
                );
              }
            },
            child: const Text("CONFIRM", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      bool canEnable = true;
      String? errorMessage;

      if (newValue == true) {
        if (type == "face") {
          final faceData = await SecureStorageService.getFaceEncoding();
          if (faceData == null || faceData.isEmpty) {
            canEnable = false;
            errorMessage = "Please register your Face Identity first.";
          }
        } else if (type == "passkey") {
          final passkey = await SecureStorageService.getPasskey();
          if (passkey == null || passkey.isEmpty) {
            canEnable = false;
            errorMessage = "Please configure your Security PIN first.";
          }
        }
      }

      if (canEnable) {
        if (type == "face") {
          await SecureStorageService.setUseFaceLogin(newValue);
          setState(() => _useFace = newValue);
        } else if (type == "fingerprint") {
          await SecureStorageService.setUseFingerprintLogin(newValue);
          setState(() => _useFingerprint = newValue);
        } else if (type == "passkey") {
          await SecureStorageService.setUsePasskeyLogin(newValue);
          setState(() => _usePasskey = newValue);
        }
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: const Text("DATA REQUIRED", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
            content: Text(errorMessage ?? "Required data missing.", style: const TextStyle(fontSize: 10)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context, DashboardViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text("TERMINATE SESSION?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
        content: const Text("Your local credentials will be cleared for security.", style: TextStyle(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontSize: 10)),
          ),
          TextButton(
            onPressed: () async {
              await viewModel.signOut();
              await SecureStorageService.clearPasskey();
              await SecureStorageService.clearAccountCredentials();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text("LOGOUT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ],
      ),
    );
  }
}