import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/theme_provider.dart';
import '../widgets/wave_background.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;

    // Detect if we are in light mode for text visibility
    bool isLight = themeType == ThemeType.light;
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color subTextColor = isLight ? Colors.black54 : Colors.white70;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isLight ? const Color(0xFFF3F6F8) : (themeType == ThemeType.dark ? Colors.black : const Color(0xFF0E1215)),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Theme Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)).animate().fadeIn(),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background
          if (!isLight && themeType != ThemeType.dark)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F2027), Color(0xFF203A43)],
                ),
              ),
            ),
          
          if (!isLight) const Positioned.fill(child: WaveBackground()),

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 30, bottom: 220),
              children: [
                _buildThemeCard(
                  context: context,
                  title: "Default Theme",
                  subtitle: "Deep space blue with glassmorphism",
                  icon: Icons.ac_unit,
                  isSelected: themeType == ThemeType.defaultTheme,
                  onTap: () => themeProvider.setTheme(ThemeType.defaultTheme),
                  isLight: isLight,
                ),
                const SizedBox(height: 20),
                _buildThemeCard(
                  context: context,
                  title: "Dark Mode",
                  subtitle: "Pure OLED black for deep contrast",
                  icon: Icons.dark_mode,
                  isSelected: themeType == ThemeType.dark,
                  onTap: () => themeProvider.setTheme(ThemeType.dark),
                  isLight: isLight,
                ),
                const SizedBox(height: 20),
                _buildThemeCard(
                  context: context,
                  title: "Light Mode",
                  subtitle: "Clean white and soft blue",
                  icon: Icons.light_mode,
                  isSelected: themeType == ThemeType.light,
                  onTap: () => themeProvider.setTheme(ThemeType.light),
                  isLight: isLight,
                ),
              ],
            ).animate().fadeIn().slideY(begin: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLight,
  }) {
    Color cardColor = isLight ? Colors.white : Colors.white.withOpacity(0.05);
    Color borderColor = isSelected 
        ? Colors.tealAccent 
        : (isLight ? Colors.grey.shade300 : Colors.white.withOpacity(0.15));
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color subTextColor = isLight ? Colors.black54 : Colors.white70;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
              boxShadow: isLight 
                ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                : [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30)],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.tealAccent.withOpacity(0.2) : (isLight ? Colors.grey.shade200 : Colors.white10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: isSelected ? Colors.tealAccent : (isLight ? Colors.black54 : Colors.white54), size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 14)),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.tealAccent, size: 28).animate().scale(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
