import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/premium_setup_visualizer.dart';
import '../widgets/wave_background.dart';
import '../utils/snackbar_utils.dart';
import 'home_screen.dart';

enum SetupStep {
  welcome,
  detection,
  wifiConfig,
  processing,
  success
}

class AddDeviceScreen extends StatefulWidget {
  final bool isReconnecting;
  final String? initialSsid;
  final String? initialPassword;

  const AddDeviceScreen({
    super.key,
    this.isReconnecting = false,
    this.initialSsid,
    this.initialPassword,
  });

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  SetupStep _currentStep = SetupStep.welcome;
  final NetworkInfo _networkInfo = NetworkInfo();
  
  String? _currentSsid;
  bool _isCheckingWifi = false;
  
  final TextEditingController _wifiSsidController = TextEditingController();
  final TextEditingController _wifiPasswordController = TextEditingController();
  bool _obscurePassword = true;
  
  List<String> _progressLogs = [];
  double _progressValue = 0.0;
  
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isReconnecting) {
      _wifiSsidController.text = widget.initialSsid ?? '';
      _wifiPasswordController.text = widget.initialPassword ?? '';
      _currentStep = SetupStep.wifiConfig; // Jump to WiFi config directly for reconnection
    }
    _loadCurrentWifi();
  }

  Future<void> _loadCurrentWifi() async {
    try {
      String? ssid = await _networkInfo.getWifiName();
      // Remove quotes if present
      if (ssid != null && ssid.startsWith('"') && ssid.endsWith('"')) {
        ssid = ssid.substring(1, ssid.length - 1);
      }
      setState(() {
        _currentSsid = ssid;
        if (ssid != null && !ssid.contains("SMRIDGE_SETUP")) {
           _wifiSsidController.text = ssid;
        }
      });
    } catch (e) {
      print("Error getting WiFi name: $e");
    }
  }

  void _nextStep() {
    setState(() {
      int nextIndex = _currentStep.index + 1;
      if (nextIndex < SetupStep.values.length) {
        _currentStep = SetupStep.values[nextIndex];
      }
    });
  }

  void _prevStep() {
    setState(() {
      int prevIndex = _currentStep.index - 1;
      if (prevIndex >= 0) {
        _currentStep = SetupStep.values[prevIndex];
      }
    });
  }

  // --- LOGIC FOR STEP 2: DETECTION ---
  Future<void> _checkEspConnection() async {
    setState(() => _isCheckingWifi = true);
    await _loadCurrentWifi();
    setState(() => _isCheckingWifi = false);

    if (_currentSsid != null && _currentSsid!.toUpperCase().contains("SMRIDGE_SETUP")) {
      _nextStep();
    } else {
      SnackbarUtils.showWarning(context, "Not connected to SMRIDGE_SETUP. Please check your WiFi settings.");
    }
  }

  // --- LOGIC FOR STEP 3: WIFI CONFIG ---
  Future<void> _startConfiguration() async {
    if (_wifiSsidController.text.isEmpty || _wifiPasswordController.text.isEmpty) {
      SnackbarUtils.showWarning(context, "Please enter both SSID and Password");
      return;
    }

    _nextStep(); // Move to Processing
    _runProvisioningSequence();
  }

  // --- LOGIC FOR STEP 4: PROCESSING ---
  Future<void> _runProvisioningSequence() async {
    setState(() {
      _progressLogs = ["📡 Connected to device"];
      _progressValue = 0.2;
    });

    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _progressLogs.add("⏳ Sending WiFi credentials...");
      _progressValue = 0.4;
    });

    bool sent = await ApiService.connectToEsp(
      _wifiSsidController.text,
      _wifiPasswordController.text,
    );

    if (!sent) {
       _progressLogs.add("❌ Failed to send credentials. Check connection.");
       return;
    }

    setState(() {
      _progressLogs.add("⏳ Device connecting to network...");
      _progressValue = 0.6;
    });

    await Future.delayed(const Duration(seconds: 5));

    setState(() {
      _progressLogs.add("⏳ Registering device to backend...");
      _progressValue = 0.8;
    });

    // Start Polling Backend for device registration
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final token = await SecureStorageService.getToken();
      if (token == null) return;
      
      final devices = await ApiService.getUserDevices(token);
      if (devices.isNotEmpty) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _progressValue = 1.0;
            _progressLogs.add("✅ Device synchronized successfully!");
          });
        }
        
        // 💾 Save credentials locally for future "Premium Reconnect"
        await SecureStorageService.saveWifiCredentials(
          _wifiSsidController.text, 
          _wifiPasswordController.text
        );

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) _nextStep(); // Move to Success
      }
    });
  }

  void _showSetupSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2027).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 25),
              Text("SETUP CONFIGURATION", style: GoogleFonts.orbitron(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
              const SizedBox(height: 30),
              _buildConfigTile(Icons.sync_outlined, "Auto-Reconnect", "Try connecting if signal drops", true),
              _buildConfigTile(Icons.wifi_tethering_outlined, "Aggressive Scan", "Find hidden devices", false),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.signal_wifi_4_bar_outlined, color: Colors.white54, size: 18),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Sensitivity Threshold", style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
                        Slider(
                          value: 0.7,
                          onChanged: (_) {},
                          activeColor: Colors.tealAccent,
                          inactiveColor: Colors.white10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Shortcut to System WiFi
              _buildConfigTile(
                Icons.wifi_find_outlined, 
                "System WiFi Settings", 
                "Connect to SMRIDGE_SETUP manually", 
                false,
                onTap: () => launchUrl(Uri.parse('package:android_settings/wifi_settings')),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigTile(IconData icon, String title, String sub, bool initialVal, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 22),
            const SizedBox(width: 15),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                Text(sub, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
              ]),
            ),
            if (onTap == null) Switch(value: initialVal, onChanged: (_) {}, activeColor: Colors.tealAccent),
            if (onTap != null) const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F2027), Color(0xFF203A43)],
              ),
            ),
          ),
          const Positioned.fill(child: WaveBackground()),

          // Content
          SafeArea(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                   return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
                },
                child: _buildCurrentStep(),
              ),
            ),
          ),

          // Bypass Icon
          Positioned(
            top: 50,
            right: 20,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                  onPressed: _showSetupSettings,
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.skip_next_outlined, color: Colors.white70),
                  tooltip: "Bypass Setup",
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ).animate().fadeIn(delay: 1.seconds),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case SetupStep.welcome:
        return _buildWelcome();
      case SetupStep.detection:
        return _buildDetection();
      case SetupStep.wifiConfig:
        return _buildWifiConfig();
      case SetupStep.processing:
        return _buildProcessing();
      case SetupStep.success:
        return _buildSuccess();
    }
  }

  Widget _buildGlassCard({required List<Widget> children, double width = 340}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
  }

  Widget _buildWelcome() {
    return _buildGlassCard(
      children: [
        Hero(
          tag: 'device_icon',
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.tealAccent.withOpacity(0.15),
              boxShadow: [
                BoxShadow(
                  color: Colors.tealAccent.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.kitchen_outlined, size: 80, color: Colors.tealAccent),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 2.seconds, colors: [Colors.tealAccent, Colors.white, Colors.tealAccent])
            .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1500.ms, curve: Curves.easeInOut),
        const SizedBox(height: 32),
        Text(
          "Add Your Smart Device",
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
        const SizedBox(height: 16),
        Text(
          "Set up your device in just a few steps to start monitoring your fridge.",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15, height: 1.5),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        const SizedBox(height: 40),
        Column(
          children: [
            _buildInfoRow(Icons.power_settings_new, "Power on your ESP32 device"),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.wifi_tethering, "Stay within range of the device"),
          ],
        ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.tealAccent.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _nextStep,
              child: Text(
                "START SETUP",
                style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 1.seconds).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.tealAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.tealAccent, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDetection() {
    return _buildGlassCard(
      children: [
        const PremiumSetupVisualizer(),
        const SizedBox(height: 32),
        Text(
          "Searching for device...",
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
        const SizedBox(height: 24),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15, height: 1.5),
            children: const [
              TextSpan(text: "Please connect your phone to the "),
              TextSpan(text: "SMRIDGE_SETUP", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
              TextSpan(text: " WiFi network in your settings."),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi, color: Colors.white54, size: 14),
              const SizedBox(width: 8),
              Text(
                "Current: ${_currentSsid ?? 'Checking...'}",
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _showSetupSettings,
                child: Text("SETTINGS", style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _checkEspConnection,
                child: _isCheckingWifi 
                  ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                  : Text("CONNECTED", style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _prevStep,
          child: Text("GO BACK", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, letterSpacing: 1)),
        ),
      ],
    );
  }

  Widget _buildWifiConfig() {
    return _buildGlassCard(
      children: [
        const Hero(
          tag: 'device_icon',
          child: Icon(Icons.wifi_lock, size: 60, color: Colors.tealAccent),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        Text(
          "Device WiFi Setup",
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Target SSID: ${(_currentSsid != null && _currentSsid!.toUpperCase().contains('SMRIDGE_SETUP')) ? 'ESP32 Device' : 'Unknown'}",
          style: GoogleFonts.outfit(color: Colors.tealAccent.withOpacity(0.7), fontSize: 13),
        ),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _wifiSsidController,
          label: "Network SSID",
          icon: Icons.wifi,
        ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _wifiPasswordController,
          label: "Password",
          icon: Icons.lock_outline,
          isPassword: true,
        ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _startConfiguration,
            child: Text(
              "CONNECT DEVICE",
              style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
        ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _prevStep,
          child: Text("GO BACK", style: GoogleFonts.outfit(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.tealAccent, size: 20),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 18),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          floatingLabelStyle: GoogleFonts.outfit(color: Colors.tealAccent),
        ),
      ),
    );
  }

  Widget _buildProcessing() {
    return _buildGlassCard(
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 160,
          width: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _progressValue,
                strokeWidth: 4,
                backgroundColor: Colors.white.withOpacity(0.05),
                color: Colors.tealAccent,
              ),
              Container(
                margin: const EdgeInsets.all(15),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.tealAccent.withOpacity(0.05),
                ),
                child: Text(
                  "${(_progressValue * 100).toInt()}%",
                  style: GoogleFonts.orbitron(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
        const SizedBox(height: 40),
        Text(
          "CONFIGURING SYSTEM",
          style: GoogleFonts.orbitron(
            color: Colors.tealAccent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 1.seconds).fadeOut(duration: 1.seconds),
        const SizedBox(height: 32),
        Container(
          height: 140,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.1)),
          ),
          child: ListView.builder(
            itemCount: _progressLogs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      "> ",
                      style: GoogleFonts.sourceCodePro(color: Colors.tealAccent, fontSize: 12),
                    ),
                    Expanded(
                      child: Text(
                        _progressLogs[index],
                        style: GoogleFonts.sourceCodePro(
                          color: _progressLogs[index].startsWith("❌") ? Colors.redAccent : Colors.white70,
                          fontSize: 12,
                        ),
                      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_progressLogs.any((log) => log.startsWith("❌")))
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => setState(() => _currentStep = SetupStep.wifiConfig),
              child: const Text("RETRY CONNECTION"),
            ),
          )
      ],
    );
  }

  Widget _buildSuccess() {
    return _buildGlassCard(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Expanding Background Rings
            ...List.generate(2, (index) => 
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.3), width: 2),
                ),
              ).animate().scale(
                duration: 1.seconds,
                delay: (index * 400).ms,
                begin: const Offset(1, 1),
                end: const Offset(2, 2),
              ).fadeOut()
            ),
            // Check Circle
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.tealAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 50, color: Colors.black),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          "PAIRING COMPLETE",
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        const SizedBox(height: 16),
        Text(
          "Your Smridge device is successfully registered. Sensors are now transmitting live data.",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15, height: 1.5),
        ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
            child: Text(
              "ACCESS DASHBOARD",
              style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
        ).animate().fadeIn(delay: 800.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
      ],
    );
  }
}
