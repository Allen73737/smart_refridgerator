import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HapticService {
  static bool _enabled = true;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('haptics_enabled') ?? true;
  }

  static void setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptics_enabled', value);
  }

  static bool get isEnabled => _enabled;

  /// 📳 Light tap for subtle interactions (buttons, tabs)
  static void light() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  /// 📳 Medium impact for more significant actions (saving, adding)
  static void medium() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// 📳 Heavy impact for critical or tactile operations (deleting, errors)
  static void heavy() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// 📳 Selection feedback for list item interactions
  static void selection() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  /// 📳 Vibrates for errors or critical warnings
  static void error() {
    if (!_enabled) return;
    HapticFeedback.vibrate();
  }
}
