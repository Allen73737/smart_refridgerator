import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/wave_background.dart';
import '../widgets/smart_loader.dart';
import '../utils/snackbar_utils.dart';

enum _RecoveryStep { email, code, newPassword, done }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _RecoveryStep _step = _RecoveryStep.email;
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  int _remaining = 0;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    if (_emailController.text.trim().isEmpty) {
      SnackbarUtils.showWarning(context, "Enter your email");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.forgotPassword(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _remaining = result?['remaining'] ?? 0;
        _step = _RecoveryStep.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackbarUtils.showError(context, e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      SnackbarUtils.showWarning(context, "Passwords do not match");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.resetPassword(
        _emailController.text.trim(),
        _codeController.text.trim(),
        _newPasswordController.text,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _remaining = result?['remaining'] ?? 0;
        _step = _RecoveryStep.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackbarUtils.showError(context, e.toString().replaceAll("Exception: ", ""));
    }
  }

  Widget _buildStepIndicator() {
    final steps = ["Email", "Code", "Password", "Done"];
    final currentIndex = _step.index;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        final isActive = i <= currentIndex;
        return Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.tealAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                border: Border.all(color: isActive ? Colors.tealAccent : Colors.white24, width: 1.5),
              ),
              child: Center(
                child: i < currentIndex
                    ? const Icon(Icons.check, size: 14, color: Colors.tealAccent)
                    : Text("${i + 1}", style: TextStyle(fontSize: 11, color: isActive ? Colors.tealAccent : Colors.white30, fontWeight: FontWeight.bold)),
              ),
            ),
            if (i < steps.length - 1)
              Container(width: 30, height: 1.5, color: isActive ? Colors.tealAccent.withOpacity(0.3) : Colors.white10),
          ],
        );
      }),
    ).animate().fadeIn(delay: 200.ms);
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
      prefixIcon: Icon(icon, color: Colors.white70),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.email_outlined, color: Colors.tealAccent, size: 48)
            .animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 16),
        Text("Enter your email", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600))
            .animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 6),
        Text("We'll verify your account exists", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13))
            .animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 28),
        TextField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration("Email Address", Icons.alternate_email),
        ).animate().slideX(begin: -0.15).fadeIn(delay: 300.ms),
        const SizedBox(height: 36),
        _buildActionButton("VERIFY ACCOUNT", _verifyEmail),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.vpn_key_outlined, color: Colors.orangeAccent, size: 48)
              .animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text("Enter Backup Code", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600))
              .animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 6),
          Text("$_remaining codes remaining", style: GoogleFonts.outfit(color: Colors.tealAccent, fontSize: 13))
              .animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 28),
          TextFormField(
            controller: _codeController,
            style: GoogleFonts.jetBrainsMono(color: Colors.tealAccent, fontSize: 18, letterSpacing: 2),
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            decoration: _inputDecoration("XXXX-XXXX", Icons.lock_open_rounded),
            validator: (v) => (v == null || v.trim().length < 5) ? "Enter a valid backup code" : null,
          ).animate().slideX(begin: -0.15).fadeIn(delay: 300.ms),
          const SizedBox(height: 24),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("New Password", Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 8) return "Min 8 characters";
              if (!RegExp(r'[A-Z]').hasMatch(v)) return "Need uppercase letter";
              if (!RegExp(r'[0-9]').hasMatch(v)) return "Need a number";
              if (!RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"|,.<>/?]').hasMatch(v)) return "Need special char";
              return null;
            },
          ).animate().slideX(begin: 0.15).fadeIn(delay: 400.ms),
          const SizedBox(height: 20),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Confirm Password", Icons.lock_reset).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? "Confirm your password" : null,
          ).animate().slideX(begin: -0.15).fadeIn(delay: 500.ms),
          const SizedBox(height: 36),
          _buildActionButton("RESET PASSWORD", _resetPassword),
        ],
      ),
    );
  }

  Widget _buildDoneStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.tealAccent.withOpacity(0.15),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
          ),
          child: const Icon(Icons.check_circle_outline, color: Colors.tealAccent, size: 48),
        ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        Text("Password Reset!", style: GoogleFonts.orbitron(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))
            .animate().fadeIn(delay: 300.ms),
        const SizedBox(height: 12),
        Text("$_remaining backup codes remaining", style: GoogleFonts.outfit(color: Colors.tealAccent, fontSize: 14))
            .animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 8),
        Text("You can now login with your new password.",
          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 500.ms),
        const SizedBox(height: 36),
        _buildActionButton("BACK TO LOGIN", () => Navigator.pop(context)),
      ],
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.tealAccent.withOpacity(0.85),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 8,
        ),
        onPressed: onPressed,
        child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
      ),
    ).animate().scale(delay: 600.ms).fadeIn();
  }

  @override
  Widget build(BuildContext context) {
    Widget stepContent;
    switch (_step) {
      case _RecoveryStep.email:
        stepContent = _buildEmailStep();
        break;
      case _RecoveryStep.code:
        stepContent = _buildCodeStep();
        break;
      case _RecoveryStep.newPassword:
      case _RecoveryStep.done:
        stepContent = _buildDoneStep();
        break;
    }

    return Scaffold(
      body: Stack(
        children: [
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

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 20),
                      onPressed: () {
                        if (_step == _RecoveryStep.email || _step == _RecoveryStep.done) {
                          Navigator.pop(context);
                        } else {
                          setState(() => _step = _RecoveryStep.email);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text("ACCOUNT RECOVERY",
                    style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                  ).animate().fadeIn().slideY(begin: -0.3),
                  const SizedBox(height: 20),
                  _buildStepIndicator(),
                  const SizedBox(height: 32),

                  // Step Content Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, spreadRadius: 5),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                              child: child,
                            ),
                          ),
                          child: KeyedSubtree(key: ValueKey(_step), child: stepContent),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          if (_isLoading)
            const Positioned.fill(child: SmartLoader(message: "Verifying...")),
        ],
      ),
    );
  }
}
