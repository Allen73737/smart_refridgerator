import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
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
  const AddDeviceScreen({super.key});

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
    int attempts = 0;
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      attempts++;
      final token = await SecureStorageService.getToken();
      if (token == null) {
        timer.cancel();
        return;
      }

      final devices = await ApiService.getUserDevices(token);
      if (devices.isNotEmpty) {
        timer.cancel();
        setState(() {
          _progressLogs.add("✅ Device Registered Successfully!");
          _progressValue = 1.0;
        });
        await Future.delayed(const Duration(seconds: 1));
        _nextStep(); // Go to Success
      }

      if (attempts > 20) {
        timer.cancel();
        setState(() {
          _progressLogs.add("⚠️ Registration Timeout. Please check device LED.");
        });
      }
    });
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
            child: IconButton(
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
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return _buildGlassCard(
      children: [
        const Icon(Icons.kitchen_outlined, size: 80, color: Colors.tealAccent)
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 2.seconds),
        const SizedBox(height: 24),
        Text(
          "Add Your Smart Device",
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Set up your device in just a few steps to start monitoring your fridge.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 32),
        const Row(
          children: [
            Icon(Icons.power_settings_new, color: Colors.tealAccent, size: 18),
            SizedBox(width: 12),
            Expanded(child: Text("Power on your ESP32 device", style: TextStyle(color: Colors.white))),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.bluetooth_searching, color: Colors.tealAccent, size: 18),
            SizedBox(width: 12),
            Expanded(child: Text("Keep your phone nearby", style: TextStyle(color: Colors.white))),
          ],
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _nextStep,
            child: const Text("Start Setup", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildDetection() {
    return _buildGlassCard(
      children: [
        SizedBox(
          height: 100,
          width: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2),
              const Icon(Icons.wifi_find, color: Colors.tealAccent, size: 40),
            ],
          ),
        ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.1, 1.1), duration: 1.seconds, curve: Curves.easeInOut),
        const SizedBox(height: 24),
        const Text(
          "Searching for device...",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            text: "Please connect your phone to the ",
            style: TextStyle(color: Colors.white70, fontSize: 14),
            children: [
              TextSpan(text: "SMRIDGE_SETUP", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
              TextSpan(text: " WiFi network in your settings."),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          "Current WiFi: ${_currentSsid ?? 'Checking...'}",
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => launchUrl(Uri.parse('package:android_settings/wifi_settings')), // Fallback placeholder
                child: const Text("WiFi Settings"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _checkEspConnection,
                child: _isCheckingWifi ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text("I've Connected"),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: _prevStep,
          child: const Text("Go Back", style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildWifiConfig() {
    return _buildGlassCard(
      children: [
        const Icon(Icons.wifi_lock, size: 60, color: Colors.tealAccent),
        const SizedBox(height: 24),
        const Text(
          "Connect Device to WiFi",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          "The device will use these credentials to connect to the internet.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _wifiSsidController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
             labelText: "WiFi Name",
             labelStyle: const TextStyle(color: Colors.white70),
             prefixIcon: const Icon(Icons.wifi, color: Colors.tealAccent, size: 20),
             enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _wifiPasswordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
             labelText: "WiFi Password",
             labelStyle: const TextStyle(color: Colors.white70),
             prefixIcon: const Icon(Icons.lock_outline, color: Colors.tealAccent, size: 20),
             suffixIcon: IconButton(
               icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 18),
               onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
             ),
             enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _startConfiguration,
            child: const Text("Connect Device", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        TextButton(
          onPressed: _prevStep,
          child: const Text("Go Back", style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildProcessing() {
    return _buildGlassCard(
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 120,
          width: 120,
          child: CircularProgressIndicator(
            value: _progressValue,
            strokeWidth: 8,
            backgroundColor: Colors.white12,
            color: Colors.tealAccent,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          "${(_progressValue * 100).toInt()}%",
          style: GoogleFonts.orbitron(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
        Container(
          height: 120,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            itemCount: _progressLogs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _progressLogs[index],
                  style: TextStyle(
                    color: _progressLogs[index].startsWith("❌") ? Colors.redAccent : Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              );
            },
          ),
        ),
        if (_progressLogs.any((log) => log.startsWith("❌")))
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: ElevatedButton(
              onPressed: () => setState(() => _currentStep = SetupStep.wifiConfig),
              child: const Text("Retry"),
            ),
          )
      ],
    );
  }

  Widget _buildSuccess() {
    return _buildGlassCard(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.tealAccent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 60, color: Colors.black),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text(
          "Device Paired!",
          style: GoogleFonts.orbitron(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Your Smridge device is now connected and registering data.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text("Go to Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
