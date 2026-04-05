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

  SensorProvider() {
    _initSocket();
    // 🚀 IMMEDIATE FETCH: Get data right now so UI is in sync on startup
    _fetchCurrentData();
    _startPolling();
  }

  Future<void> _fetchCurrentData() async {
    try {
      final token = await SecureStorageService.getToken();
      if (token != null) {
        final data = await ApiService.getLatestSensorData('auto', token);
        if (data != null) updateFromData(data);
      }
    } catch (e) {
      debugPrint("Initial Sensor Fetch Error: $e");
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchCurrentData());
  }

  void _initSocket() {
    SocketService.on('sensor_data', (data) {
      // 🛡️ CENTRALIZED ROBUST PARSING
      final rawTemp = data['temperature']?.toString() ?? "3.5";
      final rawHum = data['humidity']?.toString() ?? "60.0";
      final rawGas = data['gasLevel']?.toString() ?? "15";
      final rawFresh = (data['freshnessScore'] ?? data['calculatedFreshness'])?.toString() ?? "100.0";
      final rawDoor = (data['doorStatus'] ?? data['doorOpen'] ?? "closed").toString();

      temperature = double.tryParse(rawTemp) ?? 3.5;
      humidity = double.tryParse(rawHum) ?? 60.0;
      gasLevel = int.tryParse(rawGas) ?? 15;
      freshnessScore = double.tryParse(rawFresh) ?? 100.0;
      status = data['status']?.toString() ?? "OPTIMAL";
      doorStatus = (rawDoor == 'true' || rawDoor.toLowerCase() == 'open') ? "OPEN" : "CLOSED";
      isRealData = data['isReal'] ?? true;
      lastUpdated = DateTime.now();

      // 📈 Update history buffer for sparklines
      if (tempHistory.length >= 20) tempHistory.removeAt(0);
      tempHistory.add(temperature);

      notifyListeners();
    });
  }

  void updateFromData(Map<String, dynamic> data) {
    final rawTemp = data['temperature']?.toString() ?? "3.5";
    final rawHum = data['humidity']?.toString() ?? "60.0";
    final rawGas = data['gasLevel']?.toString() ?? "15";
    final rawFresh = (data['freshnessScore'] ?? data['calculatedFreshness'])?.toString() ?? "100.0";
    final rawDoor = (data['doorStatus'] ?? data['doorOpen'] ?? "closed").toString();

    temperature = double.tryParse(rawTemp) ?? 3.5;
    humidity = double.tryParse(rawHum) ?? 60.0;
    gasLevel = int.tryParse(rawGas) ?? 15;
    freshnessScore = double.tryParse(rawFresh) ?? 100.0;
    status = data['status']?.toString() ?? "OPTIMAL";
    doorStatus = (rawDoor == 'true' || rawDoor.toLowerCase() == 'open') ? "OPEN" : "CLOSED";
    isRealData = data['isReal'] ?? true; 
    lastUpdated = DateTime.now();

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
