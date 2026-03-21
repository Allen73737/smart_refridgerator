import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'audio_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../providers/fridge_customization_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
  }

  Future<void> requestPermissions() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional notification permission');
    } else {
      print('User declined or has not accepted notification permission');
    }
  }

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  void listenToTokenRefresh(Function(String) onRefresh) {
    _fcm.onTokenRefresh.listen(onRefresh);
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

  Future<void> showCountdownNotification(String itemName, DateTime expiry) async {
    final diff = expiry.difference(DateTime.now());
    if (diff.isNegative) return;

    final androidDetails = AndroidNotificationDetails(
      'expiry_countdown_channel',
      'Expiry Countdown',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showWhen: true,
      usesChronometer: true,
      when: expiry.millisecondsSinceEpoch,
      chronometerCountDown: true,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);
    
    await _plugin.show(
      999, // Static ID for countdown
      "Expiry Countdown",
      "'$itemName' will expire in some time",
      details,
    );
  }
}
