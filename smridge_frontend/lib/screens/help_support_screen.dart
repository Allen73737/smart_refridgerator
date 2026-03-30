import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/wave_background.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class HelpSupportScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const HelpSupportScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    final isDark = themeType == ThemeType.dark;
    
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color accentColor = isLight ? Colors.teal : Colors.tealAccent;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () {
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text("Help & Support", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)).animate().fadeIn(),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isLight ? const Color(0xFFF3F6F8) : (isDark ? Colors.black : null),
              gradient: (isLight || isDark) ? null : const LinearGradient(
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.15)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isLight ? 0.05 : 0.2), blurRadius: 30)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection("Core Navigation", isLight),
                        const SizedBox(height: 8),
                        _buildFaqItem("How do I use the 3D Fridge?", "Interact directly with the 3D model! Tap the doors to toggle them open/closed, or tap individual slots to see what's inside. Use the Bottom Dock to switch between different monitoring hubs.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("What is the zoom effect?", "When you select the 'Status' tab, the camera will automatically zoom into the upper fridge section where the main sensor cluster (Temp/Humidity/Gas) is located for a detailed view.", isLight),

                        const SizedBox(height: 20),
                        _buildSection("AI & Inventory", isLight),
                        const SizedBox(height: 8),
                        _buildFaqItem("How do I add items?", "Tap the '+' button. For packaged goods, use the 'AI Barcode Scanner' to autofill all data. For fresh produce, use 'Manual Entry' and optionally snap a photo for image recognition.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("What is the Freshness Score?", "Our AI calculates a score (0-100%) based on atmospheric data and storage time. If a score drops below 40%, you'll receive a 'Critical Freshness' alert on your navbar.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("How does the weight sensor work?", "If your ESP32 is equipped with a load cell, Smridge will live-stream the weight during the 'Add' process. Once it stabilizes, it will 'Lock' the value automatically.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("What are AI Smart Recipes?", "Tapping the 'Recipes' tab in product details generates 3-5 unique recipes based on the specific item and other ingredients currently in your fridge.", isLight),

                        const SizedBox(height: 20),
                        _buildSection("System & Hardware", isLight),
                        const SizedBox(height: 8),
                        _buildFaqItem("ESP32 Connection Issues?", "Ensure your ESP32 is on the same network. Navigate to Settings → Advanced Device Config to update the IP endpoint and calibrate sensor thresholds.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("Why are my notifications not working?", "Check your 'App Security PIN' in settings. If enabled, notifications may be silenced until the app is unlocked. Ensure you have 'Push Alerts' enabled in the OS settings.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("How to calibrate sensors?", "Go to Advanced Hub Config. You can set baseline 'Zero' values for the VOC gas sensor and the weight scale to ensure precision.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("What is the 'Network Change' alert?", "If Smridge detects you are on a new Wi-Fi network that isn't the last known connected place, it will prompt you to re-sync your hardware for security.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("How to update Smridge OS?", "System updates are pushed via our cloud portal. Check the 'About' screen for the current version and 'Check for Updates' manually.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("Can I use Smridge without hardware?", "Yes! You can use the app in 'Simulation Mode' where the AI generates realistic sensor data based on your region and typical usage patterns.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("How to export my data?", "Navigate to Account → Data Management. You can download a structured JSON or CSV of your entire inventory history and activity logs.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("Is there an API for developers?", "Yes! Smridge Pro users can access the 'Developer Portal' in settings to generate API keys for integrating Smridge data with other Smart Home platforms like Home Assistant.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("What if the AI recognizes an item incorrectly?", "You can manually correct any AI error by tapping 'Edit' on the item details. Our neural network learns from these corrections to improve accuracy for your specific household.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("Device 'Sleep Mode' vs 'Active'?", "Your hardware saves power by pulsing sensor data every 5 minutes in 'Sleep Mode'. In 'Active Mode', it provides real-time updates (useful for cooking or shopping).", isLight),
                        
                        const SizedBox(height: 40),
                        Center(
                          child: Column(
                            children: [
                              Text("Still need help?", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14)),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () {}, // Future: Email trigger
                                icon: const Icon(Icons.support_agent_outlined),
                                label: const Text("Contact Smridge Engineering"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn().slideY(begin: 0.1),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSection(String title, bool isLight) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        title,
        style: TextStyle(
          color: isLight ? Colors.teal.shade700 : Colors.tealAccent.shade100,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer, bool isLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: TextStyle(color: isLight ? Colors.teal : Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(answer, style: TextStyle(color: isLight ? Colors.black87 : Colors.white70, fontSize: 14, height: 1.4)),
      ],
    );
  }
}
