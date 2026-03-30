import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'dart:io';
import '../models/inventory_item.dart';

class IconService {
  // 🧊 Android alias names match the android:name SUFFIX in AndroidManifest.xml
  // AndroidManifest has: android:name=".Teal", ".Warning", ".Danger"
  // flutter_dynamic_icon_plus expects the suffix without the dot on Android
  static const _iconTeal    = 'Teal';
  static const _iconWarning = 'Warning';
  static const _iconDanger  = 'Danger';

  static String? _currentIcon;
  static bool _isInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    try {
      // Basic check for platform support
      if (Platform.isAndroid || Platform.isIOS) {
        _isInitialized = true;
      }
    } catch (e) {
      print("❌ IconService initialization failed: $e");
    }
  }

  static Future<void> updateAppIcon(List<InventoryItem> items) async {
    await _ensureInitialized();
    try {
      if (!_isInitialized) return;

      bool hasExpired = false;
      bool hasWarning = false;

      final now = DateTime.now();
      for (var item in items) {
        if (item.expiryDate.isBefore(now)) {
          hasExpired = true;
          break; // ⚠️ Danger is highest priority — stop scanning
        } else if (item.expiryDate.difference(now).inDays <= 2) {
          hasWarning = true;
        }
      }

      // Determine the target icon
      final String targetIcon;
      if (hasExpired) {
        targetIcon = _iconDanger;
      } else if (hasWarning) {
        targetIcon = _iconWarning;
      } else {
        targetIcon = _iconTeal;
      }

      // Skip if already correct (avoids unnecessary platform calls)
      if (_currentIcon == targetIcon) return;

      print("🧊 Smridge Icon Switch: $_currentIcon → $targetIcon");
      await _switchIcon(targetIcon);
    } catch (e) {
      // Non-fatal — gracefully degrade
      print("⚠️ Icon update skipped: $e");
    }
  }

  /// Internal helper to switch icon with Android delay
  static Future<void> _switchIcon(String iconName) async {
    // Android needs a small yield so the component state commits properly
    if (Platform.isAndroid) await Future.delayed(const Duration(milliseconds: 300));
    await FlutterDynamicIconPlus.setAlternateIconName(
      iconName: Platform.isIOS ? '.$iconName' : iconName,
    );
    _currentIcon = iconName;
  }

  /// 🚨 Force switch to Danger icon (Critical Telemetry)
  static Future<void> updateToCriticalIcon() async {
    await _ensureInitialized();
    try {
      if (!_isInitialized) return;
      if (_currentIcon == _iconDanger) return;
      await _switchIcon(_iconDanger);
    } catch (e) {
      print("⚠️ Icon critical skip: $e");
    }
  }

  /// 🟢 Force reset to Normal (Teal)
  static Future<void> updateToNormalIcon() async {
    await resetToDefault();
  }

  /// 🔄 Force reset to the default Teal icon
  static Future<void> resetToDefault() async {
    await _ensureInitialized();
    try {
      if (!_isInitialized) return;
      if (_currentIcon == _iconTeal) return;
      await _switchIcon(_iconTeal);
    } catch (e) {
      print("⚠️ Icon reset skipped: $e");
    }
  }
}
