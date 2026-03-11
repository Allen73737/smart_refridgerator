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
                        _buildSection("Getting Started", isLight),
                        const SizedBox(height: 8),
                        _buildFaqItem("How do I add inventory?", "Tap the '+' button at the bottom dock. Choose 'Packaged' to scan a barcode (auto-fills item data from OpenFoodFacts) or 'Non-Packaged' to enter details manually. The load cell will automatically detect weight.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("How do I scan a barcode?", "Select 'Packaged Item' → point your camera at the barcode. The app queries OpenFoodFacts API and auto-fills name, brand, category, weight, and estimated expiry date. You can edit any field before saving.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("What are the fridge categories?", "Items are categorized as: Dairy, Fruits, Vegetables, Meat, Seafood, Beverages, Snacks, Condiments, Bakery, Frozen, Leftovers, or Others. The app auto-detects the category from the item name.", isLight),

                        const SizedBox(height: 20),
                        _buildSection("Fridge & Sensors", isLight),
                        const SizedBox(height: 8),
                        _buildFaqItem("How do I calibrate the sensors?", "Navigate to Settings → 'Device Metrics Configuration' and adjust the temperature, humidity, and gas threshold parameters to match your ESP32 hardware environment.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("Why is the fridge glowing red?", "Red pulsing indicates a critical threshold breach — temperature has exceeded safe limits (>8°C), gas reading is abnormal, or freshness has dropped below thresholds. Check the Analytics screen for exact readings.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("How does the load cell work?", "The load cell sensor auto-detects the weight of items placed in the fridge. On the Add Inventory screen, you'll see 'Reading Load Cell...' while it stabilizes, then 'Load Cell Locked' once the weight is captured. You can also manually override the weight.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("How do I close the fridge door?", "Tap the door icon (🚪) next to the inventory list icon at the top-right of the fridge view. You can also tap directly on the 3D door or swipe it closed.", isLight),
                        
                        const SizedBox(height: 20),
                        _buildSection("Customization", isLight),
                        const SizedBox(height: 8),
                        _buildFaqItem("How do I change the fridge color?", "Go to Settings → Advanced Settings → 'Fridge Visuals'. You can customize both the exterior and interior colors using the color picker. Hit 'Revert to Default Visuals' to restore original colors.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("How do I customize sounds?", "Settings → Advanced Settings → 'Audio Customization'. Choose from 7 unique sounds for each category: Fridge Working, Door, General Notification, Expiry Notification, and Inventory Save. Use the preview button (▶) to hear sounds before selecting.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("How do I switch themes?", "Open the side menu → tap 'App Theme', or go to Settings → Theme. Choose between Default (dark blue gradient), Light Mode, or Dark Mode. All screens including the splash screen adapt to your chosen theme.", isLight),

                        const SizedBox(height: 20),
                        _buildSection("Notifications & Alerts", isLight),
                        const SizedBox(height: 8),
                        _buildFaqItem("What types of notifications are there?", "Smridge sends alerts for: items about to expire (48-hour warning), temperature breaches, unusual gas readings, prolonged door-open events, and sudden weight drops. Each notification type has its own customizable sound.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("How do I silence notifications?", "In Advanced Settings → Audio Customization, select 'None' from any sound dropdown to mute that specific notification type.", isLight),

                        const SizedBox(height: 20),
                        _buildSection("Analytics & Data", isLight),
                        const SizedBox(height: 8),
                        _buildFaqItem("How do the analytics graphs work?", "The Analytics screen shows live temperature, humidity, and freshness data. Data points update every 3 seconds from the ESP32 sensors (or simulator). Tap any point on the graph for detailed values.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("What is the Freshness Score?", "Freshness Score (0-100) is calculated based on temperature stability, storage duration, and item category. A score below 50 triggers an expiry warning. The score is displayed both on the status panel and in item details.", isLight),

                        const SizedBox(height: 20),
                        _buildSection("Contact & Support", isLight),
                        const SizedBox(height: 8),
                        _buildFaqItem("Contact Technical Support", "Still facing hardware or software issues? Email our engineering team at support@smridge.io. Please include your hardware MAC address, app version, and a screenshot of the issue. We typically respond within 24 hours.", isLight),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 30),
                        _buildFaqItem("How do I report a bug?", "Go to Settings → Help & Support (this screen), note the issue details, and email support@smridge.io with steps to reproduce the problem. Include your device model, OS version, and any error messages displayed.", isLight),
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
