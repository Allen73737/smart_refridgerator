/// @file sensor_provider.dart
/// @description The central real-time state manager for all IoT sensor data.
///
/// This class uses Flutter's [ChangeNotifier] (Provider pattern) to broadcast
/// sensor updates to every widget in the app that is listening.
///
/// Data sources (in priority order):
///   1. WebSocket push (via [SocketService]): Instant, zero-latency updates from backend.
///   2. HTTP polling (every 10 seconds): Fallback for when socket events are missed.
///   3. Initial fetch on startup: Ensures data is displayed immediately on cold boot.
///
/// Key public fields consumed by the UI:
///   - [temperature], [humidity], [gasLevel]: Raw sensor readings.
///   - [freshnessScore]: Overall fridge health score (0-100).
///   - [doorStatus]: "OPEN" or "CLOSED".
///   - [isRealData]: Whether data came from real ESP32 hardware (vs. simulation).
///   - [tempHistory]: Last 20 temperature readings for the sparkline mini-chart.
///
/// Call [notifyListeners()] after any state change to trigger UI rebuilds.

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

class SensorProvider extends ChangeNotifier {
  double temperature = 0.0;
  double humidity = 0.0;
  int gasLevel = 0;
  double freshnessScore = 0.0;
  String status = "LOADING...";
  String? doorStatus = "---";
  DateTime? lastUpdated;
  bool isRealData = false;
  List<double> tempHistory = []; // 📈 History for mini-sparklines
  Timer? _pollingTimer;

  /// 🔗 Callback for ConnectivityProvider to track ESP32 liveness
  void Function(DateTime?)? onLivenessUpdate;

  SensorProvider() {
    _initSocket();
    // Initial fetch with whatever token we have at startup.
    // The real sync happens via initForUser() after login.
    _fetchCurrentData();
    _startPolling();
  }

  /// 🔑 CALL THIS AFTER LOGIN: Joins socket room + immediately fetches live data.
  /// Without calling this, the SensorProvider may never receive targeted
  /// ESP32 socket events because the backend emits only to user-specific rooms.
  Future<void> initForUser(String userId) async {
    print('🎛️ [SensorProvider] Initializing for user: $userId');
    // 1. Join the socket room so server-side emitToUser() reaches this device
    SocketService.joinUserRoom(userId);
    // 2. Cancel existing polling and restart fresh
    _pollingTimer?.cancel();
    // 3. Fetch immediately (don't wait for poll interval)
    await _fetchCurrentData();
    // 4. Restart polling at 5s intervals
    _startPolling();
  }

  Future<void> _fetchCurrentData() async {
    try {
      final token = await SecureStorageService.getToken();
      if (token != null) {
        // Use clean /api/sensors/latest endpoint (no deviceId needed)
        final data = await ApiService.getLatestSensorDataDirect(token);
        if (data != null) updateFromData(data);
      }
    } catch (e) {
      debugPrint("Sensor Fetch Error: $e");
    }
  }

  void _startPolling() {
    // Poll every 5s (was 10s) to keep System Monitor in tight sync with Device Analytics
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchCurrentData());
  }

  void _initSocket() {
    SocketService.on('sensor_data', (data) {
      // 🛡️ CENTRALIZED ROBUST PARSING
      final rawTemp = data['temperature']?.toString() ?? "3.5";
      final rawHum = data['humidity']?.toString() ?? "60.0";
      final rawGas = data['gasLevel']?.toString() ?? "15";
      // 🔥 FIX: Only update freshness if the payload actually has it.
      // Using ?? "100.0" caused the display to flip back to 100% every time
      // the backend sent a response (e.g. DB fallback) without a freshness field.
      final rawFreshStr = (data['freshnessScore'] ?? data['calculatedFreshness'])?.toString();
      final rawDoor = (data['doorStatus'] ?? data['doorOpen'] ?? "closed").toString();

      temperature = double.tryParse(rawTemp) ?? 3.5;
      humidity = double.tryParse(rawHum) ?? 60.0;
      gasLevel = int.tryParse(rawGas) ?? 15;
      // Only overwrite freshnessScore when we have a real value from this payload
      if (rawFreshStr != null) {
        freshnessScore = double.tryParse(rawFreshStr) ?? freshnessScore;
      }
      status = data['status']?.toString() ?? status;
      doorStatus = (rawDoor == 'true' || rawDoor.toLowerCase() == 'open') ? "OPEN" : "CLOSED";
      isRealData = data['isReal'] ?? true;
      lastUpdated = DateTime.now();

      // 📈 Update history buffer for sparklines
      if (tempHistory.length >= 20) tempHistory.removeAt(0);
      tempHistory.add(temperature);

      onLivenessUpdate?.call(lastUpdated);
      notifyListeners();
    });
  }

  void updateFromData(Map<String, dynamic> data) {
    final rawTemp = data['temperature']?.toString() ?? "3.5";
    final rawHum = data['humidity']?.toString() ?? "60.0";
    final rawGas = data['gasLevel']?.toString() ?? "15";
    // 🔥 FIX: Preserve last known freshnessScore if payload has no freshness field
    final rawFreshStr = (data['freshnessScore'] ?? data['calculatedFreshness'])?.toString();
    final rawDoor = (data['doorStatus'] ?? data['doorOpen'] ?? "closed").toString();

    temperature = double.tryParse(rawTemp) ?? 3.5;
    humidity = double.tryParse(rawHum) ?? 60.0;
    gasLevel = int.tryParse(rawGas) ?? 15;
    if (rawFreshStr != null) {
      freshnessScore = double.tryParse(rawFreshStr) ?? freshnessScore;
    }
    status = data['status']?.toString() ?? status;
    doorStatus = (rawDoor == 'true' || rawDoor.toLowerCase() == 'open') ? "OPEN" : "CLOSED";
    isRealData = data['isReal'] ?? true;
    lastUpdated = DateTime.now();

    onLivenessUpdate?.call(lastUpdated);
    notifyListeners();
  }

  /// 📊 Preload history points from the cloud for Dashboard Sparkline
  void setInitialHistory(List<dynamic> historyData) {
    tempHistory.clear();
    for (var entry in historyData) {
      final t = double.tryParse(entry['temperature']?.toString() ?? "");
      if (t != null) tempHistory.add(t);
    }
    
    // Cap to last 20
    if (tempHistory.length > 20) {
      tempHistory = tempHistory.sublist(tempHistory.length - 20);
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    SocketService.off('sensor_data');
    super.dispose();
  }
}
