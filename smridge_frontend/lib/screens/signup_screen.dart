import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'add_device_screen.dart';
import '../services/api_service.dart';
import '../widgets/smart_loader.dart';
import '../widgets/wave_background.dart';
import '../utils/snackbar_utils.dart';
import '../services/secure_storage_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  Future<void> register() async {
    if (!formKey.currentState!.validate()) return;

    if (passwordController.text != confirmPasswordController.text) {
      SnackbarUtils.showWarning(context, "Passwords do not match");
      return;
    }

    setState(() => isLoading = true);
    
    final data = await ApiService.signup(nameController.text, emailController.text, passwordController.text);

    if (!mounted) return;
    setState(() => isLoading = false);

    if (data != null) {
      SnackbarUtils.showSuccess(context, "Registration Successful! Logging in...");
      
      // Auto-login after signup
      setState(() => isLoading = true);
      final loginData = await ApiService.login(emailController.text, passwordController.text);
      if (!mounted) return;
      setState(() => isLoading = false);

      if (loginData != null) {
        final token = loginData['token'];
        final userId = loginData['user']['_id'];
        await SecureStorageService.saveToken(token);
        await SecureStorageService.saveUserId(userId);

        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (_, __, ___) => const AddDeviceScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
      }
    } else {
      SnackbarUtils.showError(context, "Registration Failed. User might already exist.");
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Animated Background
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

          // 🔹 Glassmorphic Form Container
          Center(
            child: SingleChildScrollView(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ]
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ).animate().slideY(begin: -0.5, duration: 800.ms).fade(),

                        const SizedBox(height: 30),

                        TextFormField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                            prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return "Enter your name";
                            return null;
                          },
                        ).animate().slideX(begin: -0.2).fade(delay: 50.ms),

                        const SizedBox(height: 20),

                        TextFormField(
                          controller: emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Email",
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return "Enter email";
                            if (!value.contains("@")) return "Invalid email";
                            return null;
                          },
                        ).animate().slideX(begin: -0.2).fade(delay: 100.ms),

                        const SizedBox(height: 20),

                        TextFormField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Password",
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                            suffixIcon: IconButton(
                              icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                              onPressed: () => setState(() => obscurePassword = !obscurePassword),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 6) return "Password must be 6+ chars";
                            return null;
                          },
                        ).animate().slideX(begin: 0.2).fade(delay: 200.ms),

                        const SizedBox(height: 20),

                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirmPassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                            prefixIcon: const Icon(Icons.lock_reset, color: Colors.white70),
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                              onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return "Confirm your password";
                            return null;
                          },
                        ).animate().slideX(begin: -0.2).fade(delay: 300.ms),

                        const SizedBox(height: 40),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent.withOpacity(0.8),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 10,
                            ),
                            onPressed: register,
                            child: const Text("Register", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ),
                        ).animate().scale(delay: 400.ms).fade(),
                        
                        const SizedBox(height: 15),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Back to Login", style: TextStyle(color: Colors.white70)),
                        ).animate().fade(delay: 500.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ),
          ).animate().fadeIn(duration: 1.seconds),

          // 🔹 Loader Overlay
          if (isLoading)
            const Positioned.fill(
              child: SmartLoader(message: "Creating Account..."),
            ),
        ],
      ),
    );
  }
}
