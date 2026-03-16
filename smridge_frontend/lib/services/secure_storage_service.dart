import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';
  static const _biometricKey = 'biometric_enabled';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    // Also save to SharedPreferences for backup/legacy compatibility
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setBool('isLoggedIn', true);
  }

  static Future<String?> getToken() async {
    // Try secure storage first
    String? token = await _storage.read(key: _tokenKey);
    if (token == null) {
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');
      // If found in prefs but not secure storage, sync it up
      if (token != null) {
        await _storage.write(key: _tokenKey, value: token);
      }
    }
    return token;
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.setBool('isLoggedIn', false);
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled.toString());
  }

  static Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _biometricKey);
    return val == 'true';
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
