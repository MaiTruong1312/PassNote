// lib/views/register_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../viewmodels/register_viewmodel.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<RegisterViewModel>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("CREATE ACCOUNT", style: theme.textTheme.displayLarge),
            Text("JOIN THE SECURE NETWORK", style: theme.textTheme.bodyLarge?.copyWith(letterSpacing: 2)),
            const SizedBox(height: 50),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "FULL NAME")),
            const SizedBox(height: 20),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "EMAIL ADDRESS")),
            const SizedBox(height: 20),
            TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: "PASSWORD")),
            const SizedBox(height: 40),
            if (viewModel.errorMessage != null)
              Text(viewModel.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: viewModel.isLoading ? null : () async {
                  bool success = await viewModel.register(_emailController.text, _passController.text, _nameController.text);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng kiểm tra email để xác nhận!")));
                    Navigator.pop(context);
                  }
                },
                child: viewModel.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("CREATE VAULT"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}