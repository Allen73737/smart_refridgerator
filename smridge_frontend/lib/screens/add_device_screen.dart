import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/premium_setup_visualizer.dart';
import '../widgets/wave_background.dart';
import '../utils/snackbar_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'home_screen.dart';

enum SetupStep {
  welcome,
  qrScan,
  connectDeviceWifi,   // Instruct connect to SMRIDGE_SETUP
  provisionHomeWifi,   // Enter home SSID & Pass -> Send to ESP
  reconnectHomeWifi,   // Instruct connect to HOME network before cloud linking
  nameDevice,
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
  String? _scannedDeviceId;
  final TextEditingController _deviceNameController = TextEditingController(text: "My Smridge");
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isScannerActive = false;
  bool _isProvisioning = false;
  
  List<String> _progressLogs = [];
  double _progressValue = 0.0;
  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  // --- LOGIC FOR STEP 2: QR SCAN ---
  void _onQrScanned(String? code) {
    if (code != null && code.isNotEmpty) {
      setState(() {
        _scannedDeviceId = code.trim().toUpperCase();
        _isScannerActive = false;
      });
      _nextStep(); // Move to connectDeviceWifi
    } else {
      SnackbarUtils.showError(context, "Invalid QR Code detected.");
    }
  }

  // --- LOGIC FOR STEP 3: HARDWARE PROVISIONING ---
  Future<void> _sendWifiCredentials() async {
    final ssid = _ssidController.text.trim();
    final pass = _passwordController.text.trim();

    if (ssid.isEmpty || pass.isEmpty) {
      SnackbarUtils.showWarning(context, "Please enter both SSID and Password.");
      return;
    }

    setState(() {
      _isProvisioning = true;
    });

    try {
      final url = Uri.parse('http://192.168.4.1/save?ssid=${Uri.encodeComponent(ssid)}&password=${Uri.encodeComponent(pass)}');
      
      // ESP32 WebServer is notoriously picky. Manually format the x-www-form-urlencoded string.
      final String rawBody = 'ssid=${Uri.encodeComponent(ssid)}&password=${Uri.encodeComponent(pass)}';

      var response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': rawBody.length.toString(),
        },
        body: rawBody,
      ).timeout(const Duration(seconds: 10));

      // 🔄 Fallback just in case
      if (response.statusCode == 404) {
        response = await http.get(url).timeout(const Duration(seconds: 5));
      }

