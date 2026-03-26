import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/inventory_item.dart';
import '../widgets/wave_background.dart';
import 'barcode_scanner_screen.dart';
import 'add_inventory_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_walkthrough.dart'; // 🎯
import '../services/secure_storage_service.dart';

class AddInventoryChoiceScreen extends StatefulWidget {
  final VoidCallback onPackaged;
  final VoidCallback onNonPackaged;
  final VoidCallback? onBack;

  const AddInventoryChoiceScreen({
    super.key, 
    required this.onPackaged, 
    required this.onNonPackaged, 
    this.onBack
  });

  @override
  State<AddInventoryChoiceScreen> createState() => _AddInventoryChoiceScreenState();
}

class _AddInventoryChoiceScreenState extends State<AddInventoryChoiceScreen> {
  final GlobalKey _wtPackagedKey = GlobalKey();
  final GlobalKey _wtManualKey = GlobalKey();
  
  bool _showWalkthrough = false;
  List<WalkthroughStep> _currentSteps = [];

  @override
  void initState() {
    super.initState();
    _checkFirstVisit();
  }

  Future<void> _checkFirstVisit() async {
    final visited = await SecureStorageService.getString('visited_add_choice');
    if (visited == null) {
      _triggerWalkthrough();
    }
  }

  void _triggerWalkthrough() {
    setState(() {
      _currentSteps = [
        WalkthroughStep(
          targetKey: _wtPackagedKey,
          title: "AI Barcode Scanner",
          description: "Use your device camera to scan retail barcodes. Smridge will automatically fetch product nutrition, weight, and suggested expiry dates.",
        ),
        WalkthroughStep(
          targetKey: _wtManualKey,
          title: "Manual Logging",
          description: "For fresh farm produce or unpackaged items, enter details manually. You can also snap a photo for AI-assisted image recognition.",
        ),
      ];
      _showWalkthrough = true;
    });
    SecureStorageService.saveString('visited_add_choice', 'true');
  }

  Widget _buildChoiceCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required bool isLight,
    Key? key,
  }) {
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color subTextColor = isLight ? Colors.black54 : Colors.white70;

    final border = Border.all(color: isLight ? Colors.transparent : color.withOpacity(0.3), width: 1.5);

    return GestureDetector(
      key: key, // 🎯
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: border,
          boxShadow: [
            BoxShadow(
              color: isLight ? Colors.black.withOpacity(0.1) : color.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 60, color: isLight ? ((color == Colors.tealAccent) ? Colors.teal : Colors.blue) : color),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    final isDark = themeType == ThemeType.dark;
    
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
        title: Text(
          "Select Item Type",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ).animate().fadeIn(),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isLight ? const Color(0xFFF3F6F8) : (isDark ? Colors.black : null),
              gradient: (isLight || isDark) ? null : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F2027), Color(0xFF203A43)],
              ),
            ),
          ),
          const Positioned.fill(child: WaveBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildChoiceCard(
                    context: context,
                    key: _wtPackagedKey, // 🎯
                    title: "Packaged Food",
                    subtitle: "Scan a barcode to instantly autofill product details.",
                    icon: Icons.qr_code_scanner,
                    color: Colors.tealAccent,
                    isLight: isLight,
                    onTap: widget.onPackaged,
                  ).animate().slideX(begin: -0.2).fade(),
                  const SizedBox(height: 40),
                  _buildChoiceCard(
                    context: context,
                    key: _wtManualKey, // 🎯
                    title: "Non-Packaged Food",
                    subtitle: "Enter details manually and optionally capture a photo.",
                    icon: Icons.fastfood_outlined,
                    color: Colors.blueAccent,
                    isLight: isLight,
                    onTap: widget.onNonPackaged,
                  ).animate().slideX(begin: 0.2).fade(delay: const Duration(milliseconds: 100)),
                ],
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
}
