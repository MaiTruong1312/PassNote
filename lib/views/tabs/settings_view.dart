// lib/views/tabs/settings_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../utils/app_theme.dart';
import '../../services/secure_storage_service.dart';
import '../passkey_setup_page.dart';
import '../face_setup_page.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _usePasskey = true;
  bool _useFace = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _usePasskey = await SecureStorageService.getUsePasskeyLogin();
    _useFace = await SecureStorageService.getUseFaceLogin();
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
            onChanged: (v) async {
              await SecureStorageService.setUseFaceLogin(v);
              setState(() => _useFace = v);
            },
          ),
          _buildSwitchTile(
            title: "PASSKEY ACCESS",
            subtitle: "Secondary 6-digit pin security",
            value: _usePasskey,
            onChanged: (v) async {
              await SecureStorageService.setUsePasskeyLogin(v);
              setState(() => _usePasskey = v);
            },
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