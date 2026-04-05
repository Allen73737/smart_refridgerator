import 'package:flutter/material.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

class SensorProvider extends ChangeNotifier {
  double temperature = 3.5;
  double humidity = 60.0;
  int gasLevel = 15;
  double freshnessScore = 100.0;
  String status = "OPTIMAL";
  String? doorStatus = "CLOSED";
  DateTime? lastUpdated;
  bool isRealData = false;
  List<double> tempHistory = []; // 📈 History for mini-sparklines
  Timer? _pollingTimer;

  SensorProvider() {
    _initSocket();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final token = await SecureStorageService.getToken();
        if (token != null) {
          // Poll REST DB to guarantee System Monitor parity with Analytics
          final data = await ApiService.getLatestSensorData('auto', token);
          if (data != null) {
            updateFromData(data);
          }
        }
      } catch (e) {
        debugPrint("Sensor Polling Error: $e");
      }
    });
  }

  void _initSocket() {
    SocketService.on('sensor_data', (data) {
      // 🛡️ CENTRALIZED ROBUST PARSING
      final rawTemp = data['temperature']?.toString() ?? "3.5";
      final rawHum = data['humidity']?.toString() ?? "60.0";
      final rawGas = data['gasLevel']?.toString() ?? "15";
      final rawFresh = data['calculatedFreshness']?.toString() ?? "100.0";
      final rawDoor = data['doorStatus']?.toString() ?? "closed";

      temperature = double.tryParse(rawTemp) ?? 3.5;
      humidity = double.tryParse(rawHum) ?? 60.0;
      gasLevel = int.tryParse(rawGas) ?? 15;
      freshnessScore = double.tryParse(rawFresh) ?? 100.0;
      status = data['status']?.toString() ?? "OPTIMAL";
      doorStatus = (data['doorOpen'] == true || rawDoor == 'open') ? "OPEN" : "CLOSED";
      isRealData = data['isReal'] ?? false;
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
    final rawFresh = data['calculatedFreshness']?.toString() ?? "100.0";
    final rawDoor = data['doorStatus']?.toString() ?? "closed";

    temperature = double.tryParse(rawTemp) ?? 3.5;
    humidity = double.tryParse(rawHum) ?? 60.0;
    gasLevel = int.tryParse(rawGas) ?? 15;
    freshnessScore = double.tryParse(rawFresh) ?? 100.0;
    status = data['status']?.toString() ?? "OPTIMAL";
    doorStatus = (data['doorOpen'] == true || rawDoor == 'open') ? "OPEN" : "CLOSED";
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
