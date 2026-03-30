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

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        print("🔔 Notification Clicked: ${response.payload}");
      },
    );
    
    // 🏗️ Pre-create Notification Channels for Android 8.0+
    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'high_importance_channel', 'High Importance Alerts', importance: Importance.max, description: 'Critical fridge alerts'
      ));
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'live_timer_channel', 'Active Kitchen Timers', importance: Importance.max, description: 'Ongoing countdowns'
      ));
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'expiry_countdown_channel', 'Expiry Enforcement', importance: Importance.max, description: 'Final warnings'
      ));
      // 🔔 Previously missing channels — now registered
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'timer_end_channel', 'Timer Completion Alerts', importance: Importance.max, description: 'Timer finished alarm'
      ));
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'expiry_scheduled_channel', 'Scheduled Expiry Alerts', importance: Importance.max, description: '3-hour expiry warning'
      ));
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'custom_reminders_channel', 'Personal Reminders', importance: Importance.max, description: 'User-set item reminders'
      ));
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'reminder_timer_channel', 'Active Reminders', importance: Importance.max, description: 'Live reminder countdown'
      ));
    }


    // 🕒 Initialize Timezones for Background Scheduling
    tz.initializeTimeZones();
    
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset.inMinutes;
      String zoneName = "Asia/Kolkata"; // Default
      if (offset == 330) zoneName = "Asia/Kolkata";
      else if (offset == 0) zoneName = "UTC";
      else if (offset == -300) zoneName = "America/New_York";
      else if (offset == -480) zoneName = "America/Los_Angeles";
      else {
        final hours = offset ~/ 60;
        zoneName = "Etc/GMT${hours >= 0 ? '-' : '+'}${hours.abs()}";
      }
      
      tz.setLocalLocation(tz.getLocation(zoneName));
      print("🕒 Timezone initialized to: $zoneName");
    } catch (e) {
      tz.setLocalLocation(tz.getLocation("UTC"));
    }
  }

  Future<void> requestPermissions() async {
    // 1. FCM Permissions
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 2. Android 13+ Local Notification Permission
    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      // Also request exact alarm permission if needed
      await androidImplementation.requestExactAlarmsPermission();
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

    // 🎯 ID Safety: modulo 100M to keep within Android Int32 range
    final int notifId = (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 100000000;

    await _plugin.show(
      notifId,
      "🧊 SMRIDGE: $title",
      body,
      details,
    );
  }

  /// ⏲️ Official OS-Level Live Timer Notification
  Future<void> showLiveTimer(String title, Duration duration) async {
    final targetTime = DateTime.now().add(duration);
    final id = 999;

    final String timeStr = "${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}";
    
    final androidDetails = AndroidNotificationDetails(
      'live_timer_channel',
      'Active Kitchen Timers',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      showWhen: true,
      icon: 'ic_notif',
      color: const Color(0xFF00FFD1),
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        "⏱️ <b>STRICT DEADLINE: <font color='#00FFD1'>$timeStr</font></b><br/><br/>Smridge 🧊 is watching your kitchen with eagle eyes!👀 Don't let your food down! 🚀",
        contentTitle: "⚡ LIVE SMRIDGE TRACKER: $title",
        summaryText: "Smridge Kitchen Protocol",
        htmlFormatContent: true,
        htmlFormatContentTitle: true,
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id, 
      "⚡ Smridge Tracker: $title",
      "Counting down to $timeStr... 🧊👀",
      details,
    );

    // 🚀 Schedule the "Expired" alert for when the timer hits zero
    // 🎯 ID Safety: +1 relative to the main timer ID
    await _scheduleTimerEndAlert((id + 1) % 100000000, title, targetTime);
  }

  Future<void> _scheduleTimerEndAlert(int id, String title, DateTime targetTime) async {
    final androidDetails = AndroidNotificationDetails(
      'timer_end_channel',
      'Timer Completion Alerts',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notif',
      color: const Color(0xFFFF004D),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      "💥 BOOM! TIMER EXPIRED 🚨",
      "Your $title is done! Smridge 🧊 demands your attention! 🏃‍♂️",
      tz.TZDateTime.from(targetTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showCountdownNotification(String itemName, DateTime expiry) async {
    final now = DateTime.now();
    final diff = expiry.difference(now);
    
    // 🔹 Only show if within 3 hours of expiry
    if (diff.isNegative || diff.inHours > 3) return;

    final String timeStr = "${expiry.hour.toString().padLeft(2, '0')}:${expiry.minute.toString().padLeft(2, '0')}";

    final androidDetails = AndroidNotificationDetails(
      'expiry_countdown_channel',
      'Expiry Countdown',
      importance: Importance.max, 
      priority: Priority.high,
      fullScreenIntent: diff.inHours < 1, 
      ongoing: true,
      showWhen: true,
      icon: 'ic_notif',
      color: const Color(0xFFFF004D), 
      ledColor: const Color(0xFFFF004D),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: BigTextStyleInformation(
        "🥶 <b>SMRIDGE IS SAD</b>: Your <b>$itemName</b> is dying! 😱<br/><br/>Deadline: <b><font color='#FF004D'>$timeStr</font></b>. Eat it or Smridge will never forgive you! 😭😭🧊",
        contentTitle: "🚨 URGENT: $itemName ALERT",
        summaryText: "Smridge Freshness Enforcement",
        htmlFormatContent: true,
        htmlFormatContentTitle: true,
      ),
      ticker: "Smridge Urgent Alert: $itemName",
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    final details = NotificationDetails(android: androidDetails);
    
    await _plugin.show(
      itemName.hashCode, 
      "🚨 URGENT: $itemName ALERT",
      "Critical deadline at $timeStr! 😱",
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
      "🥶 Smridge misses you!",
      "Hey! 👋 Don't forget about your **$itemName**! It's expiring in 3 hours. Time for a delicious meal or Smridge will cry! 😭🧊",
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

    // 🧊 ALWAYS show a live timer notification in the shade when reminder is set
    await showReminderTimerNotification(id, itemName, localScheduled);
    // 🚀 Schedule the zero-point "Expired" alert
    await _scheduleTimerEndAlert(id + 50000, "🧊 Reminder: $itemName", localScheduled);

    final androidDetails = AndroidNotificationDetails(
      'custom_reminders_channel',
      'Personal Reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notif',
      color: const Color(0xFFFFAB00), 
      groupKey: 'smridge_reminders',
      styleInformation: BigTextStyleInformation(
        "🧊 **KNOCK KNOCK**: It's time to check on your **$itemName**! 🥗\n\nMake Smridge proud by staying on top of your premium inventory! ✨",
        contentTitle: "👀 Smridge is watching: $itemName",
        summaryText: "Smridge Reminders",
        htmlFormatContent: true,
        htmlFormatContentTitle: true,
      ),
      category: AndroidNotificationCategory.reminder,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id + 20000, 
      "👀 Smridge is watching: $itemName",
      "Check your $itemName now to keep Smridge happy! ✨",
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

    final String timeStr = "${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}";
    
    // 🎯 ID Safety: ensured within Android range
    final int safeId = (id + 30000) % 100000000;
    print("⏲️ Attempting to show reminder timer [ID: $safeId] for $itemName at $timeStr");

    final androidDetails = AndroidNotificationDetails(
      'reminder_timer_channel',
      'Active Reminders',
      importance: Importance.max, 
      priority: Priority.high,
      ongoing: true,
      showWhen: true,
      icon: 'ic_notif',
      color: const Color(0xFFFFAB00),
      groupKey: 'smridge_timers',
      onlyAlertOnce: true, // Don't beep every update
      styleInformation: BigTextStyleInformation(
        "👀 <b>SMRIDGE IS TRACKING</b>: Deadline at <b><font color='#FFAB00'>$timeStr</font></b><br/><br/>Your reminder for <b>$itemName</b> is ticking! Smridge 🧊 hates tardiness! 🥗✨",
        contentTitle: "⚡ TARGET REACHED: $itemName",
        summaryText: "Smridge Active Protocol",
        htmlFormatContent: true,
        htmlFormatContentTitle: true,
      ),
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
    );

    final details = NotificationDetails(android: androidDetails);
    
    try {
      await _plugin.show(
        safeId, 
        "🧊⏳ TARGET REACHED: $itemName",
        "Deadline set for $timeStr! ✨",
        details,
      );
      print("✅ Reminder timer notification pushed successfully.");
    } catch (e) {
      print("❌ Error showing reminder timer notification: $e");
    }
  }

  // 🗑️ Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  // 🗑️ Clear all scheduled notifications
  Future<void> cancelAllScheduled() async {
    await _plugin.cancelAll();
  }
}
