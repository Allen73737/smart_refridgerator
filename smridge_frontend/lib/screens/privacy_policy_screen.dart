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
                        _buildSectionTitle("1. Information We Collect", isLight),
                        const SizedBox(height: 10),
                        _buildBody("Smridge collects and processes the following data locally on your device:", isLight),
                        _buildBullet("Sensor telemetry: Temperature, Humidity, Gas levels, and Load Cell weight readings from your ESP32 hardware", isLight),
                        _buildBullet("Inventory data: Item names, categories, quantities, weights, expiry dates, and associated images", isLight),
                        _buildBullet("User preferences: Theme settings, sound configurations, fridge color customizations", isLight),
                        _buildBullet("Account credentials: Email and encrypted password for authentication", isLight),
                        _buildBullet("Device tokens: Firebase Cloud Messaging (FCM) tokens for push notifications", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("2. Data Processing & Storage", isLight),
                        const SizedBox(height: 10),
                        _buildBody("All sensor telemetry data is processed on your connected edge device (ESP32) and transmitted to the Smridge backend server via secure HTTP connections. Inventory data is stored in a MongoDB database associated with your user account. Image files are stored locally on your device storage and are not uploaded to any cloud service unless explicitly enabled.", isLight),
                        
                        const SizedBox(height: 20),
                        _buildSectionTitle("3. Third-Party Services", isLight),
                        const SizedBox(height: 10),
                        _buildBody("Smridge integrates with the following third-party services:", isLight),
                        _buildBullet("OpenFoodFacts API: When scanning barcodes, product data (name, brand, category, nutritional info) is retrieved from the open-source OpenFoodFacts database. No personal data is sent to this service.", isLight),
                        _buildBullet("Firebase Cloud Messaging: Used to deliver push notifications for expiry alerts, sensor warnings, and door-open reminders. Only your device's FCM token is shared with Google Firebase.", isLight),
                        _buildBullet("MongoDB Atlas: Your inventory and sensor data may be stored on MongoDB Atlas cloud infrastructure with AES-256 encryption at rest.", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("4. Camera & Image Usage", isLight),
                        const SizedBox(height: 10),
                        _buildBody("Images captured via the Smridge camera feature are used exclusively for inventory logging and barcode scanning. Photos are stored natively on your device storage. No visual data is transmitted to third-party training networks, analytics services, or advertising platforms. AI-based freshness estimation uses on-device processing only.", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("5. Account Security", isLight),
                        const SizedBox(height: 10),
                        _buildBody("Your account password is hashed using bcrypt with salt rounds before storage. JSON Web Tokens (JWT) are used for session authentication with configurable expiration. We do not store plain-text passwords. Account credentials are encrypted during transmission via HTTPS.", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("6. Notifications & Alerts", isLight),
                        const SizedBox(height: 10),
                        _buildBody("Smridge sends push notifications for:", isLight),
                        _buildBullet("Items approaching expiry (48-hour warning via daily cron job)", isLight),
                        _buildBullet("Temperature exceeding safe thresholds (>8°C)", isLight),
                        _buildBullet("Abnormal gas level readings", isLight),
                        _buildBullet("Fridge door left open for more than 60 seconds", isLight),
                        _buildBullet("Sudden weight drops indicating potential item removal", isLight),
                        _buildBody("\nYou can disable any notification sound by selecting 'None' in Advanced Settings. Notification content is generated locally and does not contain personal identifying information.", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("7. Data Retention & Deletion", isLight),
                        const SizedBox(height: 10),
                        _buildBody("Sensor data is retained for analytics purposes and displayed in the Analytics dashboard. You may delete individual inventory items at any time through the fridge 3D view. Account deletion can be requested by contacting support@smridge.io, which will remove all associated data from our servers within 30 days.", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("8. Children's Privacy", isLight),
                        const SizedBox(height: 10),
                        _buildBody("Smridge is not directed at children under the age of 13. We do not knowingly collect personal information from children. If you believe a child has provided us with personal data, please contact us at support@smridge.io for immediate deletion.", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("9. Your Rights", isLight),
                        const SizedBox(height: 10),
                        _buildBody("You have the right to:", isLight),
                        _buildBullet("Access all data associated with your account", isLight),
                        _buildBullet("Request correction of inaccurate data", isLight),
                        _buildBullet("Request deletion of your account and all associated data", isLight),
                        _buildBullet("Export your inventory data", isLight),
                        _buildBullet("Opt out of push notifications at any time", isLight),

                        const SizedBox(height: 20),
                        _buildSectionTitle("10. Contact Us", isLight),
                        const SizedBox(height: 10),
                        _buildBody("For any privacy-related concerns, data requests, or questions about this policy, please contact our data protection team at:", isLight),
                        _buildBody("\nprivacy@smridge.io\nsupport@smridge.io", isLight),

                        const SizedBox(height: 20),
                        Divider(color: isLight ? Colors.black12 : Colors.white24),
                        const SizedBox(height: 10),
                        _buildBody("By using Smridge, you acknowledge that you have read and understood this Privacy Policy and agree to the collection and use of information in accordance with this policy.", isLight),
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
