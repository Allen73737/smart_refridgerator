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
import 'package:vibration/vibration.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  // 🔔 Stream for deep-linking
  static final StreamController<String?> selectNotificationStream = StreamController<String?>.broadcast();
  
  // 🚨 Emergency Stream for foreground alerts
  static final StreamController<String> expiredTimerStream = StreamController<String>.broadcast();

  // 🎯 Stable ID Logic (Cross-platform hashing matches backend)
  int getStableId(String name) {
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = ((hash << 5) - hash) + name.codeUnitAt(i);
      hash |= 0; // Convert to 32bit integer
    }
    return hash.abs() % 100000;
  }

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
      debugPrint("🔔 SMRIDGE NOTIF: Initializing Urgent Protocol v11...");
      // 🚀 NUCLEAR CLEANUP: Clear all legacy channel IDs
      final channels = [
        'smridge_protocol_v10',
        'smridge_protocol_v9',
        'smridge_protocol_v6',
        'high_importance_channel_v5',
        'live_timer_channel_v5',
        'reminder_timer_channel_v5',
        'timer_end_channel_v5',
        'expiry_countdown_channel_v5',
        'expiry_scheduled_channel_v5',
        'custom_reminders_channel_v5',
        'high_importance_channel_v3',
        'smridge_urgent_v9',
        'smridge_urgent_v8',
        'smridge_urgent_v7',
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
      
      // 🛡️ URGENT PROTOCOL: Ensuring 100% visibility on Samsung One UI
      // 💡 Vibration must be defined STABLE in the channel for Android 8.0+
      await androidImplementation.createNotificationChannel(AndroidNotificationChannel(
        'smridge_urgent_v15', 
        'Smridge Emergency Protocol', 
        importance: Importance.max, 
        description: 'Time-critical inventory updates (v15)', 
        playSound: true, 
        sound: const RawResourceAndroidNotificationSound('smridge_alarm'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
        enableLights: true,
        ledColor: const Color(0xFFFFAB00),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ));
      
      debugPrint("✅ SMRIDGE NOTIF: Urgent Protocol (v15) initialized.");
      // 🧪 Trigger Vibration Diagnostic
      await showVibrationDebug();
    }

    tz.initializeTimeZones();
    await _initializeLocation();
    
    debugPrint("✅ SMRIDGE NOTIF: Initialization complete.");
  }

  // 📡 FCM Token Management
  Future<String?> getToken() => _fcm.getToken();

  void listenToTokenRefresh(void Function(String) onRefresh) {
    _fcm.onTokenRefresh.listen(onRefresh);
  }

  Future<void> _initializeLocation() async {
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.toString())); 
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  Future<void> showNotification(String title, String body, {int? id, String? payload, BuildContext? context, String? colorHex}) async {
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
      } catch (e) {}
    }

    final androidDetails = AndroidNotificationDetails(
      'smridge_urgent_v15',
      'Smridge Emergency Protocol',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      icon: 'ic_notif',
      color: notificationColor,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('smridge_alarm'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 2000, 500, 2000]),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    final details = NotificationDetails(android: androidDetails);
    
    // 🛡️ DEDUPLICATION: Use stable ID from title if none provided
    final int notifId = id ?? getStableId(title);

    await _plugin.show(
      notifId,
      "🧊 SMRIDGE: $title",
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showFCMNotification(RemoteMessage message) async {
    final String title = message.notification?.title ?? message.data['title'] ?? "Smridge Alert";
    final String body = message.notification?.body ?? message.data['body'] ?? "";
    final String? color = message.data['color'];
    
    // Construct deep-linking payload from arbitrary FCM data
    String? payload = message.data['payload'];
    if (payload == null && message.data.containsKey('route')) {
      payload = '{"route": "${message.data['route']}", "recordedWeight": "${message.data['recordedWeight'] ?? ""}"}';
    }
    
    // 🛡️ Aligned ID from backend payload for deduplication
    // 💡 IMPORTANT: If type is 'expiry', we MUST use the stable item name ID to replace trackers
    int? idFromBackend = int.tryParse(message.data['notificationId']?.toString() ?? "");
    final String type = message.data['type']?.toString().toLowerCase() ?? "";
    
    if (idFromBackend == null && (type == 'expiry' || type == 'reminder')) {
       final itemName = title.split(':').last.trim();
       idFromBackend = getStableId(itemName) + 1000000; // Match showLiveTimer trackerId
    }

    await showNotification(
      title,
      body,
      id: idFromBackend,
      colorHex: color,
      payload: payload,
    );
  }

  Future<void> setupFCM(BuildContext context) async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _fcm.getToken();
      if (token != null) {
        final authToken = await SecureStorageService.getToken();
        if (authToken != null) {
          await ApiService.saveFcmToken(token, authToken);
        }
      }
    }

    FirebaseMessaging.onMessage.listen((message) {
      showFCMNotification(message);
    });

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    // 🛡️ DEDUPLICATION: If the FCM has a notification object, Android already showed it.
    // We only manual-trigger if it's a pure data message (like a silent sync or custom layout).
    if (message.notification != null) {
       print("📌 System already handled notification: ${message.messageId}");
       return; 
    }

    final service = NotificationService();
    await service.init(); 
    print("🚀 Handling background DATA message: ${message.messageId}");
    await service.showFCMNotification(message);
  }

  Future<void> cancelAllForItem(String itemName) async {
    final int baseId = getStableId(itemName);
    await _plugin.cancel(baseId + 1000000); // Tracker / Alert (v15+)
    await _plugin.cancel(baseId + 10000);   // Legacy Tracker ID
    await _plugin.cancel(baseId + 20000);   // Legacy Alert ID
  }

  Future<void> showLiveTimer(String itemName, DateTime expiry) async {
    final now = DateTime.now();
    final localExpiry = expiry.isUtc ? expiry.toLocal() : expiry;
    final int baseId = getStableId(itemName);
    final int trackerId = baseId + 1000000;
    
    if (localExpiry.isBefore(now)) return;

    final androidDetails = AndroidNotificationDetails(
      'smridge_urgent_v15',
      'Smridge Emergency Protocol',
      importance: Importance.max,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: true,
      when: localExpiry.millisecondsSinceEpoch,
      icon: 'ic_notif',
      color: const Color(0xFFFF004D),
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      groupKey: 'com.example.smridge.TIMERS',
      groupAlertBehavior: GroupAlertBehavior.all,
      timeoutAfter: localExpiry.difference(now).inMilliseconds,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('smridge_alarm'),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'dismiss_timer',
          'DISMISS',
          cancelNotification: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);
    
    try {
      await _plugin.show(
        trackerId, 
        "🚨 LIVE EXPIRY: $itemName",
        "Critical deadline at ${localExpiry.hour}:${localExpiry.minute}! 😱",
        details,
        payload: 'inventory:$itemName',
      );
    } catch (e) {
      debugPrint("❌ SMRIDGE NOTIF Error: $e");
    }
    
    // 🚨 Schedule intensive foreground alert
    await _scheduleTimerEndAlert(trackerId, itemName, localExpiry, shadeId: trackerId);
  }

  Future<void> _scheduleTimerEndAlert(int id, String title, DateTime targetTime, {int? shadeId}) async {
    final androidDetails = AndroidNotificationDetails(
      'smridge_urgent_v15',
      'Smridge Emergency Protocol',
      importance: Importance.max,
      priority: Priority.max,
      icon: 'ic_notif',
      color: const Color(0xFFFF004D),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 2000, 500, 2000, 500, 2000, 500, 2000]),
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('smridge_alarm'),
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id, // 🎯 Use the tracker ID so the ALARM replaces the COUNTDOWN
      title.contains(":") ? title : "Item Expired: $title",
      "Your ${title.contains(":") ? title.split(":").last.trim() : title} is done! Smridge 🧊 demands your attention! 🏃‍♂️",
      tz.TZDateTime.from(targetTime, tz.local),
      details,
      payload: 'inventory:$title',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    // 🚨 For foreground UI & Clean Disposal
    Timer(targetTime.difference(DateTime.now()), () {
      if (shadeId != null) _plugin.cancel(shadeId);
      expiredTimerStream.add(title);
    });
  }

  Future<void> showCountdownNotification(String itemName, DateTime expiry, {int? itemId}) async {
    final now = DateTime.now();
    final localExpiry = expiry.toLocal();
    final diff = localExpiry.difference(now);
    
    if (diff.isNegative || diff.inHours > 72) return;

    final String timeStr = "${localExpiry.hour.toString().padLeft(2, '0')}:${localExpiry.minute.toString().padLeft(2, '0')}";
    final int baseId = (itemId ?? getStableId(itemName));
    final int trackerId = baseId + 1000000;

    final androidDetails = AndroidNotificationDetails(
      'smridge_urgent_v15',
      'Smridge Emergency Protocol',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: true,
      when: localExpiry.millisecondsSinceEpoch,
      icon: 'ic_notif',
      color: const Color(0xFFFF004D), 
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      groupKey: 'com.example.smridge.TIMERS',
      groupAlertBehavior: GroupAlertBehavior.all,
      timeoutAfter: localExpiry.difference(now).inMilliseconds,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('smridge_alarm'),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'dismiss_timer',
          'DISMISS',
          cancelNotification: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);
    
    try {
      await _plugin.show(
        trackerId, 
        "🚨 LIVE EXPIRY: $itemName",
        "Critical deadline at $timeStr! 😱",
        details,
        payload: 'inventory:$itemName',
      );
    } catch (e) {}
  }

  Future<void> scheduleExpiryNotification(int id, String itemName, DateTime expiryDate) async {
    final now = DateTime.now();
    final localExpiry = expiryDate.isUtc ? expiryDate.toLocal() : expiryDate;
    final scheduledDate = localExpiry.subtract(const Duration(hours: 3));
    
    if (scheduledDate.isBefore(now)) return;

    final androidDetails = AndroidNotificationDetails(
      'smridge_urgent_v15',
      'Smridge Emergency Protocol',
      importance: Importance.max,
      priority: Priority.max,
      icon: 'ic_notif',
      color: const Color(0xFF00F2FF),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      "Expiry Warning: $itemName",
      "Hey! 👋 Don't forget about your **$itemName**! It's expiring soon. Time for a delicious meal! 😭🧊",
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      payload: 'inventory:$itemName',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleLocalReminder(int id, String itemName, DateTime scheduledDate, {String? imagePath}) async {
    final now = DateTime.now();
    final localScheduled = scheduledDate.isUtc ? scheduledDate.toLocal() : scheduledDate;
    final int baseId = id; // 🛡️ Use the passed ID (from HomeScreen stableId)

    // 🚀 CLEAR ANY OLD ALARM FOR THIS ITEM
    await _plugin.cancel(baseId + 10000); 
    await _plugin.cancel(baseId + 20000); 

    if (localScheduled.isBefore(now)) return;

    await showReminderTimerNotification(baseId, itemName, localScheduled, imagePath: imagePath);
    // 🛡️ Pass baseId + 1000000 so the alarm replaces the tracker
    await _scheduleTimerEndAlert(baseId + 1000000, itemName, localScheduled, shadeId: baseId + 1000000);
  }

  Future<void> showReminderTimerNotification(int id, String itemName, DateTime targetTime, {String? imagePath}) async {
    final now = DateTime.now();
    if (targetTime.isBefore(now)) return;

    final String timeStr = "${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}";
    final int baseId = id; 
    final int trackerId = baseId + 1000000;

    AndroidBitmap<Object>? largeIcon;
    if (imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()) {
      largeIcon = FilePathAndroidBitmap(imagePath);
    }

    final androidDetails = AndroidNotificationDetails(
      'smridge_urgent_v15',
      'Smridge Emergency Protocol',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: true,
      when: targetTime.millisecondsSinceEpoch,
      icon: 'ic_notif',
      largeIcon: largeIcon,
      color: const Color(0xFF00E5FF),
      enableVibration: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('smridge_alarm'),
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      timeoutAfter: targetTime.difference(now).inMilliseconds,
      styleInformation: BigTextStyleInformation(
        "⏱️ <b>DEADLINE APPROACHING: <font color='#00E5FF'>$itemName</font></b> at $timeStr",
        contentTitle: "⚡ LIVE SMRIDGE TRACKER: $itemName",
        htmlFormatContent: true,
        htmlFormatContentTitle: true,
      ),
    );

    final details = NotificationDetails(android: androidDetails);
    
    try {
      await _plugin.show(
        trackerId, 
        "🧊⏳ REMINDER: $itemName",
        "Deadline at $timeStr! ✨",
        details,
        payload: 'inventory:$itemName',
      );
    } catch (e) {
      print("❌ Error: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> showVibrationDebug() async {
    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
        final androidDetails = AndroidNotificationDetails(
          'smridge_urgent_v15',
          'Smridge Emergency Protocol',
          importance: Importance.max,
          priority: Priority.max,
          icon: 'ic_notif',
          enableVibration: true,
        );
        final details = NotificationDetails(android: androidDetails);
        
        await _plugin.show(
          999, 
          "📳 SMRIDGE VIBRATION TEST",
          "If the device is vibrating, it works! 🚀",
          details,
        );
    }
  }
}
