import 'dart:convert';
import 'package:http/http.dart' as http;

class AppSettings {
  static double temperatureThreshold = 10;
  static double humidityThreshold = 70;
  static double freshnessThreshold = 40;

  // Admin-set minimums — user cannot go lower than these
  static double adminMinTemperature = 0;
  static double adminMinHumidity = 0;
  static double adminMinFreshness = 0;

  /// Fetch admin-defined minimum thresholds from backend
  static Future<void> fetchAdminThresholds() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.127.211.225:5001/api/settings/admin-thresholds'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        adminMinTemperature = (data['minTemperature'] ?? 0).toDouble();
        adminMinHumidity = (data['minHumidity'] ?? 0).toDouble();
        adminMinFreshness = (data['minFreshness'] ?? 0).toDouble();

        // Enforce: if current values are below admin minimums, clamp them up
        if (temperatureThreshold < adminMinTemperature) {
          temperatureThreshold = adminMinTemperature;
        }
        if (humidityThreshold < adminMinHumidity) {
          humidityThreshold = adminMinHumidity;
        }
        if (freshnessThreshold < adminMinFreshness) {
          freshnessThreshold = adminMinFreshness;
        }
      }
    } catch (_) {
      // If backend is unreachable, keep defaults (no admin enforcement)
    }
  }

  /// Clamp a user-set value to be at least the admin minimum
  static double clampTemperature(double val) =>
      val < adminMinTemperature ? adminMinTemperature : val;

  static double clampHumidity(double val) =>
      val < adminMinHumidity ? adminMinHumidity : val;

  static double clampFreshness(double val) =>
      val < adminMinFreshness ? adminMinFreshness : val;
}
