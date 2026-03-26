import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/secure_storage_service.dart';
import '../services/haptic_service.dart';
import 'login_screen.dart';
import '../core/page_transitions.dart';
import '../widgets/wave_background.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: "Smart Vision",
      description: "Experience the future of refrigeration. Our AI instantly recognizes your groceries with clinical precision.",
      icon: Icons.visibility_outlined,
      color: Colors.tealAccent,
      image: "assets/images/fridge_vision.png", // Generic placeholder or use an icon
    ),
    OnboardingData(
      title: "Fortified Security",
      description: "Your data, protected. Set a secure PIN and enjoy peace of mind with encrypted local storage.",
      icon: Icons.security_outlined,
      color: Colors.blueAccent,
      image: "assets/images/security_vault.png",
    ),
    OnboardingData(
      title: "Real-time Pulse",
      description: "Stay connected always. Receive instant notifications the moment your fridge needs attention.",
      icon: Icons.speed_outlined,
      color: Colors.orangeAccent,
      image: "assets/images/notification_pulse.png",
    ),
  ];

  Future<void> _finishOnboarding() async {
    HapticService.heavy();
    await SecureStorageService.setOnboardingSeen(true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      FadeSlidePageRoute(page: const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLight = themeProvider.currentTheme == ThemeType.light;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 🔹 Premium Background
          Container(
            decoration: BoxDecoration(
              color: isLight ? const Color(0xFFF3F6F8) : const Color(0xFF050B12),
              gradient: isLight ? null : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF050B12), Color(0xFF0A1420)],
              ),
            ),
          ),
          const Positioned.fill(child: WaveBackground()),

          // Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: _buildGlow(_pages[_currentPage].color.withOpacity(0.15)),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: _buildGlow(_pages[_currentPage].color.withOpacity(0.1)),
          ),

          SafeArea(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                HapticService.selection();
                setState(() => _currentPage = index);
              },
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return _buildPage(_pages[index], isLight, textColor);
              },
            ),
          ),

          // Header: Skip Button
          Positioned(
            top: 50,
            right: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: _finishOnboarding,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "SKIP ONBOARDING",
                        style: GoogleFonts.orbitron(
                          color: textColor.withOpacity(0.9),
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.fast_forward_rounded, size: 12, color: textColor.withOpacity(0.9)),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 500.ms),

          // Footer: Indicators & Next Button
          Positioned(
            bottom: 50,
            left: 30,
            right: 30,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(_pages.length, (index) {
                      return AnimatedContainer(
                        duration: 400.ms,
                        margin: const EdgeInsets.only(right: 8),
                        height: 6,
                        width: _currentPage == index ? 30 : 6,
                        decoration: BoxDecoration(
                          color: _currentPage == index 
                              ? _pages[_currentPage].color 
                              : textColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),

                  // Action Button
                  GestureDetector(
                    onTap: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: 600.ms, 
                          curve: Curves.easeInOutCubic,
                        );
                      } else {
                        _finishOnboarding();
                      }
                    },
                    child: AnimatedContainer(
                      duration: 400.ms,
                      padding: EdgeInsets.symmetric(
                        horizontal: _currentPage == _pages.length - 1 ? 24 : 20, 
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _pages[_currentPage].color.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: _pages[_currentPage].color.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: -5,
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1 ? "ENTER SMRIDGE" : "NEXT Phase",
                            style: GoogleFonts.orbitron(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().slideY(begin: 0.5, end: 0).fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingData data, bool isLight, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon/Image Area
          Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isLight ? Colors.white : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: data.color.withOpacity(0.2)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated Rings
                ...List.generate(3, (i) => 
                  Container(
                    width: 140 + (i * 40).toDouble(),
                    height: 140 + (i * 40).toDouble(),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: data.color.withOpacity(0.1 - (i * 0.02))),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(duration: (1 + i).seconds, curve: Curves.easeInOut),
                ),
                Icon(data.icon, size: 80, color: data.color)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(duration: 2.seconds, color: Colors.white.withOpacity(0.5))
                  .scale(duration: 2.seconds),
              ],
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),

          const SizedBox(height: 50),

          // Text Area
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: GoogleFonts.orbitron(
                  color: data.color,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ).animate().slideX(begin: 0.2).fadeIn(duration: 400.ms),
              
              const SizedBox(height: 16),

              Text(
                data.description,
                style: GoogleFonts.inter(
                  color: textColor.withOpacity(0.7),
                  fontSize: 16,
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ).animate().slideY(begin: 0.2).fadeIn(delay: 200.ms),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlow(Color color) {
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String image;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.image,
  });
}
