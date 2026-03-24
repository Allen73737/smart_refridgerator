import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Added for .animate()
import 'package:google_fonts/google_fonts.dart'; // Added for GoogleFonts
import 'login_screen.dart';
import 'home_screen.dart';
import 'add_device_screen.dart';
import '../core/page_transitions.dart';
import '../services/audio_service.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/secure_storage_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class SplashIntro extends StatefulWidget {
  const SplashIntro({Key? key}) : super(key: key);

  @override
  State<SplashIntro> createState() => _SplashIntroState();
}

class _SplashIntroState extends State<SplashIntro>
    with TickerProviderStateMixin {

  late AnimationController _logoController;

  late Animation<double> _logoSlide;
  late Animation<double> _logoFade;

  String titleText = "";
  String taglineText = "";

  final String fullTitle = "Smridge";
  final String fullTagline = "Where vision meets refrigeration";

  @override
  void initState() {
    super.initState();

    /// Logo Slide Animation
    _logoController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));

    _logoSlide = Tween<double>(begin: 200, end: 0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Start slightly faster since we removed the 2s door constraint
    await Future.delayed(const Duration(milliseconds: 300));

    AudioService.playLogoReveal();
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 1500));

    await _startTyping();

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    await AudioService.stopLogoReveal();

    final token = await SecureStorageService.getToken();
    final isBiometricEnabled = await SecureStorageService.isBiometricEnabled();

    if (token != null) {
      if (isBiometricEnabled) {
        // Go to login page to trigger biometrics
        Navigator.pushReplacement(
          context,
          FadeSlidePageRoute(page: const LoginScreen()),
        );
      } else {
        // 🔥 Re-detect backend BEFORE auto-login to HomeScreen
        // This ensures local backend is used if it's now reachable
        await ApiService.initializeBackend();
        print('🎯 [SplashIntro] Auto-login using: ${ApiService.baseDomain}');
        SocketService.init(); // Re-init socket with the correct URL
        
        // 🔹 Check if user has a device
        final devices = await ApiService.getUserDevices(token);
        final bool hasDevice = devices.isNotEmpty;

        if (!mounted) return;

        // Direct to home if logged in and biometrics not required
        Navigator.pushReplacement(
          context,
          FadeSlidePageRoute(page: hasDevice ? const HomeScreen() : const AddDeviceScreen()),
        );
      }
    } else {
      // Not logged in, go to login page
      Navigator.pushReplacement(
        context,
        FadeSlidePageRoute(page: const LoginScreen()),
      );
    }
  }

  Future<void> _startTyping() async {
    for (int i = 0; i < fullTitle.length; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() {
        titleText += fullTitle[i];
      });
    }

    await Future.delayed(const Duration(milliseconds: 400));

    for (int i = 0; i < fullTagline.length; i++) {
      await Future.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
      setState(() {
        taglineText += fullTagline[i];
      });
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    final isDark = themeType == ThemeType.dark;
    
    final width = MediaQuery.of(context).size.width;

    Color bgColor;
    if (isLight) {
      bgColor = const Color(0xFFE2E8F0);
    } else if (isDark) {
      bgColor = Colors.black;
    } else {
      bgColor = const Color(0xFF071A2F);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [

          /// CENTER CONTENT
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _logoSlide.value),
                        child: Column(
                          children: [
                            Image.asset(
                              "assets/images/smridge_logo.png",
                              width: 140,
                            ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8)),
                            const SizedBox(height: 10),
                            // Emptied static text block to allow the typewriter to shine.
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: (isLight ? Colors.teal : Colors.tealAccent).withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Text(
                    titleText.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: isLight ? Colors.black87 : Colors.white,
                      letterSpacing: 6.0,
                      shadows: [
                        Shadow(
                          color: (isLight ? Colors.teal : Colors.tealAccent).withOpacity(0.8),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  taglineText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: isLight ? Colors.teal.shade700 : Colors.tealAccent,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
