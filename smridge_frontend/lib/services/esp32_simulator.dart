import 'dart:math';

class ESP32Data {
  final int temp;
  final int humidity;
  final int freshness;
  final bool isDoorOpen;
  final DateTime? lastUpdated;

  ESP32Data({
    required this.temp,
    required this.humidity,
    required this.freshness,
    required this.isDoorOpen,
    this.lastUpdated,
  });
}

class ESP32Simulator {
  final Random _random = Random();
  bool _doorState = false;
  int _ticks = 0;

  ESP32Data getData() {
    _ticks++;
    if (_ticks % 5 == 0) {
      // _doorState = !_doorState; // Toggle door state every 5 ticks for simulation
    }

    DateTime currentTime = DateTime.now();
    
    // Simulate Occasional Disconnects (Offline status)
    if (_ticks % 8 == 0) {
       currentTime = currentTime.subtract(const Duration(seconds: 18)); // Offline simulation
    }

    return ESP32Data(
      temp: 2 + _random.nextInt(6),
      humidity: 40 + _random.nextInt(30),
      freshness: 60 + _random.nextInt(40),
      isDoorOpen: _doorState,
      lastUpdated: currentTime,
    );
  }
}
