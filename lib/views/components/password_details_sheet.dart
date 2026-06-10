// lib/views/components/password_details_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/encryption_service.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../utils/app_theme.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

import '../../services/face_inference_service.dart';
import '../../services/secure_storage_service.dart';
import '../../models/password_model.dart';

class PasswordDetailsSheet extends StatefulWidget {
  final Password item;

  const PasswordDetailsSheet({super.key, required this.item});

  @override
  State<PasswordDetailsSheet> createState() => _PasswordDetailsSheetState();
}

class _PasswordDetailsSheetState extends State<PasswordDetailsSheet> {
  bool _obscurePassword = true;
  bool _isAuthenticating = false;
  String _decryptedPassword = "Error decoding";

  @override
  void initState() {
    super.initState();
    try {
      _decryptedPassword = EncryptionService.decryptPassword(
          widget.item.encryptedPassword,
          widget.item.iv
      );
    } catch (e) {
      debugPrint("Decrypt error: $e");
    }
  }

  void _confirmDelete() {
    final viewModel = Provider.of<DashboardViewModel>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final innerNavigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("DELETE PASSWORD"),
        content: const Text("Are you sure you want to delete this password? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // close dialog
              bool success = await viewModel.deletePassword(widget.item.supabaseId, widget.item.localId);
              if (success && mounted) {
                innerNavigator.pop(); // close bottom sheet
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text("PASSWORD DELETED SUCCESSFULLY"), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  Future<bool> _promptFaceAuth() async {
     setState(() => _isAuthenticating = true);
     final scaffoldMessenger = ScaffoldMessenger.of(context);
     
     try {
       final savedStr = await SecureStorageService.getFaceEncoding();
       if (savedStr == null) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Face Not Configured. Go to Settings.")));
          return false;
       }
       
       final picker = ImagePicker();
       final source = (Platform.isWindows || Platform.isLinux || Platform.isMacOS) 
                            ? ImageSource.gallery 
                            : ImageSource.camera;
       final pickedFile = await picker.pickImage(source: source, preferredCameraDevice: CameraDevice.front);
       
       if (pickedFile == null) return false;

       final vector = await FaceInferenceService().extractEmbedding(File(pickedFile.path));
       if (vector != null) {
          final List<double> savedEncoding = List<double>.from(jsonDecode(savedStr));
          double distance = FaceInferenceService.calculateCosineDistance(vector, savedEncoding);
          debugPrint("Face distance (Local Sheet): $distance");
          
          final threshold = await SecureStorageService.getFaceThreshold();
          if (distance < threshold) return true;
          scaffoldMessenger.showSnackBar(SnackBar(content: Text("Face mismatch! (Dist: ${distance.toStringAsFixed(3)})")));
          return false;
       } else {
         scaffoldMessenger.showSnackBar(const SnackBar(content: Text("SERVER ERROR OR NO FACE DETECTED.")));
         return false;
       }
     } finally {
       if (mounted) setState(() => _isAuthenticating = false);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 40,
        right: 40,
        top: 40,
        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.item.appName.toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _confirmDelete),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.black, thickness: 2),
          const SizedBox(height: 20),
          _infoRow("USERNAME", widget.item.appUsername),
          const SizedBox(height: 15),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PASSWORD", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _obscurePassword ? '•' * _decryptedPassword.length : _decryptedPassword, 
                      style: const TextStyle(fontSize: 16, letterSpacing: 2)
                    ),
                  ),
                  IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: _isAuthenticating ? null : () async {
                      if (_obscurePassword && widget.item.isFavorite == true) {
                         bool authSuccess = await _promptFaceAuth();
                         if (!authSuccess && mounted) return; 
                      }
                      if (mounted) {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 40),
          SizedBox(
             width: double.infinity,
             child: ElevatedButton(
               onPressed: () {
                 Clipboard.setData(ClipboardData(text: _decryptedPassword));
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text("PASSWORD COPIED TO CLIPBOARD"), behavior: SnackBarBehavior.floating),
                 );
               },
               child: const Text("COPY TO CLIPBOARD"),
             ),
           ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 16, letterSpacing: 1)),
      ],
    );
  }
}
