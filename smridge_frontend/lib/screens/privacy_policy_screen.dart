import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/wave_background.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const PrivacyPolicyScreen({super.key, this.onBack});

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
        title: Text("Privacy Policy", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)).animate().fadeIn(),
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
                        _buildPolicyHeader("Last Updated: March 2026", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("1. Data Sovereignty & AI", isLight),
                        const SizedBox(height: 10),
                        _buildBody("Smridge employs advanced AI models for freshness estimation and image recognition. All visual data processed during 'Add Inventory' flows is handled on-device. No raw images are stored on our cloud servers unless you explicitly upload them to your personal vault.", isLight),
                        
                        const SizedBox(height: 20),
                        _buildSectionTitle("2. Sensor Telemetry", isLight),
                        const SizedBox(height: 10),
                        _buildBody("Your ESP32 hardware transmits telemetry (Temp, Humidity, VOCs, Weight) to our secure backend. this data is used exclusively to populate your Analytics hub and trigger safety alerts. We do not share your grocery consumption patterns with third-party advertisers.", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("3. Information We Collect", isLight),
                        const SizedBox(height: 10),
                        _buildBullet("Account Data: Email and hashed authentication credentials.", isLight),
                        _buildBullet("Hardware Identifiers: MAC address and IP of your Smridge Hub for local network synchronization.", isLight),
                        _buildBullet("Inventory Logs: Item metadata including nutritional info retrieved from OpenFoodFacts.", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("4. Push Notifications", isLight),
                        const SizedBox(height: 10),
                        _buildBody("We use Firebase Cloud Messaging (FCM) to deliver high-priority alerts (e.g. 'Door Left Open' or 'Expiry Warning'). Your device token is shared with Google for delivery purposes only.", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("5. Security Protocols", isLight),
                        const SizedBox(height: 10),
                        _buildBody("Smridge utilizes AES-256 encryption for data at rest and TLS 1.3 for all data in transit. You can further secure access to your local app instance using the 'App Security PIN' feature in settings.", isLight),

                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            "For full legal terms, visit legal.smridge.io",
                            style: TextStyle(color: isLight ? Colors.grey : Colors.white38, fontSize: 12),
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

  Widget _buildPolicyHeader(String text, bool isLight) {
    return Text(
      text,
      style: TextStyle(
        color: isLight ? Colors.grey.shade600 : Colors.white54,
        fontSize: 13,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isLight) {
    return Text(
      title,
      style: TextStyle(
        color: isLight ? Colors.teal : Colors.tealAccent,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBody(String text, bool isLight) {
    return Text(
      text,
      style: TextStyle(
        color: isLight ? Colors.black87 : Colors.white70,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }

  Widget _buildBullet(String text, bool isLight) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("•  ", style: TextStyle(color: isLight ? Colors.teal : Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: TextStyle(color: isLight ? Colors.black87 : Colors.white70, fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
