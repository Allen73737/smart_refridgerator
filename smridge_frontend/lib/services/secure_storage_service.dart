import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';
  static const _biometricKey = 'biometric_enabled';
  static const _lastSsidKey = 'last_connected_ssid';
  static const _lastPasswordKey = 'last_connected_password';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    // Also save to SharedPreferences for backup/legacy compatibility
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setBool('isLoggedIn', true);
  }

  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
  }

  static Future<void> deleteUserId() async {
    await _storage.delete(key: _userIdKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
  }

  static Future<String?> getUserId() async {
    String? id = await _storage.read(key: _userIdKey);
    if (id == null) {
      final prefs = await SharedPreferences.getInstance();
      id = prefs.getString('userId');
    }
    return id;
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

  static const _pinKey = 'app_pin';
  static const _pinEnabledKey = 'pin_enabled';
  static const _onboardingSeenKey = 'has_seen_onboarding';
  static const _walkthroughSeenKey = 'has_seen_walkthrough';

  static Future<bool> hasSeenOnboarding() async {
    final val = await _storage.read(key: _onboardingSeenKey);
    return val == 'true';
  }

  static Future<void> setOnboardingSeen(bool seen) async {
    await _storage.write(key: _onboardingSeenKey, value: seen.toString());
  }

  static Future<bool> hasSeenWalkthrough() async {
    final val = await _storage.read(key: _walkthroughSeenKey);
    return val == 'true';
  }

  static Future<void> setWalkthroughSeen(bool seen) async {
    await _storage.write(key: _walkthroughSeenKey, value: seen.toString());
  }

  static Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
    await _storage.write(key: _pinEnabledKey, value: 'true');
  }

  static Future<String?> getPin() async {
    return await _storage.read(key: _pinKey);
  }

  static Future<bool> isPinEnabled() async {
    final val = await _storage.read(key: _pinEnabledKey);
    return val == 'true';
  }

  static Future<void> setPinEnabled(bool enabled) async {
    await _storage.write(key: _pinEnabledKey, value: enabled.toString());
  }

  static Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
    await _storage.write(key: _pinEnabledKey, value: 'false');
  }

  static Future<void> saveString(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  static Future<String?> getString(String key) async {
    return await _storage.read(key: key);
  }

  static Future<void> saveWifiCredentials(String ssid, String password) async {
    await _storage.write(key: _lastSsidKey, value: ssid);
    await _storage.write(key: _lastPasswordKey, value: password);
  }
  
  static Future<String?> getLastSsid() async => await _storage.read(key: _lastSsidKey);
  static Future<String?> getLastPassword() async => await _storage.read(key: _lastPasswordKey);

  static Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
