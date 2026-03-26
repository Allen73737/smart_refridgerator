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
import 'device_config_screen.dart';
import 'about_screen.dart';
import 'notification_history_screen.dart';
import '../services/secure_storage_service.dart';
import '../services/haptic_service.dart';
import 'login_screen.dart';
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
  
  final GlobalKey _wtAccountKey = GlobalKey();
  final GlobalKey _wtActivityKey = GlobalKey();
  final GlobalKey _wtSecurityKey = GlobalKey();
  final GlobalKey _wtThemeKey = GlobalKey();
  final GlobalKey _wtHapticsKey = GlobalKey();
  final GlobalKey _wtAdvancedKey = GlobalKey();
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
          title: "Consumption Logs",
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
          targetKey: _wtAdvancedKey,
          title: "Hardware Sync",
          description: "Calibrate ESP32 weight sensors and configure zero-latency backend endpoints.",
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

  void _showPinSetupDialog() {
    TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Set App PIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter a 4-digit PIN to secure your app access.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 10),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterStyle: const TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent.withOpacity(0.5))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
            onPressed: () async {
              if (pinController.text.length == 4) {
                await SecureStorageService.savePin(pinController.text);
                setState(() => _isPinEnabled = true);
                if (mounted) Navigator.pop(context);
                HapticService.heavy();
              }
            },
            child: const Text("Save"),
          ),
        ],
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
                          "My Consumption Activity", 
                          isLight,
                          key: _wtActivityKey,
                          onTap: () {
                            if (widget.onActivityTap != null) widget.onActivityTap!();
                            // If no general activity tap passed, we can go to analytics or history
                            else Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()));
                          },
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
                          onTap: _showPinSetupDialog,
                          trailing: Switch(
                            value: _isPinEnabled, 
                            activeColor: Colors.tealAccent,
                            onChanged: (val) {
                               if (val) _showPinSetupDialog();
                               else {
                                 SecureStorageService.clearPin();
                                 setState(() => _isPinEnabled = false);
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

                        const SizedBox(height: 30),

                        // System Section
                        Text("SYSTEM & SUPPORT", style: TextStyle(color: isLight ? Colors.black54 : Colors.white54, fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildSettingsTile(
                          Icons.settings_input_component, 
                          "Advanced Hub Config", 
                          isLight,
                          key: _wtAdvancedKey, 
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A33),
        title: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to logout from your Smridge session?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await SecureStorageService.clearAll();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              }
            },
            child: const Text("Logout"),
          ),
        ],
      ),
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
