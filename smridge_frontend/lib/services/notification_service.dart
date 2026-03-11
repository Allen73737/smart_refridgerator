import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'audio_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../providers/fridge_customization_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
  }

  Future<void> showNotification(String title, String body, {BuildContext? context}) async {
    if (context != null) {
      final customizer = Provider.of<FridgeCustomizationProvider>(context, listen: false);
      bool isExpiry = title.toLowerCase().contains('expir') || body.toLowerCase().contains('expir');
      if (isExpiry) {
        AudioService.playNotification(index: customizer.expiryNotificationSoundIndex, customPath: customizer.customExpiryNotificationSoundPath);
      } else {
        AudioService.playNotification(index: customizer.notificationSoundIndex, customPath: customizer.customNotificationSoundPath);
      }
    } else {
      AudioService.playNotification();
    }

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
