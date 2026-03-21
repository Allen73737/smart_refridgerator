import 'dart:convert';
import 'package:http/http.dart' as http;

class AppSettings {
  static double temperatureThreshold = 10;
  static double humidityThreshold = 70;
  static double freshnessThreshold = 40;

  // Admin-set boundaries — user is restricted between these
  static double adminMinTemperature = 0;
  static double adminMaxTemperature = 10;
  static double adminMinHumidity = 40;
  static double adminMaxHumidity = 95;
  static double adminMinFreshness = 0;
  static double adminMaxFreshness = 100;

  /// Fetch admin-defined threshold ranges from backend
  static Future<void> fetchAdminThresholds() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.127.211.225:5001/api/settings/admin-thresholds'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        adminMinTemperature = (data['minTemperature'] ?? 0).toDouble();
        adminMaxTemperature = (data['maxTemperature'] ?? 10).toDouble();
        adminMinHumidity = (data['minHumidity'] ?? 40).toDouble();
        adminMaxHumidity = (data['maxHumidity'] ?? 95).toDouble();
        adminMinFreshness = (data['minFreshness'] ?? 0).toDouble();
        adminMaxFreshness = (data['maxFreshness'] ?? 100).toDouble();

        // Enforce: if current values are outside admin bounds, clamp them
        temperatureThreshold = temperatureThreshold.clamp(adminMinTemperature, adminMaxTemperature);
        humidityThreshold = humidityThreshold.clamp(adminMinHumidity, adminMaxHumidity);
        freshnessThreshold = freshnessThreshold.clamp(adminMinFreshness, adminMaxFreshness);
      }
    } catch (_) {
      // If backend is unreachable, keep defaults
    }
  }

  /// Clamping helpers
  static double clampTemperature(double val) => val.clamp(adminMinTemperature, adminMaxTemperature);
  static double clampHumidity(double val) => val.clamp(adminMinHumidity, adminMaxHumidity);
  static double clampFreshness(double val) => val.clamp(adminMinFreshness, adminMaxFreshness);
}
