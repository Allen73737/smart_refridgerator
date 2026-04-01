import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../services/haptic_service.dart';
import 'home_screen.dart';
import '../widgets/wave_background.dart';
import 'package:google_fonts/google_fonts.dart';

class PinEntryScreen extends StatefulWidget {
  final bool isConfirming; // If true, we are setting a new pin
  final VoidCallback? onSuccess;

  const PinEntryScreen({super.key, this.isConfirming = false, this.onSuccess});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String _enteredPin = "";
  String _errorMessage = "";
  bool _isLocked = false;
  
  // 🔐 Confirmation Logic
  String? _firstPin;
  bool _isConfirmingStep = false;
  
  // 🛡️ Lockout Logic
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkLockout();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final lockout = await SecureStorageService.getLockoutUntil();
    if (lockout != null && lockout.isAfter(DateTime.now())) {
      setState(() {
        _lockoutUntil = lockout;
        _isLocked = true;
        _errorMessage = "Too many attempts. Locked until ${DateFormat('HH:mm:ss').format(lockout)}";
      });
      _startLockoutTimer(lockout.difference(DateTime.now()));
    } else {
      _failedAttempts = await SecureStorageService.getFailedAttempts();
    }
  }

  void _startLockoutTimer(Duration duration) {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _isLocked = false;
          _lockoutUntil = null;
          _errorMessage = "";
          _failedAttempts = 0;
        });
        SecureStorageService.setFailedAttempts(0);
        SecureStorageService.setLockoutUntil(null);
      }
    });
  }

  void _onDigitPress(String digit) {
    if (_isLocked || _enteredPin.length >= 4) return;
    HapticService.light();
    setState(() {
      _enteredPin += digit;
      _errorMessage = "";
    });

    if (_enteredPin.length == 4) {
      if (widget.isConfirming) {
        _handleSetupPin();
      } else {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty || _isLocked) return;
    HapticService.selection();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _handleSetupPin() async {
    setState(() => _isLocked = true);
    await Future.delayed(const Duration(milliseconds: 400));

    if (!_isConfirmingStep) {
      // First step of setup
      setState(() {
        _firstPin = _enteredPin;
        _enteredPin = "";
        _isConfirmingStep = true;
        _isLocked = false;
        _errorMessage = "Now confirm your PIN";
      });
      HapticService.medium();
    } else {
      // Confirmation step
      if (_enteredPin == _firstPin) {
        // Success!
        final token = await SecureStorageService.getToken();
        if (token != null) {
          // 🚀 SYNC PIN TO BACKEND
          await ApiService.updateProfile("", "", token, appPin: _enteredPin);
        }
        await SecureStorageService.savePin(_enteredPin);
        HapticService.heavy();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("PIN Secured Successfully"), backgroundColor: Colors.teal),
           );
           if (widget.onSuccess != null) widget.onSuccess!();
           else Navigator.pop(context);
        }
      } else {
        // Mismatch
        HapticService.error();
        setState(() {
          _errorMessage = "PINs do not match. Start over.";
          _enteredPin = "";
          _firstPin = null;
          _isConfirmingStep = false;
          _isLocked = false;
        });
      }
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isLocked = true);
    final savedPin = await SecureStorageService.getPin();

    await Future.delayed(const Duration(milliseconds: 300));

    if (_enteredPin == savedPin) {
      HapticService.heavy();
      await SecureStorageService.setFailedAttempts(0);
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween<double>(begin: 1.2, end: 1.0).animate(animation), child: child));
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        }
      }
    } else {
      HapticService.error();
      _failedAttempts++;
      await SecureStorageService.setFailedAttempts(_failedAttempts);
      
      if (_failedAttempts >= 5) {
        final lockoutTime = DateTime.now().add(const Duration(seconds: 30));
        await SecureStorageService.setLockoutUntil(lockoutTime);
        setState(() {
          _lockoutUntil = lockoutTime;
          _errorMessage = "Too many attempts. Locked for 30s.";
          _enteredPin = "";
          _isLocked = true;
        });
        _startLockoutTimer(const Duration(seconds: 30));
      } else {
        setState(() {
          _errorMessage = "Incorrect PIN. Attempt $_failedAttempts/5";
          _enteredPin = "";
          _isLocked = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: WaveBackground()),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                
                // 🛡️ Security Icon
                const Icon(Icons.lock_person_outlined, color: Colors.tealAccent, size: 60)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(duration: 2.seconds, color: Colors.white24)
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), curve: Curves.easeInOut),

                const SizedBox(height: 20),
                
                Text(
                  widget.isConfirming ? "SETUP SECURITY" : "IDENTITY VERIFIED",
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2),

                const SizedBox(height: 10),
                
                Text(
                  _isConfirmingStep 
                      ? "Confirm your new 4-digit PIN" 
                      : (widget.isConfirming ? "Enter a new 4-digit PIN" : "Verification required to proceed"),
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 50),

                // 🔢 PIN Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    bool isFilled = _enteredPin.length > index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? Colors.tealAccent : Colors.transparent,
                        border: Border.all(color: Colors.tealAccent.withOpacity(0.5), width: 2),
                        boxShadow: isFilled ? [BoxShadow(color: Colors.tealAccent.withOpacity(0.6), blurRadius: 15)] : [],
                      ),
                    ).animate(target: isFilled ? 1 : 0).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), curve: Curves.elasticOut);
                  }),
                ),

                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent))
                      .animate().shake(duration: 400.ms),
                  ),

                const Spacer(),

                // ⌨️ Custom Numpad
                Container(
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            _buildNumpadRow(["1", "2", "3"]),
                            const SizedBox(height: 20),
                            _buildNumpadRow(["4", "5", "6"]),
                            const SizedBox(height: 20),
                            _buildNumpadRow(["7", "8", "9"]),
                            const SizedBox(height: 20),
                            _buildNumpadRow([null, "0", "backspace"]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().slideY(begin: 0.5, duration: 800.ms, curve: Curves.easeOutQuart),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String?> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key == null) return const SizedBox(width: 80);
        if (key == "backspace") {
          return _buildNumpadButton(
            IconButton(
              icon: const Icon(Icons.backspace_outlined, color: Colors.white70),
              onPressed: _onBackspace,
            ),
          );
        }
        return _buildNumpadButton(
          TextButton(
            onPressed: () => _onDigitPress(key),
            child: Text(
              key,
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.normal),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumpadButton(Widget child) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.03),
      ),
      child: Center(child: child),
    ).animate().scale(begin: const Offset(0.5, 0.5), duration: 400.ms, curve: Curves.easeOutBack);
  }
}
