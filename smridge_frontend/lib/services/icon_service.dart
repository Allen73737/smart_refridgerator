import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'dart:io';
import '../models/inventory_item.dart';

class IconService {
  static Future<void> updateAppIcon(List<InventoryItem> items) async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return;

      bool hasExpired = false;
      bool hasWarning = false;

      final now = DateTime.now();
      for (var item in items) {
        if (item.expiryDate.isBefore(now)) {
          hasExpired = true;
          break; // Danger is highest priority
        } else if (item.expiryDate.difference(now).inDays <= 2) {
          hasWarning = true;
        }
      }

      String? targetIcon;
      if (hasExpired) {
        targetIcon = 'MainActivityDanger';
      } else if (hasWarning) {
        targetIcon = 'MainActivityWarning';
      } else {
        targetIcon = null; // Default (MainActivity)
      }

      final currentIcon = await FlutterDynamicIconPlus.alternateIconName;
      
      if (currentIcon != targetIcon) {
        print("Changing app icon from $currentIcon to $targetIcon");
        await FlutterDynamicIconPlus.setAlternateIconName(
          iconName: targetIcon,
        );
      }
    } catch (e) {
      print("Failed to update app icon: $e");
    }
  }
}
