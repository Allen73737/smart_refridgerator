import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'audio_service.dart';
import 'package:provider/provider.dart';
import '../providers/fridge_customization_provider.dart';
import 'api_service.dart';
import 'secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  // 🔔 Stream for deep-linking
  static final StreamController<String?> selectNotificationStream = StreamController<String?>.broadcast();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('ic_notif');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        print("🔔 Notification Clicked: ${response.payload}");
        selectNotificationStream.add(response.payload);
      },
    );

    // 🛡️ Request Permissions immediately for Android 13+
    await requestPermissions();
    
    // 🏗️ Pre-create Notification Channels for Android 8.0+
    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      // 🚀 RENAMED TO _v2 TO FORCE NEW REGISTRATION (fixes previously silenced channels)
      // 🚀 HARD RESET: Purge ALL previous channels to force-update Importance & Vibration settings
      // 🚀 NUCLEAR RESET (v5): Purge all previous channels to ensure fresh Importance & Vibration settings
      final channels = [
        'high_importance_channel_v5',
        'live_timer_channel_v5',
        'reminder_timer_channel_v5',
        'timer_end_channel_v5',
        // Purge legacy v3 and v4 as well
        'high_importance_channel_v3',
        'live_timer_channel_v4',
        'reminder_timer_channel_v4',
        'timer_end_channel_v4',
        'expiry_countdown_channel_v3',
        'expiry_scheduled_channel_v3',
        'custom_reminders_channel_v3'
      ];
      for (final c in channels) {
        await androidImplementation.deleteNotificationChannel(c);
      }
      
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'high_importance_channel_v5', 'Smridge Alerts', importance: Importance.max, description: 'Critical alerts', playSound: true, showBadge: true, enableVibration: true
      ));
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'live_timer_channel_v5', 'Smridge Live Timers', importance: Importance.max, description: 'Ongoing countdowns', playSound: true, showBadge: true, enableVibration: true
      ));
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'reminder_timer_channel_v5', 'Smridge Active Reminders', importance: Importance.max, description: 'Live reminder countdown', playSound: true, showBadge: true, enableVibration: true
      ));
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'timer_end_channel_v5', 'Smridge Alarms', importance: Importance.max, description: 'Timer finished alarm', playSound: true, enableVibration: true
      ));
      
      // 🧪 Trigger Vibration Diagnostic
      await showVibrationDebug();
    }


    tz.initializeTimeZones();
    await _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.toString())); 
      debugPrint("🕒 SMRIDGE: Timezone initialized to: $timeZoneInfo");
    } catch (e) {
      debugPrint("🕒 SMRIDGE: Fallback to Asia/Kolkata: $e");
      tz.setLocalLocation(tz.getLocation("Asia/Kolkata"));
    }
  }

  /// 🌏 Sync with User Profile Timezone
  Future<void> syncTimezone(String timezoneName) async {
    try {
      if (timezoneName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(timezoneName));
        debugPrint("🌏 SMRIDGE: Location Synced to Database: $timezoneName");
      }
    } catch (e) {
      debugPrint("🌏 SMRIDGE Sync Error: $e");
    }
  }

  Future<void> requestPermissions() async {
    try {
      // 1. FCM Permissions
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      print("🔔 FCM Permission Exception: $e");
    }

    try {
      // 2. Android 13+ Local Notification Permission
      final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        // Also request exact alarm permission if needed
        await androidImplementation.requestExactAlarmsPermission();
      }
    } catch (e) {
      print("🔔 Android Plugin Permission Exception: $e");
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
      try {
        final customizer = Provider.of<FridgeCustomizationProvider>(context, listen: false);
        bool isExpiry = title.toLowerCase().contains('expir') || body.toLowerCase().contains('expir');
        if (isExpiry) {
          AudioService.playNotification(index: customizer.expiryNotificationSoundIndex, customPath: customizer.customExpiryNotificationSoundPath);
        } else {
          AudioService.playNotification(index: customizer.notificationSoundIndex, customPath: customizer.customNotificationSoundPath);
        }
      } catch (e) {
        AudioService.playNotification();
      }
    } else {
      AudioService.playNotification();
    }

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel_v3',
      'Smridge Critical Alerts',
      importance: Importance.max,
      priority: Priority.max,
      icon: 'ic_notif',
      color: notificationColor, // 🔹 Status bar color support
      ledColor: notificationColor,
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final details = NotificationDetails(android: androidDetails);

    // 🎯 ID Safety: Use microseconds to ensure uniqueness in rapid iteration
    final int notifId = DateTime.now().microsecondsSinceEpoch.remainder(100000000);

    try {
      await _plugin.show(
        notifId,
        "🧊 SMRIDGE: $title",
        body,
        details,
      );
    } catch (e) {
      print("🔔 Error displaying standard notification: $e");
    }
  }

  /// ⏲️ Official OS-Level Live Timer Notification
  Future<void> showLiveTimer(String title, Duration duration, {int? itemId}) async {
    final targetTime = DateTime.now().add(duration).toLocal();
    final id = itemId ?? (title.hashCode.abs() % 1000000);

    final String timeStr = "${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}";
    
    final prefs = await SharedPreferences.getInstance();
    final bool enableVib = prefs.getBool('vibration_alerts_enabled') ?? true;

    final androidDetails = AndroidNotificationDetails(
      'live_timer_channel_v5',
      'Smridge Live Timers',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true, // 📌 Keeps it in the notification shade
      autoCancel: false, // 📌 Prevents tapping from dismissing it
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: true,
      when: targetTime.millisecondsSinceEpoch,
      icon: 'ic_notif',
      color: const Color(0xFF00FFD1),
      enableVibration: enableVib,
      vibrationPattern: enableVib ? Int64List.fromList([0, 500, 200, 500, 200, 500]) : null, // 🛠️ Extended pattern
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        "⏱️ <b>DEADLINE: <font color='#00FFD1'>$timeStr</font></b><br/><br/>Smridge 🧊 is tracking your item! Don't forget! 🚀",
        contentTitle: "⚡ LIVE SMRIDGE: $title",
        summaryText: "Smridge Tracker",
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
      'timer_end_channel_v5',
      'Smridge Alarms',
      importance: Importance.max,
      priority: Priority.max,
      icon: 'ic_notif',
      color: const Color(0xFFFF004D),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 2000, 500, 2000, 500, 2000, 500, 2000]),
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      "💥 BOOM! TIMER EXPIRED 🚨",
      "Your $title is done! Smridge 🧊 demands your attention! 🏃‍♂️",
      tz.TZDateTime.from(targetTime, tz.local),
      details,
      payload: 'inventory:$title',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showCountdownNotification(String itemName, DateTime expiry, {int? itemId}) async {
    final now = DateTime.now();
    final localExpiry = expiry.toLocal();
    final diff = localExpiry.difference(now);
    
    // 🔹 Only show if within 3 hours of expiry
    if (diff.isNegative || diff.inHours > 3) return;

    final String timeStr = "${localExpiry.hour.toString().padLeft(2, '0')}:${localExpiry.minute.toString().padLeft(2, '0')}";

    final androidDetails = AndroidNotificationDetails(
      'expiry_countdown_channel_v3',
      'Smridge Expiry Alerts',
      importance: Importance.max, 
      priority: Priority.max,
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
      itemId ?? itemName.hashCode, 
      "🚨 URGENT: $itemName ALERT",
      "Critical deadline at $timeStr! 😱",
      details,
      payload: 'inventory:$itemName',
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
      'expiry_scheduled_channel_v3',
      'Scheduled Smridge Alerts',
      importance: Importance.max,
      priority: Priority.max,
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
      payload: 'inventory:$itemName',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 🚀 Schedule a custom user reminder with Timer support
  Future<void> scheduleLocalReminder(int id, String itemName, DateTime scheduledDate, {String? imagePath}) async {
    final now = DateTime.now();
    final localScheduled = scheduledDate.isUtc ? scheduledDate.toLocal() : scheduledDate;

    // 🧊 Fix negative IDs and scale for safety
    final int safeId = id.abs() % 100000;

    // 🧹 HARD CANCEL any existing timers to prevent duplicates when updating
    await cancelNotification(safeId + 20000); 
    await cancelNotification(safeId + 50000); 
    await cancelNotification((safeId + 30000) % 100000000); 

    if (localScheduled.isBefore(now)) return;

    // 🧊 ALWAYS show a live timer notification in the shade when reminder is set
    await showReminderTimerNotification(safeId, itemName, localScheduled, imagePath: imagePath);
    // 🚀 Schedule the zero-point "Expired" alert
    await _scheduleTimerEndAlert(safeId + 50000, "🧊 Reminder: $itemName", localScheduled);

    final androidDetails = AndroidNotificationDetails(
      'custom_reminders_channel_v3',
      'Smridge Personal Reminders',
      importance: Importance.max,
      priority: Priority.max,
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
      safeId + 20000, 
      "👀 Smridge is watching: $itemName",
      "Check your $itemName now to keep Smridge happy! ✨",
      tz.TZDateTime.from(localScheduled, tz.local),
      details,
      payload: 'inventory:$itemName',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ⏲️ Ongoing Timer Notification for Reminders
  Future<void> showReminderTimerNotification(int id, String itemName, DateTime targetTime, {String? imagePath}) async {
    final now = DateTime.now();
    final diff = targetTime.difference(now);
    if (diff.isNegative) return;

    final String timeStr = "${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}";
    
    // 🎯 ID Safety: ensured within Android range
    final int safeId = (id.abs() + 30000) % 100000000;
    print("⏲️ Attempting to show premium reminder timer [ID: $safeId] for $itemName at $timeStr");

    // 🎨 UI: Determine LargeIcon (Item Image or Brand Icon)
    AndroidBitmap<Object>? largeIcon;
    if (imagePath != null && imagePath.isNotEmpty) {
      if (File(imagePath).existsSync()) {
        largeIcon = FilePathAndroidBitmap(imagePath);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final bool enableVib = prefs.getBool('vibration_alerts_enabled') ?? true;

    final androidDetails = AndroidNotificationDetails(
      'reminder_timer_channel_v5',
      'Smridge Active Reminders',
      importance: Importance.max, 
      priority: Priority.max,
      ongoing: true,
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: true,
      when: targetTime.millisecondsSinceEpoch,
      icon: 'ic_notif',
      largeIcon: largeIcon,
      color: const Color(0xFF00E5FF),
      enableVibration: enableVib,
      vibrationPattern: enableVib ? Int64List.fromList([0, 500, 200, 500, 200, 500]) : null,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        "⏱️ <b>DEADLINE APPROACHING: <font color='#00E5FF'>$itemName</font></b> at $timeStr<br/><br/>"
        "Smridge 🧊 is tracking your inventory! ✨🚀",
        contentTitle: "⚡ LIVE SMRIDGE TRACKER: $itemName",
        summaryText: "Smridge Active Protocol",
        htmlFormatContent: true,
        htmlFormatContentTitle: true,
      ),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'view_fridge',
          'OPEN FRIDGE 🧊',
          titleColor: const Color(0xFF00E5FF),
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'clear_timer',
          'DISMISS',
          cancelNotification: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);
    
    try {
      await _plugin.show(
        safeId, 
        "🧊⏳ REMINDER COUNTDOWN: $itemName",
        "Deadline set for $timeStr! ✨",
        details,
        payload: 'inventory:$itemName',
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

  // 🧪 DIAGNOSTIC: Test Notification
  Future<void> showTestNotification() async {
    // 🛡️ Extra check on every test
    await requestPermissions();

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel_v3',
      'Smridge Critical Alerts',
      importance: Importance.max,
      priority: Priority.max,
      icon: 'ic_notif',
      color: Color(0xFF00F2FF),
      fullScreenIntent: true,
    );
    const details = NotificationDetails(android: androidDetails);
    
    await _plugin.show(
      888, 
      "🧊 SMRIDGE: System Test",
      "If you see this, notifications are working perfectly! 🚀",
      details,
    );
    print("✅ Test notification pushed successfully.");
  }

  // 🗑️ Clear all scheduled notifications
  Future<void> cancelAllScheduled() async {
    await _plugin.cancelAll();
  }

  // 🧪 DIAGNOSTIC: Force Vibration on launch
  Future<void> showVibrationDebug() async {
    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel_v5',
      'Smridge Alerts',
      importance: Importance.max,
      priority: Priority.max,
      icon: 'ic_notif',
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 400, 500, 200, 500]), // 📳 DOUBLE PULSE
    );
    final details = NotificationDetails(android: androidDetails);
    
    await _plugin.show(
      999, 
      "📳 SMRIDGE VIBRATION TEST",
      "If the device is vibrating, your notification system is working perfectly! 🚀",
      details,
    );
    print("✅ Startup vibration test pushed successfully.");
  }
}
