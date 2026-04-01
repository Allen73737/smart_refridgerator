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
import '../providers/connectivity_provider.dart';
import 'advanced_settings_screen.dart';
import 'add_device_screen.dart';
import 'device_config_screen.dart';
import 'about_screen.dart';
import 'notification_history_screen.dart';
import '../services/secure_storage_service.dart';
import '../services/haptic_service.dart';
import 'login_screen.dart';
import 'pin_entry_screen.dart';
import 'activity_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_walkthrough.dart'; 

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
  bool _isPinEnabled = false;
  bool _hapticsEnabled = HapticService.isEnabled;
  bool _vibrationAlertsEnabled = true; // 📳 New: Vibration for notifications
  
  final GlobalKey _wtAccountKey = GlobalKey();
  final GlobalKey _wtActivityKey = GlobalKey();
  final GlobalKey _wtSecurityKey = GlobalKey();
  final GlobalKey _wtThemeKey = GlobalKey();
  final GlobalKey _wtHapticsKey = GlobalKey();
  final GlobalKey _wtThresholdsKey = GlobalKey(); // 🔹 Renamed from _wtAdvancedKey
  final GlobalKey _wtCustomizationKey = GlobalKey(); // 🔹 New key for Fridge Customization
  final GlobalKey _wtNotificationHistoryKey = GlobalKey(); // 🔹 New key for Notification History
  final GlobalKey _wtPrivacyKey = GlobalKey();
  final GlobalKey _wtHelpKey = GlobalKey();
  final GlobalKey _wtAboutKey = GlobalKey();
  final GlobalKey _wtLogoutKey = GlobalKey();
  
  bool _showWalkthrough = false;
  List<WalkthroughStep> _currentSteps = [];

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
    _checkFirstVisit();
    _loadVibrationSettings(); // 📳 Initialize vibration preference
  }

  Future<void> _loadVibrationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _vibrationAlertsEnabled = prefs.getBool('vibration_alerts_enabled') ?? true;
      });
    }
  }

  Future<void> _checkFirstVisit() async {
    final visited = await SecureStorageService.getString('visited_settings_v2');
    if (visited == null) {
      _triggerWalkthrough();
    }
  }

  void _triggerWalkthrough() {
    setState(() {
      _currentSteps = [
        WalkthroughStep(
          targetKey: _wtAccountKey,
          title: "Your Profile",
          description: "Manage your Smridge identity, profile picture, and shared household permissions.",
        ),
        WalkthroughStep(
          targetKey: _wtActivityKey,
          title: "My Activity",
          description: "Review your detailed inventory history and AI-detected waste metrics.",
        ),
        WalkthroughStep(
          targetKey: _wtSecurityKey,
          title: "App Security",
          description: "Protect your fridge settings with a secondary PIN. Essential for shared households.",
        ),
        WalkthroughStep(
          targetKey: _wtThemeKey,
          title: "Visual Personalization",
          description: "Choose between Light, Dark, or cinematic Nebula themes for your clinical interface.",
        ),
        WalkthroughStep(
          targetKey: _wtHapticsKey,
          title: "Tactile Feedback",
          description: "Enable or disable precision vibrations for physical interaction confirmation.",
        ),
        WalkthroughStep(
          targetKey: _wtCustomizationKey,
          title: "Fridge Customization",
          description: "Personalize your Smridge's 3D colors and unique audio signatures (hum, door, alerts).",
        ),
        WalkthroughStep(
          targetKey: _wtNotificationHistoryKey,
          title: "Notification History",
          description: "Review all past alerts, expiry warnings, and system logs in one place.",
        ),
        WalkthroughStep(
          targetKey: _wtThresholdsKey,
          title: "Hardware Thresholds",
          description: "Calibrate ESP32 thresholds for temperature, humidity, and freshness alerts.",
        ),
        WalkthroughStep(
          targetKey: _wtPrivacyKey,
          title: "Data Sovereignty",
          description: "Review how our on-device AI processes your inventory data without cloud exposure.",
        ),
        WalkthroughStep(
          targetKey: _wtHelpKey,
          title: "Intelligent Support",
          description: "Access our futuristic FAQ and contact our zero-latency support team.",
        ),
        WalkthroughStep(
          targetKey: _wtAboutKey,
          title: "Ecosystem Specs",
          description: "View technical specifications and the version history of your Smridge OS.",
        ),
        WalkthroughStep(
          targetKey: _wtLogoutKey,
          title: "Session Control",
          description: "Securely end your current session and clear local biometric cache.",
        ),
      ];
      _showWalkthrough = true;
    });
    SecureStorageService.saveString('visited_settings_v2', 'true');
  }

  Future<void> _loadSecuritySettings() async {
    final pinEnabled = await SecureStorageService.isPinEnabled();
    if (mounted) {
      setState(() {
        _isPinEnabled = pinEnabled;
      });
    }
  }

  void _showPinSetupDialog({bool isVerifying = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinEntryScreen(
          isConfirming: !isVerifying, // isConfirming usually means "Set New PIN"
          onSuccess: () {
            if (isVerifying) {
              // Successfully verified old PIN, now set new one
              Navigator.pop(context);
              _showPinSetupDialog(isVerifying: false);
            } else {
              // Successfully set new PIN
              setState(() => _isPinEnabled = true);
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLight = themeProvider.currentTheme == ThemeType.light;
    final isDark = themeProvider.currentTheme == ThemeType.dark;
    
    Color textColor = isLight ? Colors.black87 : Colors.white;

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
        title: Text("Settings Hub", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)).animate().fadeIn(),
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
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Account Section
                        Text("ACCOUNT & PROFILE", style: TextStyle(color: isLight ? Colors.black54 : Colors.white54, fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildSettingsTile(
                          Icons.person_outline, 
                          "Account Details", 
                          isLight,
                          key: _wtAccountKey,
                          onTap: () {
                            if (widget.onProfileTap != null) widget.onProfileTap!();
                            else Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountProfileScreen()));
                          },
                        ),
                        _buildSettingsTile(
                          Icons.insights, 
                          "My Activity", 
                          isLight,
                          key: _wtActivityKey,
                          onTap: () {
                            if (widget.onActivityTap != null) widget.onActivityTap!();
                            else Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityScreen(onBack: () => Navigator.pop(context))));
                          },
                        ),
                        _buildSettingsTile(
                          Icons.history, 
                          "Notification History", 
                          isLight,
                          key: _wtNotificationHistoryKey,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationHistoryScreen())),
                        ),
                        
                        const SizedBox(height: 30),

                        // Security Section
                        Text("SECURITY", style: TextStyle(color: isLight ? Colors.black54 : Colors.white54, fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildSettingsTile(
                          Icons.lock_outline, 
                          "App Security PIN", 
                          isLight,
                          key: _wtSecurityKey, 
                          onTap: () => _showPinSetupDialog(isVerifying: _isPinEnabled),
                          trailing: Switch(
                            value: _isPinEnabled, 
                            activeColor: Colors.tealAccent,
                            onChanged: (val) {
                               if (val) _showPinSetupDialog(isVerifying: false);
                               else {
                                 // To disable PIN, we should also verify!
                                 Navigator.push(context, MaterialPageRoute(builder: (_) => PinEntryScreen(
                                   isConfirming: false,
                                   onSuccess: () {
                                     SecureStorageService.clearPin();
                                     setState(() => _isPinEnabled = false);
                                     Navigator.pop(context);
                                   },
                                 )));
                               }
                            }
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Preferences Section
                        Text("PREFERENCES", style: TextStyle(color: isLight ? Colors.black54 : Colors.white54, fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildSettingsTile(
                          Icons.palette_outlined, 
                          "Theme Customization", 
                          isLight,
                          key: _wtThemeKey, 
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeSettingsScreen())),
                        ),
                        _buildSettingsTile(
                          Icons.vibration, 
                          "Touch Haptics", 
                          isLight,
                          key: _wtHapticsKey,
                          trailing: Switch(
                            value: _hapticsEnabled,
                            activeColor: Colors.tealAccent,
                            onChanged: (val) {
                              setState(() => _hapticsEnabled = val);
                              HapticService.setEnabled(val);
                              if (val) HapticService.medium();
                            },
                          ),
                        ),
                        _buildSettingsTile(
                          Icons.notifications_active_outlined, 
                          "Vibration Alerts", 
                          isLight,
                          trailing: Switch(
                            value: _vibrationAlertsEnabled,
                            activeColor: Colors.tealAccent,
                            onChanged: (val) async {
                              setState(() => _vibrationAlertsEnabled = val);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('vibration_alerts_enabled', val);
                              if (val) HapticService.medium();
                            },
                          ),
                        ),

                        const SizedBox(height: 30),
                        
                        // 📡 Connectivity Section
                        Text("SMRIDGE CONNECTIVITY", style: TextStyle(color: isLight ? Colors.black54 : Colors.white54, fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        
                        Consumer<ConnectivityProvider>(
                          builder: (context, connectivity, child) {
                            final isConnected = connectivity.isConnected;
                            final statusColor = isConnected ? Colors.tealAccent : Colors.redAccent;
                            
                            return Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isLight ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 12, height: 12,
                                            decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                                          ).animate(onPlay: (c) => c.repeat()).scale(
                                            duration: 1500.ms,
                                            begin: const Offset(1, 1),
                                            end: const Offset(2.2, 2.2),
                                          ).fadeOut(),
                                          Container(
                                            width: 10, height: 10,
                                            decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor, boxShadow: [
                                              BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 8)
                                            ]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(isConnected ? "Hub Connected" : "Hub Offline", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text(isConnected ? "Active on ${connectivity.lastSsid ?? 'Local Network'}" : "No active link found", style: TextStyle(color: isLight ? Colors.black45 : Colors.white54, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => AddDeviceScreen(
                                            isReconnecting: isConnected,
                                            initialSsid: connectivity.lastSsid,
                                            initialPassword: connectivity.lastPassword,
                                          )));
                                        },
                                        style: TextButton.styleFrom(foregroundColor: statusColor),
                                        child: Text(isConnected ? "RECONNECT" : "PAIR NOW"),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 30),

                        // System Section
                        Text("SYSTEM & SUPPORT", style: TextStyle(color: isLight ? Colors.black54 : Colors.white54, fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildSettingsTile(
                          Icons.color_lens_outlined, 
                          "Fridge Customization", 
                          isLight,
                          key: _wtCustomizationKey, 
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen())),
                        ),
                        _buildSettingsTile(
                          Icons.settings_input_component, 
                          "Thresholds & Alerts", 
                          isLight,
                          key: _wtThresholdsKey, 
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceConfigScreen())),
                        ),
                        _buildSettingsTile(
                          Icons.privacy_tip_outlined, 
                          "Privacy & Data Safety", 
                          isLight,
                          key: _wtPrivacyKey,
                          onTap: () {
                            if (widget.onPrivacyTap != null) widget.onPrivacyTap!();
                            else Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                          },
                        ),
                        _buildSettingsTile(
                          Icons.help_outline, 
                          "Help & Smart Support", 
                          isLight,
                          key: _wtHelpKey,
                          onTap: () {
                            if (widget.onHelpTap != null) widget.onHelpTap!();
                            else Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                          },
                        ),
                        _buildSettingsTile(
                          Icons.info_outline, 
                          "About Smridge Ecosystem", 
                          isLight,
                          key: _wtAboutKey,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                        ),
                        
                        const SizedBox(height: 30),
                        Divider(color: isLight ? Colors.black12 : Colors.white10),
                        const SizedBox(height: 10),
                        
                        _buildSettingsTile(
                          Icons.logout, 
                          "Logout Session", 
                          isLight,
                          key: _wtLogoutKey,
                          isDestructive: true,
                          onTap: _showLogoutDialog,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          if (_showWalkthrough)
            AppWalkthrough(
              steps: _currentSteps,
              onFinish: () => setState(() => _showWalkthrough = false),
              onSkip: () => setState(() => _showWalkthrough = false),
            ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Logout",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                   BoxShadow(color: Colors.tealAccent.withOpacity(0.05), blurRadius: 40, spreadRadius: 5)
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.logout, color: Colors.redAccent, size: 32),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "End Session?",
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Are you sure you want to log out of Smridge? Your local inventory cache will be secured.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("CANCEL", style: TextStyle(color: Colors.white54, letterSpacing: 1.2)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () async {
                                HapticService.heavy();
                                await SecureStorageService.clearAll();
                                if (mounted) {
                                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                                }
                              },
                              child: const Text("LOGOUT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack).fadeIn(),
        );
      },
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, bool isLight, {Key? key, VoidCallback? onTap, bool isDestructive = false, Widget? trailing}) {
    Color textColor = isDestructive ? Colors.redAccent : (isLight ? Colors.black87 : Colors.white);
    Color iconColor = isDestructive ? Colors.redAccent : (isLight ? Colors.teal : Colors.tealAccent);
    Color bgColor = isDestructive ? Colors.redAccent.withOpacity(0.1) : (isLight ? Colors.grey.shade200 : Colors.white.withOpacity(0.1));

    return ListTile(
      key: key, 
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
      trailing: trailing ?? (isDestructive ? null : Icon(Icons.arrow_forward_ios, color: isLight ? Colors.black54 : Colors.white54, size: 16)),
      onTap: onTap,
    );
  }
}
