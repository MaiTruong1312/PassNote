import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/add_password_viewmodel.dart';

class AddPasswordSheet extends StatefulWidget {
  const AddPasswordSheet({super.key});

  @override
  State<AddPasswordSheet> createState() => _AddPasswordSheetState();
}

class _AddPasswordSheetState extends State<AddPasswordSheet> {
  final _appController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _requiresFaceAuth = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AddPasswordViewModel>(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
        left: 30, right: 30, top: 30,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("NEW CREDENTIAL",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 25),
          TextField(
            controller: _appController,
            decoration: const InputDecoration(labelText: "APPLICATION NAME"),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _userController,
            decoration: const InputDecoration(labelText: "USERNAME / EMAIL"),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _passController,
            obscureText: true,
            decoration: const InputDecoration(labelText: "PASSWORD"),
          ),
          const SizedBox(height: 15),
          SwitchListTile(
            title: const Text("REQUIRE FACE AUTH"),
            subtitle: const Text("Face scan required to view this password"),
            value: _requiresFaceAuth,
            activeColor: Colors.green,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _requiresFaceAuth = val),
          ),
          const SizedBox(height: 35),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: viewModel.isLoading ? null : () async {
                final success = await viewModel.savePassword(
                  appName: _appController.text,
                  username: _userController.text,
                  password: _passController.text,
                  requiresFace: _requiresFaceAuth,
                );
                if (success && mounted) Navigator.pop(context);
              },
              child: viewModel.isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("SAVE TO VAULT"),
            ),
          ),
        ],
      ),
    );
  }
}