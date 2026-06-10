import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:flutter/foundation.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  /// Kiểm tra xem thiết bị có hỗ trợ sinh trắc học và đã thiết lập hay chưa
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      debugPrint("BiometricService Error: $e");
      return false;
    }
  }

  /// Thực hiện xác thực bằng sinh trắc học hệ thống
  static Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to access your secure vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'VAULT AUTHENTICATION',
            deviceCredentialsRequiredTitle: 'Biometric required',
            cancelButton: 'CANCEL',
          ),
          IOSAuthMessages(
            cancelButton: 'CANCEL',
          ),
        ],
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint("BiometricService Auth Error: $e");
      return false;
    }
  }
}
