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

  final String fullTitle = "Smridge";
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

    // Cinematic delay for build-up
    await Future.delayed(const Duration(milliseconds: 3000));
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
        Navigator.pushReplacement(context, FadeSlidePageRoute(page: const LoginScreen()));
      } else {
        final devices = await ApiService.getUserDevices(token);
        final bool hasDevice = devices.isNotEmpty;
        if (!mounted) return;
        final bool pinEnabled = await SecureStorageService.isPinEnabled();
        if (pinEnabled) {
          Navigator.pushReplacement(context, FadeSlidePageRoute(page: const PinEntryScreen()));
        } else {
          Navigator.pushReplacement(context, FadeSlidePageRoute(page: hasDevice ? const HomeScreen() : const AddDeviceScreen()));
        }
      }
    } else {
      Navigator.pushReplacement(context, FadeSlidePageRoute(page: const LoginScreen()));
    }
  }

  Future<void> _startTyping() async {
    for (int i = 0; i < fullTitle.length; i++) {
      await Future.delayed(const Duration(milliseconds: 140));
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
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    final isDark = themeType == ThemeType.dark;
    
    Color bgColor = isLight ? const Color(0xFFF3F6F8) : (isDark ? Colors.black : Colors.black);
    Color accentColor = isLight ? Colors.teal : const Color(0xFF00FFD1);

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
                    .fadeIn(duration: 2.seconds)
                    .scale(begin: const Offset(0.4, 0.4), end: const Offset(1.0, 1.0), duration: 3.seconds, curve: Curves.easeOutQuart)
                    .custom(
                      duration: 4.seconds,
                      builder: (context, value, child) {
                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // Refractive depth
                            ..rotateY(0.6 * (1 - value))
                            ..rotateZ(0.1 * (1 - value)),
                          alignment: Alignment.center,
                          child: child,
                        );
                      },
                    )
                    .blurXY(begin: 10, end: 0, duration: 2.seconds)
                    .then() // Subtle Persistent Shimmer
                    .animate(onPlay: (c) => c.repeat())
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
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [isLight ? Colors.black87 : Colors.white, accentColor, isLight ? Colors.black87 : Colors.white],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds),
                  child: Text(
                    titleText.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 18.0,
                    ),
                  ).animate().fadeIn(duration: 2.seconds).slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuart),
                ),

                const SizedBox(height: 20),

                // 📜 5. TAGLINE: CINEMATIC FADE
                Text(
                  taglineText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: isLight ? Colors.black54 : accentColor.withOpacity(0.6),
                    letterSpacing: 6.0,
                  ),
                ).animate().fadeIn(delay: 2000.ms).blurXY(begin: 10, end: 0, duration: 1500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
