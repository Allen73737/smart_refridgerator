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
        'subject': 'Smridge App Feedback v1.2.0',
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
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    final isDark = themeType == ThemeType.dark;

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
            fontSize: 18,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                            height: 140,
                            width: 140,
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              color: isLight ? Colors.white.withOpacity(0.5) : accentColor.withOpacity(0.05),
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.2), 
                                  blurRadius: 40, 
                                  spreadRadius: 2
                                )
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/smridge_logo.png', // Fixed Path
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                             .shimmer(duration: 3000.ms, color: accentColor.withOpacity(0.3)),
                          ),
                        ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 25),
                        Text(
                          "SMRIDGE ECOSYSTEM",
                          style: GoogleFonts.orbitron(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            letterSpacing: 4,
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "VERSION 1.2.0 PREMIUM",
                            style: GoogleFonts.orbitron(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                              letterSpacing: 1,
                            ),
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Mission Section
                  _buildGlassCard(
                    context,
                    isLight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(Icons.auto_awesome, "Our Vision", accentColor),
                        const SizedBox(height: 12),
                        Text(
                          "Smridge is more than just a smart refrigerator; it is the central nervous system of your clinical kitchen. By merging advanced Computer Vision with real-time IoT synchronization, we ensure your nutrition is preserved with zero latency and absolute transparency.",
                          style: TextStyle(color: subTextColor, fontSize: 15, height: 1.6),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 20),

                  // Features List
                  _buildGlassCard(
                    context,
                    isLight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(Icons.memory, "Core Technologies", accentColor),
                        const SizedBox(height: 15),
                        _buildFeatureTile(Icons.wifi_tethering, "ESP32 Real-time Telemetry", subTextColor),
                        _buildFeatureTile(Icons.psychology, "Freshness AI Engine v2.1", subTextColor),
                        _buildFeatureTile(Icons.layers, "Glassmorphic 3D Interface", subTextColor),
                        _buildFeatureTile(Icons.security, "On-Device Data Sovereignty", subTextColor),
                      ],
                    ),
                  ).animate().fadeIn(delay: 800.ms),

                  const SizedBox(height: 20),

                  // Contact & Socials
                  _buildGlassCard(
                    context,
                    isLight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Developed with ❤️ by the Smridge Team",
                          style: TextStyle(color: subTextColor, fontSize: 13),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSocialIcon(Icons.language, () => _launchURL("https://smridge.io"), accentColor),
                            const SizedBox(width: 20),
                            _buildSocialIcon(Icons.email_outlined, _sendEmail, accentColor),
                            const SizedBox(width: 20),
                            _buildSocialIcon(Icons.code, () => _launchURL("https://github.com/smridge"), accentColor),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 1000.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context, bool isLight, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isLight ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color accentColor) {
    return Row(
      children: [
        Icon(icon, color: accentColor, size: 20),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: accentColor,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureTile(IconData icon, String label, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: textColor.withOpacity(0.5), size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: textColor, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, VoidCallback onTap, Color accentColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: accentColor, size: 24),
      ),
    );
  }
}
