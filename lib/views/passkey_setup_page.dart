import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/secure_storage_service.dart';
import '../utils/password_prompt.dart';

class PasskeySetupPage extends StatefulWidget {
  const PasskeySetupPage({super.key});

  @override
  State<PasskeySetupPage> createState() => _PasskeySetupPageState();
}

class _PasskeySetupPageState extends State<PasskeySetupPage> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isConfirming = false;
  String _firstPin = '';
  String? _error;
  bool _hasExisting = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final passkey = await SecureStorageService.getPasskey();
    if (mounted) {
      setState(() {
        _hasExisting = passkey != null;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final theme = Theme.of(context);

    if (_hasExisting) {
      return Scaffold(
        appBar: AppBar(title: const Text("SETUP PASSKEY"), centerTitle: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              const Text("PASSKEY IS ACTIVE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Your passkey is currently securing this vault.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                   if (await PasswordPrompt.verify(context)) {
                      setState(() => _hasExisting = false);
                   }
                },
                child: const Text("TẠO LẠI PIN MỚI / CHANGE PIN"),
              )
            ]
          )
        )
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("SETUP PASSKEY"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.security, size: 50, color: AppTheme.primaryBlack),
            const SizedBox(height: 40),
            Text(_isConfirming ? "CONFIRM PASSKEY" : "CREATE PASSKEY", style: theme.textTheme.displayLarge?.copyWith(fontSize: 24)),
            const SizedBox(height: 10),
            Text(_isConfirming ? "RE-ENTER YOUR 6-DIGIT PIN" : "ENTER A 6-DIGIT PIN FOR QUICK LOGIN", style: theme.textTheme.bodyLarge?.copyWith(letterSpacing: 2, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 60),

            TextField(
              controller: _isConfirming ? _confirmPinController : _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: const InputDecoration(labelText: "6-DIGIT PIN"),
              onChanged: (val) {
                if (val.length == 6) {
                  if (!_isConfirming) {
                    setState(() {
                      _firstPin = val;
                      _isConfirming = true;
                      _error = null;
                    });
                  } else {
                    if (val == _firstPin) {
                      _savePasskey(val);
                    } else {
                      setState(() {
                        _error = "PIN DOES NOT MATCH. TRY AGAIN.";
                        _isConfirming = false;
                        _pinController.clear();
                        _confirmPinController.clear();
                      });
                    }
                  }
                }
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 20),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _savePasskey(String pin) async {
    await SecureStorageService.savePasskey(pin);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PASSKEY SAVED SUCCESSFULLY"), behavior: SnackBarBehavior.floating),
    );
    Navigator.pop(context);
  }
}
