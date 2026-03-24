import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_settings.dart';
import '../widgets/wave_background.dart';
import 'account_profile_screen.dart';
import 'privacy_policy_screen.dart';
import 'help_support_screen.dart';
import 'theme_settings_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'advanced_settings_screen.dart';
import 'about_screen.dart';
import 'notification_history_screen.dart';
import '../services/secure_storage_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onProfileTap;
  final VoidCallback? onPrivacyTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onActivityTap;

  const SettingsScreen({
    super.key, 
    this.onBack,
    this.onProfileTap,
    this.onPrivacyTap,
    this.onHelpTap,
    this.onActivityTap,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isConfigExpanded = false;

  void _showMockDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2A33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(content, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Colors.tealAccent)),
            )
          ],
        );
      }
    );
  }
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLight = themeProvider.currentTheme == ThemeType.light;
    final isDark = themeProvider.currentTheme == ThemeType.dark;
    
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color subTextColor = isLight ? Colors.black54 : Colors.white70;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text("Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))
            .animate().fadeIn(),
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
              padding: const EdgeInsets.only(top: 80, bottom: 160, left: 24, right: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30)
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "General Account Settings",
                          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ).animate().fadeIn().slideX(begin: -0.1),
                        
                        const SizedBox(height: 15),
                        
                        _buildSettingsTile(Icons.person, "Account Profile", isLight, onTap: widget.onProfileTap ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountProfileScreen()))),
                        _buildSettingsTile(Icons.privacy_tip, "Privacy Policy", isLight, onTap: widget.onPrivacyTap ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
                        _buildSettingsTile(Icons.help_outline, "Help & Support", isLight, onTap: widget.onHelpTap ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
                        _buildSettingsTile(Icons.info_outline, "About Smridge", isLight, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()))),
                        _buildSettingsTile(Icons.history, "Notification History", isLight, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()))),
                        _buildSettingsTile(Icons.analytics_outlined, "My Activity", isLight, onTap: widget.onActivityTap ?? () {}),
                        
                        const SizedBox(height: 25),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 1),
                        const SizedBox(height: 15),

                        Text(
                          "Appearance",
                          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ).animate().fadeIn().slideX(begin: -0.1),
                        
                        const SizedBox(height: 15),
                        _buildSettingsTile(Icons.palette, "App Theme", isLight, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()))),
                        _buildSettingsTile(Icons.tune, "Advanced Settings", isLight, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen()))),

                        const SizedBox(height: 25),
                        Divider(color: isLight ? Colors.black12 : Colors.white24, height: 1),
                        const SizedBox(height: 15),

                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: _isConfigExpanded,
                            onExpansionChanged: (val) => setState(() => _isConfigExpanded = val),
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              "Device Metrics Configuration",
                              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                            ).animate().fadeIn().slideX(begin: -0.1),
                            children: [
                              const SizedBox(height: 15),
                              buildGlassSlider(
                                "Temperature Threshold",
                                AppSettings.temperatureThreshold,
                                AppSettings.adminMinTemperature,
                                AppSettings.adminMaxTemperature,
                                (val) => setState(() => AppSettings.temperatureThreshold = AppSettings.clampTemperature(val)),
                                Icons.thermostat,
                                isLight,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 4),
                                child: Text(
                                  "Restricted range: ${AppSettings.adminMinTemperature.toStringAsFixed(1)}° — ${AppSettings.adminMaxTemperature.toStringAsFixed(1)}°",
                                  style: TextStyle(color: isLight ? Colors.grey : Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ),
                              const SizedBox(height: 20),
                              buildGlassSlider(
                                "Humidity Threshold",
                                AppSettings.humidityThreshold,
                                AppSettings.adminMinHumidity,
                                AppSettings.adminMaxHumidity,
                                (val) => setState(() => AppSettings.humidityThreshold = AppSettings.clampHumidity(val)),
                                Icons.water_drop,
                                isLight,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 4),
                                child: Text(
                                  "Restricted range: ${AppSettings.adminMinHumidity.toStringAsFixed(1)}% — ${AppSettings.adminMaxHumidity.toStringAsFixed(1)}%",
                                  style: TextStyle(color: isLight ? Colors.grey : Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ),
                              const SizedBox(height: 20),
                              buildGlassSlider(
                                "Freshness Threshold",
                                AppSettings.freshnessThreshold,
                                AppSettings.adminMinFreshness,
                                AppSettings.adminMaxFreshness,
                                (val) => setState(() => AppSettings.freshnessThreshold = AppSettings.clampFreshness(val)),
                                Icons.eco,
                                isLight,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 4),
                                child: Text(
                                  "Restricted range: ${AppSettings.adminMinFreshness.toStringAsFixed(1)} — ${AppSettings.adminMaxFreshness.toStringAsFixed(1)}",
                                  style: TextStyle(color: isLight ? Colors.grey : Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        _buildSettingsTile(
                          Icons.logout, 
                          "Logout", 
                          isLight, 
                          onTap: () => _showLogoutDialog(),
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildGlassSlider(String label, double value, double min, double max, Function(double) onChanged, IconData icon, bool isLight) {
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color iconColor = isLight ? Colors.teal : Colors.tealAccent;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: isLight ? Colors.grey.shade200 : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.tealAccent,
              inactiveTrackColor: Colors.white.withOpacity(0.2),
              thumbColor: Colors.white,
              overlayColor: Colors.tealAccent.withOpacity(0.2),
              trackHeight: 4.0,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A33),
        title: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to logout from Smridge?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await SecureStorageService.clearToken();
              await SecureStorageService.clearUserId();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (_) => const LoginScreen()), 
                  (route) => false,
                );
              }
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, bool isLight, {VoidCallback? onTap, bool isDestructive = false}) {
    Color textColor = isDestructive ? Colors.redAccent : (isLight ? Colors.black87 : Colors.white);
    Color iconColor = isDestructive ? Colors.redAccent : (isLight ? Colors.teal : Colors.tealAccent);
    Color bgColor = isDestructive ? Colors.redAccent.withOpacity(0.1) : (isLight ? Colors.grey.shade200 : Colors.white.withOpacity(0.1));

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
      trailing: isDestructive ? null : Icon(Icons.arrow_forward_ios, color: isLight ? Colors.black54 : Colors.white54, size: 16),
      onTap: onTap,
    );
  }
}
