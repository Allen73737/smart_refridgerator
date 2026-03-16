import 'package:local_auth/local_auth.dart';
import 'secure_storage_service.dart';

class AuthService {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();
    return canAuthenticate;
  }

  Future<bool> authenticate() async {
    try {
      if (!await isBiometricAvailable()) return false;
      
      return await auth.authenticate(
        localizedReason: "Authenticate to access Smridge",
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      print("Biometric Auth Error: $e");
      return false;
    }
  }

  static Future<bool> logout() async {
    await SecureStorageService.deleteToken();
    return true;
  }
}
