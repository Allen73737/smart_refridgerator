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
import 'services/notification_service.dart';
import 'providers/theme_provider.dart';
import 'providers/fridge_customization_provider.dart';
import 'config/app_themes.dart';
import 'config/app_settings.dart';

// 🔥 Background handler (required for notifications when app is closed)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("Handling background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔥 Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔥 Initialize Local Notifications
  await NotificationService().init();

  // 🔥 Handle Foreground Messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Received foreground message: ${message.notification?.title}");
    if (message.notification != null) {
      NotificationService().showNotification(
        message.notification!.title ?? "Smridge Alert",
        message.notification!.body ?? "",
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

    return MaterialApp(
      title: 'Smridge',
      debugShowCheckedModeBanner: false,
      theme: finalTheme,
      home: const SplashIntro(),
    );
  }
}
