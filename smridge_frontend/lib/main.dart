import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'screens/splash_intro.dart';
import 'screens/home_screen.dart';
import 'services/secure_storage_service.dart';
import 'services/api_service.dart'; // 🔹 Added
import 'services/notification_service.dart';
import 'services/socket_service.dart'; // 🔹 Added
import 'services/haptic_service.dart'; // 🔹 New
import 'providers/theme_provider.dart';
import 'providers/fridge_customization_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/sensor_provider.dart'; // 🚀 Added
import 'config/app_themes.dart';
import 'config/app_settings.dart';

// 🔥 Global Navigator Key for Deep Linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🔥 Background handler (required for notifications when app is closed)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase already initialized by native layer — safe to ignore
  }
  print("Handling background message: ${message.messageId}");
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 Cold Start Mitigation: Wake up the cloud backend immediately in the background
  ApiService.wakeUpBackend();

  // 🔥 1. Initialize Firebase first (Mandatory for NotificationService)
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase Initialization Status: $e');
  }

  // 🔥 2. Parallel initialization of other core services
  await Future.wait([
    HapticService.init(),
    ApiService.initializeBackend(),
  ]);

  // 🔥 3. Initialize Notifications after Firebase is guaranteed to be ready
  await NotificationService().init();

  // 🔥 Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔥 Allow Foreground Notifications (Heads Up)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // 🔥 Initialize Sockets with the correct URL (Must happen after ApiService.initializeBackend)
  SocketService.init();

  // 🔥 Handle Foreground Messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Received foreground message: ${message.notification?.title}");
    if (message.notification != null) {
      final color = message.data['color']; // 🔹 Extract color from data payload
      NotificationService().showNotification(
        message.notification!.title ?? "Smridge Alert",
        message.notification!.body ?? "",
        colorHex: color,
      );
    }
  });

  // Fetch admin-set minimum thresholds from backend (non-blocking)
  AppSettings.fetchAdminThresholds();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) {
          final provider = FridgeCustomizationProvider();
          provider.loadFromPrefs();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => SensorProvider()), // 🚀 Added
      ],
      child: const SmridgeApp(),
    ),
  );
}

class SmridgeApp extends StatelessWidget {
  const SmridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    ThemeData activeTheme;
    
    switch (themeProvider.currentTheme) {
      case ThemeType.light:
        activeTheme = AppThemes.lightTheme;
        break;
      case ThemeType.dark:
        activeTheme = AppThemes.darkTheme;
        break;
      case ThemeType.defaultTheme:
      default:
        activeTheme = AppThemes.defaultTheme;
        break;
    }

    // Apply global font on top of the active theme
    ThemeData finalTheme = activeTheme.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(
        activeTheme.textTheme.apply(
          bodyColor: themeProvider.currentTheme == ThemeType.light ? Colors.black87 : Colors.white,
          displayColor: themeProvider.currentTheme == ThemeType.light ? Colors.black87 : Colors.white,
        ),
      ),
    );

    return GestureDetector(
      onTapDown: (_) => HapticService.light(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Smridge',
        debugShowCheckedModeBanner: false,
        theme: finalTheme.copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: const SplashIntro(),
      ),
    );
  }
}
