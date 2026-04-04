import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String _androidWidgetName = 'SmridgeWidgetProvider';

  /// 📡 Syncs real-time sensor and protocol status to the Home Screen Widget
  static Future<void> updateWidgetData({
    required double temperature,
    required double humidity,
    required double freshness,
    required String doorStatus,
    required String status,
    String? inventoryJson,
    String? notificationsJson,
    String? timerTitle,
    int? targetTimestamp,
  }) async {
    try {
      // Save data for the widget to read
      await HomeWidget.saveWidgetData<String>('temp', '${temperature.toStringAsFixed(1)}°C');
      await HomeWidget.saveWidgetData<String>('hum', '${humidity.toStringAsFixed(1)}%');
      await HomeWidget.saveWidgetData<String>('freshness', '${(freshness * 10).toStringAsFixed(1)}/10');
      await HomeWidget.saveWidgetData<String>('door', doorStatus.toUpperCase());
      await HomeWidget.saveWidgetData<String>('status', 'PROTOCOL: ${status.toUpperCase()}');
      
      if (inventoryJson != null) {
        await HomeWidget.saveWidgetData<String>('inventory_json', inventoryJson);
      }
      if (notificationsJson != null) {
        await HomeWidget.saveWidgetData<String>('notifications_json', notificationsJson);
      }
      if (timerTitle != null) {
        await HomeWidget.saveWidgetData<String>('timer_title', timerTitle);
      }
      if (targetTimestamp != null) {
        await HomeWidget.saveWidgetData<int>('target_timestamp', targetTimestamp);
      }

      // Trigger a refresh of the native widget
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
      );
      await HomeWidget.updateWidget(androidName: 'DuolingoWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'PremiumWidgetProvider');
    } catch (e) {
      print("🚀 Smridge Widget Update Error: $e");
    }
  }

  /// 📦 Syncs inventory specific metrics if needed
  static Future<void> updateInventoryCount(int count) async {
    try {
       await HomeWidget.saveWidgetData<int>('item_count', count);
       await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      print("🚀 Smridge Widget Count Error: $e");
    }
  }

  /// ⏲️ Syncs a list of active timers to the specialized Chrono Widget
  static Future<void> updateTimerListWidget(String timerListJson) async {
    try {
      await HomeWidget.saveWidgetData<String>('timer_list_json', timerListJson);
      
      // Update all widgets
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
      await HomeWidget.updateWidget(androidName: 'DuolingoWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'PremiumWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'SmridgeChronoWidgetProvider');
    } catch (e) {
      print("🚀 Smridge Chrono Widget Error: $e");
    }
  }
}