      if (response.statusCode == 200 && response.body.toLowerCase().contains('saved')) {
        SnackbarUtils.showSuccess(context, "Credentials sent! ESP32 is restarting.");
        _nextStep(); // Move to reconnectHomeWifi
      } else {
        SnackbarUtils.showError(context, "ESP32 Error [${response.statusCode}]: ${response.body}");
      }
    } catch (e) {
      SnackbarUtils.showError(context, "Cannot reach fridge. Please turn OFF your Mobile Data/Cellular completely and try again.");
    } finally {
      setState(() {
        _isProvisioning = false;
      });
    }
  }

  // --- LOGIC FOR STEP 6: NAME DEVICE ---
  Future<void> _startRegistration() async {
    if (_deviceNameController.text.trim().isEmpty) {
      SnackbarUtils.showWarning(context, "Please enter a name for your fridge.");
      return;
    }

    _nextStep(); // Move to Processing
    _runRegistrationSequence();
  }

  // --- LOGIC FOR STEP 4: PROCESSING ---
  Future<void> _runRegistrationSequence() async {
    setState(() {
      _progressValue = 0.1; // 🚀 Immediate Feedback (prevents 0% hang)
      _progressLogs = ["🛡️ Checking security tokens..."];
    });

    final token = await SecureStorageService.getToken();
    if (token == null) {
       setState(() {
         _progressLogs.add("❌ Authentication Error: Token Missing");
         _progressValue = 0.0;
       });
       return;
    }

    setState(() {
      _progressLogs.add("📡 Linking device $_scannedDeviceId to cloud...");
      _progressValue = 0.4;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final result = await ApiService.addDevice(
        _scannedDeviceId!, 
        _deviceNameController.text, 
        token
      );

      if (result != null) {
        setState(() {
          _progressValue = 0.7;
          _progressLogs.add("✅ Device linked to account!");
        });
        
        await Future.delayed(const Duration(milliseconds: 1000));
        
        setState(() {
           _progressValue = 1.0;
           _progressLogs.add("✨ System ready.");
        });

        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) _nextStep(); // Move to Success
      } else {
        setState(() {
          _progressLogs.add("❌ Registration failed. Server error.");
          _progressValue = 0.0;
        });
      }
    } catch (e) {
      setState(() {
        _progressLogs.add("❌ Connection timeout. Device may be off.");
        _progressValue = 0.0;
      });
    }
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
      case SetupStep.qrScan:
        return _buildQrScan();
      case SetupStep.connectDeviceWifi:
        return _buildConnectDeviceWifi();
      case SetupStep.provisionHomeWifi:
        return _buildProvisionHomeWifi();
      case SetupStep.reconnectHomeWifi:
        return _buildReconnectHomeWifi();
      case SetupStep.nameDevice:
        return _buildNameDevice();
      case SetupStep.processing:
        return _buildProcessing();
      case SetupStep.success:
        return _buildSuccess();
    }
  }

  Widget _buildConnectDeviceWifi() {
    return _buildGlassCard(
      children: [
        const Icon(Icons.wifi_tethering, size: 60, color: Colors.tealAccent),
        const SizedBox(height: 24),
        Text(
          "CONNECT TO DEVICE",
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "1. Turn OFF your Mobile Data.\n2. Open your phone's Wi-Fi settings.\n3. Connect to the network: SmartFridge\n4. Password is: 12345678\n5. Wait for 'Connected' status, then return here.",
          textAlign: TextAlign.left,
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _nextStep,
            child: Text(
              "I'M CONNECTED",
              style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
        ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
      ],
    );
  }

  Widget _buildProvisionHomeWifi() {
    return _buildGlassCard(
      children: [
        const Icon(Icons.router, size: 60, color: Colors.tealAccent),
        const SizedBox(height: 24),
        Text(
          "ENTER HOME WI-FI",
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Please enter your home internet details. We will send this to your Smridge.",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _ssidController,
          label: "Wi-Fi Name (SSID)",
          icon: Icons.wifi,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          label: "Wi-Fi Password",
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isProvisioning ? null : _sendWifiCredentials,
            child: _isProvisioning 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black))
                : Text(
                    "SEND CREDENTIALS",
                    style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
          ),
        ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
      ],
    );
  }

  Widget _buildReconnectHomeWifi() {
    return _buildGlassCard(
      children: [
        const Icon(Icons.cloud_done_outlined, size: 60, color: Colors.tealAccent),
        const SizedBox(height: 24),
        Text(
          "RECONNECT HOME",
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Your fridge is now restarting!\n\nPlease reconnect your phone to your normal Home Wi-Fi internet before continuing.",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _nextStep,
            child: Text(
              "I'M RECONNECTED",
              style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
        ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
      ],
    );
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

  Widget _buildQrScan() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "SCAN DEVICE QR",
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ).animate().fadeIn().slideY(begin: -0.2),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.tealAccent.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(color: Colors.tealAccent.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
              ],
            ),
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      _onQrScanned(barcodes.first.rawValue);
                    }
                  },
                ),
                // Scanning Line Animation
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.tealAccent.withOpacity(0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.4, 0.5, 0.6],
                      ),
                    ),
                  ).animate(onPlay: (c) => c.repeat()).slideY(duration: 2.seconds, begin: -1, end: 1),
                ),
              ],
            ),
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 32),
        Text(
          "Point your camera at the QR code\nattached to your Smridge device.",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 40),
        TextButton.icon(
          onPressed: _prevStep,
          icon: const Icon(Icons.arrow_back, color: Colors.white54, size: 16),
          label: Text("BACK", style: GoogleFonts.outfit(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildNameDevice() {
    return _buildGlassCard(
      children: [
        const Icon(Icons.edit_note_outlined, size: 60, color: Colors.tealAccent),
        const SizedBox(height: 24),
        Text(
          "NAME YOUR FRIDGE",
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "DEVICE ID: $_scannedDeviceId",
          style: GoogleFonts.outfit(color: Colors.tealAccent.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _deviceNameController,
          label: "Device Nickname",
          icon: Icons.drive_file_rename_outline,
        ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),
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
            onPressed: _startRegistration,
            child: Text(
              "FINISH SETUP",
              style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
        ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _prevStep,
          child: Text("SCAN AGAIN", style: GoogleFonts.outfit(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.tealAccent, size: 20),
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
              onPressed: () => setState(() => _currentStep = SetupStep.qrScan),
              child: const Text("RETRY SCANNING"),
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
