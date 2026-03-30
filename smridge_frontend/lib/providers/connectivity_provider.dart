import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

class ConnectivityProvider with ChangeNotifier {
  bool _isConnected = false;
  String? _deviceId;
  String? _deviceName;
  String? _lastSsid;
  String? _lastPassword;
  bool _isLoading = false;

  bool get isConnected => _isConnected;
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  String? get lastSsid => _lastSsid;
  String? get lastPassword => _lastPassword;
  bool get isLoading => _isLoading;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    await refreshStatus();
    _lastSsid = await SecureStorageService.getLastSsid();
    _lastPassword = await SecureStorageService.getLastPassword();
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await SecureStorageService.getToken();
      if (token != null) {
        final devices = await ApiService.getUserDevices(token);
        if (devices.isNotEmpty) {
          _isConnected = true;
          _deviceId = devices[0]['_id'];
          _deviceName = devices[0]['name'] ?? 'Smridge Hub';
        } else {
          _isConnected = false;
          _deviceId = null;
          _deviceName = null;
        }
      }
    } catch (e) {
      print("Error refreshing connectivity status: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStoredCredentials(String ssid, String password) async {
    _lastSsid = ssid;
    _lastPassword = password;
    await SecureStorageService.saveWifiCredentials(ssid, password);
    notifyListeners();
  }
}
