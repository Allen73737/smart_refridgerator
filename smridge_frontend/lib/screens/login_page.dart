import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/secure_storage_service.dart';
import 'signup_page.dart';
import 'home_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _biometricAvailable = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final available = await _authService.isBiometricAvailable();
      final enabled = await SecureStorageService.isBiometricEnabled();
      final token = await SecureStorageService.getToken();
      
      setState(() {
        _biometricAvailable = available && enabled && token != null;
      });

      if (_biometricAvailable) {
        _loginWithBiometrics();
      }
    } catch (e) {
      print("Biometric check failed: $e");
    }
  }

  Future<void> _loginWithBiometrics() async {
    try { // Added try-catch for biometric authentication
      final success = await _authService.authenticate();
      if (success) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      print("--- [FRONTEND DEBUG] Biometric Login Error: $e ---");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Biometric login failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _loginWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final token = await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      print("--- [FRONTEND DEBUG] Login Response Token: ${token != null ? 'RECEIVED' : 'NULL'} ---");

      if (token != null) {
        print("--- [FRONTEND DEBUG] Saving Token... ---");
        // Save to BOTH to ensure compatibility with HomeScreen
        await SecureStorageService.saveToken(token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setBool('isLoggedIn', true);
        
        print("--- [FRONTEND DEBUG] Token Saved. Prompting Biometrics... ---");
        _promptBiometrics();
      }
    } catch (e) {
      print("--- [FRONTEND DEBUG] Login Error: $e ---");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final idToken = await GoogleAuthService.signIn();
      if (idToken != null) {
        final data = await ApiService.googleLogin(idToken);
        if (data != null && data['token'] != null) {
          await SecureStorageService.saveToken(data['token']);
          _promptBiometrics();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google login failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _promptBiometrics() async {
    final enabled = await SecureStorageService.isBiometricEnabled();
    final available = await _authService.isBiometricAvailable();

    if (!enabled && available) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E2A33),
            title: const Text("Enable Biometrics?", style: TextStyle(color: Colors.white)),
            content: const Text("Would you like to use fingerprint or face unlock for faster login?", style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToHome();
                },
                child: const Text("Maybe Later"),
              ),
              TextButton(
                onPressed: () async {
                  await SecureStorageService.setBiometricEnabled(true);
                  Navigator.pop(ctx);
                  _navigateToHome();
                },
                child: const Text("Enable", style: TextStyle(color: Colors.tealAccent)),
              ),
            ],
          ),
        );
      }
    } else {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Hero(
                    tag: 'logo',
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.tealAccent.withOpacity(0.1),
                        boxShadow: [
                          BoxShadow(color: Colors.tealAccent.withOpacity(0.2), blurRadius: 40, spreadRadius: 5)
                        ],
                      ),
                      child: const Icon(Icons.ac_unit, color: Colors.tealAccent, size: 80),
                    ).animate().scale(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  Animate(
                    effects: [const FadeEffect(delay: Duration(milliseconds: 300))],
                    child: Text(
                      "SMRIDGE",
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                    ),
                  ),
                  
                  Animate(
                    effects: [const FadeEffect(delay: Duration(milliseconds: 500))],
                    child: Text(
                      "SMART REFRIGERATION",
                      style: GoogleFonts.orbitron(
                        color: Colors.tealAccent,
                        fontSize: 12,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Login Form
                  _buildGlassField(_emailController, "Email", Icons.email),
                  const SizedBox(height: 20),
                  _buildGlassField(_passwordController, "Password", Icons.lock, isPassword: true),
                  
                  const SizedBox(height: 30),
                  
                  _buildLoginButton(),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.white10)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Text("OR", style: TextStyle(color: Colors.white.withOpacity(0.3))),
                      ),
                      const Expanded(child: Divider(color: Colors.white10)),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildGoogleButton(),
                  
                  if (_biometricAvailable) const SizedBox(height: 20),
                  if (_biometricAvailable) _buildBiometricButton(),
                  
                  const SizedBox(height: 40),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: TextStyle(color: Colors.white.withOpacity(0.6))),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage())),
                        child: const Text("Sign Up", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          prefixIcon: Icon(icon, color: Colors.tealAccent.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _loginWithEmail,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.teal, Colors.tealAccent]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.tealAccent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 5))
          ],
        ),
        child: const Center(
          child: Text(
            "LOGIN",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _loginWithGoogle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.g_mobiledata, color: Colors.white, size: 30),
            const SizedBox(width: 10),
            Text("Continue with Google", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return Animate(
      onPlay: (c) => c.repeat(),
      effects: [ShimmerEffect(duration: const Duration(milliseconds: 2000), color: Colors.white24)],
      child: IconButton(
        icon: const Icon(Icons.fingerprint, color: Colors.tealAccent, size: 50),
        onPressed: _loginWithBiometrics,
      ),
    );
  }
}
