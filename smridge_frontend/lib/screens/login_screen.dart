import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import '../services/api_service.dart';
import '../widgets/smart_loader.dart';
import '../widgets/wave_background.dart';
import '../utils/snackbar_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> navigateToHome() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      showMessage("Please enter both email and password");
      return;
    }

    setState(() => isLoading = true);
    
    final token = await ApiService.login(_emailController.text, _passwordController.text);
    
    if (!mounted) return;
    setState(() => isLoading = false);

    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('token', token);

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      showMessage("Invalid Credentials");
    }
  }

  void showMessage(String msg) {
    SnackbarUtils.showWarning(context, msg);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "SMRIDGE",
                        style: GoogleFonts.orbitron(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 3.0,
                        ),
                      ).animate().slideY(begin: -0.5, duration: 800.ms).fade(),
                      
                      const SizedBox(height: 10),
                      Text(
                        "Welcome back",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ).animate().slideY(begin: -0.5, duration: 900.ms).fade(),

                      const SizedBox(height: 40),

                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Email",
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                          prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                        ),
                      ).animate().slideX(begin: -0.2).fade(delay: 100.ms),

                      const SizedBox(height: 20),

                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                        ),
                      ).animate().slideX(begin: 0.2).fade(delay: 200.ms),

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
                          onPressed: navigateToHome,
                          child: const Text("Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      ).animate().scale(delay: 300.ms).fade(),

                      const SizedBox(height: 25),

                      const SizedBox(height: 25),

                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen()));
                        },
                        child: RichText(
                          text: TextSpan(
                            text: "New user? ",
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            children: const [
                              TextSpan(text: "Register now", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold))
                            ]
                          )
                        ),
                      ).animate().fade(delay: 500.ms),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ).animate().fadeIn(duration: 1.seconds),

          // 🔹 Loader Overlay
          if (isLoading)
            const Positioned.fill(
              child: SmartLoader(message: "Authenticating..."),
            ),
        ],
      ),
    );
  }
}
