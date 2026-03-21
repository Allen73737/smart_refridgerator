import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../widgets/wave_background.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@smridge.io',
      query: encodeQueryParameters(<String, String>{
        'subject': 'Smridge App Feedback v1.0.0+1',
      }),
    );
    if (!await launchUrl(emailLaunchUri)) {
      throw Exception('Could not launch email');
    }
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLight = themeProvider.currentTheme == ThemeType.light;
    final isDark = themeProvider.currentTheme == ThemeType.dark;

    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color subTextColor = isLight ? Colors.black54 : Colors.white70;
    Color accentColor = isLight ? Colors.teal : Colors.tealAccent;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "ABOUT SMRIDGE",
          style: GoogleFonts.orbitron(
            color: textColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              color: isLight ? const Color(0xFFF3F6F8) : (isDark ? Colors.black : null),
              gradient: (isLight || isDark)
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F2027), Color(0xFF203A43)],
                    ),
            ),
          ),
          const Positioned.fill(child: WaveBackground()),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Logo & Version
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Hero(
                          tag: 'app_logo',
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/smridge_logo.png',
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.kitchen, size: 80, color: accentColor),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "v1.0.0+1",
                          style: GoogleFonts.anta(color: subTextColor, fontSize: 16),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms).scale(),

                  // Glass Container for Content
                  RepaintBoundary(
                    child: _GlassSection(
                      children: [
                        _InfoSection(
                          title: "1. App Overview",
                          content: "Smridge is a futuristic IoT refrigerator ecosystem designed to revolutionize food management through real-time sensing, automated tracking, and intelligent insights. Our ecosystem bridge connects your kitchen hardware to a seamless digital experience.",
                          accent: accentColor,
                          text: textColor,
                        ),
                        _InfoDivider(isLight: isLight),
                        _InfoSection(
                          title: "2. Developer Info",
                          content: "Designed and Engineered by the Smridge Systems Team. We focus on high-fidelity IoT solutions and sustainable home technology.",
                          accent: accentColor,
                          text: textColor,
                        ),
                        _InfoDivider(isLight: isLight),
                        _InfoSection(
                          title: "3. Mission & Vision",
                          content: "Our mission is to eliminate global food waste through precision technology and intuitive data. We envision a future where every household manages resources with 100% efficiency.",
                          accent: accentColor,
                          text: textColor,
                        ),
                        _InfoDivider(isLight: isLight),
                        _InfoSection(
                          title: "4. App Permissions",
                          content: "• Camera: Barcode recognition & profile settings.\n• Storage: Inventory photo management.\n• Notifications: Critical freshness & sensor alerts.\n• Sensors: Real-time ESP32 hardware synchronization.",
                          accent: accentColor,
                          text: textColor,
                        ),
                        _InfoDivider(isLight: isLight),
                        _InfoSection(
                          title: "5. Credits & Acknowledgements",
                          content: "Built with Flutter, React, Vite, ESP32 Microcontrollers, and OpenFoodFacts API. Special thanks to the open-source community.",
                          accent: accentColor,
                          text: textColor,
                        ),
                        _InfoDivider(isLight: isLight),
                        _InfoSection(
                          title: "6. Legal Information",
                          content: "© 2026 Smridge IoT Systems. Smridge is a registered trademark. Terms and Conditions apply to all cloud-synced features.",
                          accent: accentColor,
                          text: textColor,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                  const SizedBox(height: 20),

                  // Contact & Feedback Section
                  _GlassSection(
                    children: [
                      Text(
                        "7. Contact & Support",
                        style: GoogleFonts.anta(
                          color: accentColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _ActionButton(
                        icon: Icons.email_outlined,
                        label: "Report a Bug",
                        onTap: _sendEmail,
                        accent: accentColor,
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        icon: Icons.feedback_outlined,
                        label: "Send Feedback",
                        onTap: _sendEmail,
                        accent: accentColor,
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        icon: Icons.language_outlined,
                        label: "Visit Website",
                        onTap: () => _launchURL("https://www.smridge.io"),
                        accent: accentColor,
                      ),
                    ],
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  final List<Widget> children;
  const _GlassSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final String content;
  final Color accent;
  final Color text;

  const _InfoSection({
    required this.title,
    required this.content,
    required this.accent,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.anta(
            color: accent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(color: text.withOpacity(0.8), fontSize: 14, height: 1.5),
        ),
      ],
    );
  }
}

class _InfoDivider extends StatelessWidget {
  final bool isLight;
  const _InfoDivider({required this.isLight});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Divider(color: isLight ? Colors.black12 : Colors.white10),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withOpacity(0.3)),
            color: accent.withOpacity(0.05),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 15),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: accent.withOpacity(0.5), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
