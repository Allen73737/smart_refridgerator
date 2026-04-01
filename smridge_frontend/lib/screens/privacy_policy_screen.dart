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
                        _buildBody("Smridge employs advanced AI models for freshness estimation and image recognition. All visual data processed during 'Add Inventory' flows is handled on-device. No raw images are stored on our cloud servers unless you explicitly upload them to your personal vault.", isLight),
                        
                        _buildSectionTitle("2. Sensor Telemetry", isLight),
                        _buildBody("Your ESP32 hardware transmits telemetry (Temp, Humidity, VOCs, Weight) to our secure backend. this data is used exclusively to populate your Analytics hub and trigger safety alerts. We do not share your grocery activity patterns with third-party advertisers.", isLight),

                        _buildSectionTitle("3. Information We Collect", isLight),
                        _buildBullet("Account Data: Email and hashed authentication credentials.", isLight),
                        _buildBullet("Hardware Identifiers: MAC address and IP of your Smridge Hub for local network synchronization.", isLight),
                        _buildBullet("Inventory Logs: Item metadata including nutritional info retrieved from OpenFoodFacts.", isLight),

                        _buildSectionTitle("4. Push Notifications", isLight),
                        _buildBody("We use Firebase Cloud Messaging (FCM) to deliver high-priority alerts (e.g. 'Door Left Open' or 'Expiry Warning'). Your device token is shared with Google for delivery purposes only.", isLight),

                        _buildSectionTitle("5. Security Protocols", isLight),
                        _buildBody("Smridge utilizes AES-256 encryption for data at rest and TLS 1.3 for all data in transit. You can further secure access to your local app instance using the 'App Security PIN' feature in settings.", isLight),

                        _buildSectionTitle("6. Biometric Authentication", isLight),
                        _buildBody("If enabled, fingerprint or face recognition data is managed by your operating system's secure enclave. Smridge never has access to your actual biometric keys.", isLight),

                        _buildSectionTitle("7. Third-Party Integration", isLight),
                        _buildBody("We integrate with OpenFoodFacts and Google Gemini API for metadata enrichment. Your data is anonymized before being sent to these services for processing.", isLight),

                        _buildSectionTitle("8. Data Retention Policy", isLight),
                        _buildBody("Activity logs and inventory history are retained for 12 months to provide accurate activity analytics, after which they are automatically purged from our production database.", isLight),

                        _buildSectionTitle("9. User Rights (GDPR/CCPA)", isLight),
                        _buildBody("You have the right to request a full export of your data or immediate deletion of your Smridge account via the Advanced Settings menu.", isLight),

                        _buildSectionTitle("10. Children's Privacy", isLight),
                        _buildBody("Smridge is intended for household managers. We do not knowingly collect or target data from children under the age of 13.", isLight),

                        _buildSectionTitle("11. Updates to Policy", isLight),
                        _buildBody("We may update this policy periodically to reflect changes in our AI algorithms or hardware support. Continued use of Smridge after updates constitutes acceptance.", isLight),

                        _buildSectionTitle("12. Contact Data Protection Officer", isLight),
                        _buildBody("Questions regarding this policy or data processing can be directed to privacy@smridge.protocol for independent review by our security commission.", isLight),

                        _buildSectionTitle("13. Multi-Device Synchronization", isLight),
                        _buildBody("When using multiple mobile devices, your data is synchronized via our secure cloud Relay. Session tokens are uniquely generated and validated per device.", isLight),

                        _buildSectionTitle("14. Cold Storage Architecture", isLight),
                        _buildBody("Non-active legacy data is moved to 'Cold Storage' after 6 months of inactivity, ensuring your main dashboard remains high-performance while preserving historical insights.", isLight),

                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            "For full legal terms, visit smridge.vercel.app",
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
