import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart'; 
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
import 'pin_entry_screen.dart'; 
import 'onboarding_screen.dart'; 
import '../widgets/wave_background.dart';

class SplashIntro extends StatefulWidget {
  const SplashIntro({Key? key}) : super(key: key);

  @override
  State<SplashIntro> createState() => _SplashIntroState();
}

class _SplashIntroState extends State<SplashIntro> with TickerProviderStateMixin {
  String titleText = "";
  String taglineText = "";

  final String fullTitle = "SMRIDGE";
  final String fullTagline = "Where vision meets refrigeration";

  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  Future<void> _startSequence() async {
    unawaited(ApiService.initializeBackend());
    SocketService.init();

    await Future.delayed(const Duration(milliseconds: 300));
    AudioService.playLogoReveal();

    // Cinematic delay for build-up - synchronized with logo rise
    await Future.delayed(const Duration(milliseconds: 800));
    await _startTyping();

    if (!mounted) return;
    await AudioService.stopLogoReveal();

    final bool seenOnboarding = await SecureStorageService.hasSeenOnboarding();
    if (!seenOnboarding) {
      if (!mounted) return;
      Navigator.pushReplacement(context, FadeSlidePageRoute(page: const OnboardingScreen()));
      return;
    }

    final token = await SecureStorageService.getToken();
    final isBiometricEnabled = await SecureStorageService.isBiometricEnabled();

    if (token != null) {
      if (isBiometricEnabled) {
        // 🔐 Biometric users go to Login screen for auth
        Navigator.pushReplacement(context, FadeSlidePageRoute(page: const LoginScreen()));
      } else {
        if (!mounted) return;
        final bool pinEnabled = await SecureStorageService.isPinEnabled();
        if (pinEnabled) {
          // 🔒 PIN users go to PIN entry
          Navigator.pushReplacement(context, FadeSlidePageRoute(page: const PinEntryScreen()));
        } else {
          // ✅ Logged-in user → ALWAYS go to HomeScreen
          // Device pairing is handled inside the app (network-change detection)
          Navigator.pushReplacement(context, FadeSlidePageRoute(page: const HomeScreen()));
        }
      }
    } else {
      Navigator.pushReplacement(context, FadeSlidePageRoute(page: const LoginScreen()));
    }
  }

  Future<void> _startTyping() async {
    for (int i = 0; i < fullTitle.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100)); // Faster typing for title
      if (!mounted) return;
      setState(() {
        titleText += fullTitle[i];
      });
    }

    await Future.delayed(const Duration(milliseconds: 400));

    for (int i = 0; i < fullTagline.length; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      setState(() {
        taglineText += fullTagline[i];
      });
    }
    
    // Blink cursor at the end
    for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        setState(() {}); // trigger rebuild for cursor blink
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    final isDark = themeType == ThemeType.dark;
    
    Color bgColor = const Color(0xFF010A15); // 🌌 Premium Deep Dark Blue (Image 2 Sync)
    Color accentColor = const Color(0xFF00F2FF); // 💎 Vibrant Cyan Glow

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 🌠 1. BASE BACKGROUND (Match HomeScreen)
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              gradient: (isLight || isDark) ? null : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                ],
              ),
            ),
          ),

          // 🌊 2. WAVE BACKGROUND (Seamless transition to Home)
          const Positioned.fill(child: RepaintBoundary(child: WaveBackground())),

          // 🌌 3. LUMINOUS VOID: Cinematic Pulse
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    accentColor.withOpacity(0.08),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .fadeIn(duration: 2.seconds)
             .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 10.seconds),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 💎 2. LOGO REVEAL: LIQUID LIGHT ASSEMBLY
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dynamic Light Burst (Backglow)
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 100, spreadRadius: 10),
                          BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 50, spreadRadius: -10),
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.1, 1.1), duration: 3.seconds, curve: Curves.easeInOutSine)
                     .fadeIn(duration: 2.seconds),

                    // The Core Logo Image with Perspective and Refraction
                    Image.asset(
                      "assets/images/smridge_logo.png",
                      width: 160,
                    )
                    .animate()
                    .fadeIn(duration: 2500.ms)
                    .blurXY(begin: 30, end: 0, duration: 2.seconds, curve: Curves.easeOutQuart) // 💎 Mystic Blur-Reveal
                    .moveY(begin: 300, end: 0, duration: 2500.ms, curve: Curves.easeOutQuart) // 🚀 Cinematic Slide-Up (Increased Distance)
                    .scale(begin: const Offset(0.2, 0.2), end: const Offset(1.0, 1.0), duration: 2500.ms, curve: Curves.easeOutBack)
                    .custom(
                      duration: 4.seconds,
                      builder: (context, value, child) {
                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(0.8 * (1 - value))
                            ..rotateZ(0.2 * (1 - value)),
                          alignment: Alignment.center,
                          child: child,
                        );
                      },
                    )
                    // REMOVED .blurXY (erasing effect) per user request
                    .then()
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: -5, end: 5, duration: 2.seconds, curve: Curves.easeInOutSine)
                    .rotate(begin: -0.02, end: 0.02, duration: 3.seconds, curve: Curves.easeInOutSine)
                    .shimmer(duration: 4.seconds, color: Colors.white24, stops: [0.4, 0.5, 0.6]),

                    // 3. COALESCING "DATA LIGHTS" (Instead of scan lines)
                    ...List.generate(15, (index) {
                      final delay = (index * 150).ms;
                      return Container(
                        width: 2,
                        height: 2,
                        decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                      ).animate(onPlay: (c) => c.repeat())
                       .move(
                         begin: Offset(index % 2 == 0 ? -120 : 120, (index - 7) * 15.0),
                         end: Offset(0, 0),
                         duration: 2.seconds,
                         delay: delay,
                         curve: Curves.easeOutSine
                       )
                       .fadeIn(duration: 500.ms)
                       .fadeOut(delay: 1500.ms, duration: 500.ms);
                    }),
                  ],
                ),

                const SizedBox(height: 80),

                // 🔡 4. TYPOGRAPHIC REVEAL: SMRIDGE
                Text(
                  titleText.toUpperCase() + (titleText.length < fullTitle.length ? "█" : ""),
                  style: GoogleFonts.orbitron(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.0,
                    shadows: [
                      Shadow(color: accentColor.withOpacity(0.8), blurRadius: 20), 
                      Shadow(color: accentColor.withOpacity(0.5), blurRadius: 40),
                    ],
                  ),
                ).animate()
                 .fadeIn(duration: 500.ms)
                 .moveY(begin: 100, end: 0, duration: 1000.ms, curve: Curves.easeOutQuart), 

                const SizedBox(height: 15),

                // 📜 5. TAGLINE: CINEMATIC RISE
                Text(
                  taglineText + (taglineText.length < fullTagline.length && titleText.length == fullTitle.length ? "█" : (DateTime.now().millisecond % 1000 < 500 && titleText.length == fullTitle.length ? "█" : "")),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: accentColor.withOpacity(0.9),
                    letterSpacing: 0.1, // Near zero for readability
                  ),
                ).animate()
                 .fadeIn(duration: 500.ms), // 🚀 Vertical Rise
              ],
            ),
          ),
        ],
      ),
    );
  }
}
