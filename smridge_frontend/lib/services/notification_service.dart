import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'audio_service.dart';
import 'package:provider/provider.dart';
import '../providers/fridge_customization_provider.dart';
import 'api_service.dart';
import 'secure_storage_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('ic_notif');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
    
    // 🕒 Initialize Timezones for Background Scheduling
    tz.initializeTimeZones();
    
    try {
      // 🌓 Resilient Timezone Detection
      final now = DateTime.now();
      final offset = now.timeZoneOffset.inMinutes;

      // Common mappings for UTC offsets to IANA names
      String zoneName = "UTC";
      if (offset == 330) zoneName = "Asia/Kolkata";
      else if (offset == 0) zoneName = "UTC";
      else if (offset == -300) zoneName = "America/New_York";
      else if (offset == -480) zoneName = "America/Los_Angeles";
      else if (offset == 60) zoneName = "Europe/London";
      else if (offset == 120) zoneName = "Europe/Paris";
      else if (offset == 480) zoneName = "Asia/Shanghai";
      else if (offset == 540) zoneName = "Asia/Tokyo";
      else {
        // 🔹 Generic offset-based location if not in common list
        final hours = offset ~/ 60;
        final mins = offset % 60;
        zoneName = "Etc/GMT${hours >= 0 ? '-' : '+'}${hours.abs()}";
      }
      
      tz.setLocalLocation(tz.getLocation(zoneName));
      print("🕒 Timezone initialized to: $zoneName (Offset: $offset mins)");
    } catch (e) {
      print("⚠️ Timezone detection failed, falling back to UTC: $e");
      tz.setLocalLocation(tz.getLocation("UTC"));
    }
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
    _fcm.onTokenRefresh.listen((token) {
       onRefresh(token);
       syncToken(token);
    });
  }

  // 📡 Sync token to backend
  Future<void> syncToken(String fcmToken) async {
    final token = await SecureStorageService.getToken();
    if (token != null) {
      await ApiService.saveFcmToken(fcmToken, token);
      print("📡 FCM Token Synced to Backend");
    }
  }

  // 🚀 Top-level background message handler for FCM
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("🚀 Handling background message: ${message.messageId}");
    // Note: On Android, if the 'notification' property is present in the payload, 
    // the system naturally displays it. For 'data' only messages, we would handle manually.
  }

  Future<void> showNotification(String title, String body, {BuildContext? context, String? colorHex}) async {
    Color? notificationColor;
    if (colorHex != null) {
      try {
        final hex = colorHex.replaceAll('#', '0xFF');
        notificationColor = Color(int.parse(hex));
      } catch (e) {}
    }

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

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notif',
      color: notificationColor, // 🔹 Status bar color support
      ledColor: notificationColor,
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  Future<void> showCountdownNotification(String itemName, DateTime expiry) async {
    final now = DateTime.now();
    final diff = expiry.difference(now);
    
    // 🔹 Only show if within 3 hours of expiry
    if (diff.isNegative || diff.inHours > 3) return;

    final androidDetails = AndroidNotificationDetails(
      'expiry_countdown_channel',
      'Expiry Countdown',
      importance: Importance.max, 
      priority: Priority.high,
      fullScreenIntent: diff.inHours < 1, // 🚀 Disruptive alert for < 1 hour
      ongoing: true,
      showWhen: true,
      usesChronometer: true,
      when: expiry.millisecondsSinceEpoch,
      chronometerCountDown: true,
      icon: 'ic_notif',
      color: const Color(0xFFFF004D), // 🚨 High-Impact Warning Red
      ledColor: const Color(0xFFFF004D),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: BigTextStyleInformation(
        "🚨 **ULTRASONIC WARNING**: Your **$itemName** is reaching its expiration point! ⏳\n\nTake immediate action to utilize this item before it goes to waste. Smridge AI recommends immediate consumption.",
        contentTitle: "⚡ EXPIRE ALERT: $itemName",
        summaryText: "Smridge Freshness Protocol",
        htmlFormatContent: true,
        htmlFormatContentTitle: true,
      ),
      ticker: "Smridge Urgent Alert: $itemName",
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    final details = NotificationDetails(android: androidDetails);
    
    await _plugin.show(
      itemName.hashCode, // 🔹 Unique ID per item to allow multiple timers
      "⚡ EXPIRE ALERT: $itemName",
      "Expiring in less than ${diff.inHours + 1} hours!",
      details,
    );
  }

  // 🚀 Schedule background notification for expiry
  Future<void> scheduleExpiryNotification(int id, String itemName, DateTime expiryDate) async {
    final now = DateTime.now();
    
    // 🔹 Ensure we use absolute local time for comparison and scheduling
    final localExpiry = expiryDate.isUtc ? expiryDate.toLocal() : expiryDate;
    final scheduledDate = localExpiry.subtract(const Duration(hours: 3));
    
    if (scheduledDate.isBefore(now)) return;

    final androidDetails = AndroidNotificationDetails(
      'expiry_scheduled_channel',
      'Scheduled Expiry Alerts',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notif',
      color: const Color(0xFF00F2FF),
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      "🚨 Stay Fresh!",
      "Reminder: Your **$itemName** is expiring in 3 hours. Plan your meal! 🥗",
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 🚀 Schedule a custom user reminder with Timer support
  Future<void> scheduleLocalReminder(int id, String itemName, DateTime scheduledDate) async {
    final now = DateTime.now();
    final localScheduled = scheduledDate.isUtc ? scheduledDate.toLocal() : scheduledDate;

    if (localScheduled.isBefore(now)) return;

    // 🔹 If the reminder is within 1 hour, show a real-time timer notification in the shade
    final diff = localScheduled.difference(now);
    if (diff.inHours < 1) {
      await showReminderTimerNotification(id, itemName, localScheduled);
    }

    final androidDetails = AndroidNotificationDetails(
      'custom_reminders_channel',
      'Personal Reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notif',
      color: const Color(0xFFFFAB00), 
      styleInformation: BigTextStyleInformation(
        "🔔 **REMINDER**: It's time to check on your **$itemName**! 🥗\n\nYou set this reminder to stay on top of your fridge inventory.",
        contentTitle: "⏰ Smridge Reminder: $itemName",
        summaryText: "Smridge Personal Protocol",
        htmlFormatContent: true,
        htmlFormatContentTitle: true,
      ),
      category: AndroidNotificationCategory.reminder,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id + 20000, 
      "⏰ Reminder: $itemName",
      "Smridge Reminder: Check your $itemName now!",
      tz.TZDateTime.from(localScheduled, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ⏲️ Ongoing Timer Notification for Reminders
  Future<void> showReminderTimerNotification(int id, String itemName, DateTime targetTime) async {
    final now = DateTime.now();
    final diff = targetTime.difference(now);
    if (diff.isNegative) return;

    final androidDetails = AndroidNotificationDetails(
      'reminder_timer_channel',
      'Active Reminders',
      importance: Importance.low, // Lower importance so it doesn't keep buzzing
      priority: Priority.low,
      ongoing: true,
      showWhen: true,
      usesChronometer: true,
      when: targetTime.millisecondsSinceEpoch,
      chronometerCountDown: true,
      icon: 'ic_notif',
      color: const Color(0xFFFFAB00),
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
    );

    final details = NotificationDetails(android: androidDetails);
    
    await _plugin.show(
      id + 30000, 
      "⏳ Reminder Timer: $itemName",
      "Due in approximately ${diff.inMinutes} minutes",
      details,
    );
  }

  // 🗑️ Clear all scheduled notifications
  Future<void> cancelAllScheduled() async {
    await _plugin.cancelAll();
  }
}
