import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../config/app_settings.dart';
import '../widgets/wave_background.dart';
import '../widgets/animated_bottom_dock.dart';
import '../screens/home_screen.dart';
import '../providers/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

class DeviceConfigScreen extends StatefulWidget {
  const DeviceConfigScreen({super.key});

  @override
  State<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends State<DeviceConfigScreen> {
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Device Configuration", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))
            .animate().fadeIn(),
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
              padding: const EdgeInsets.only(top: 20, bottom: 40, left: 24, right: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30)
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, color: Colors.tealAccent, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              "Metrics Thresholds",
                              style: GoogleFonts.orbitron(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ).animate().fadeIn().slideX(begin: -0.1),
                        const SizedBox(height: 10),
                        Text(
                          "Configure the thresholds at which your Smridge device triggers alerts. Note that you cannot exceed ranges hardcoded by the administrator.",
                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13, height: 1.5),
                        ).animate().fadeIn(delay: 100.ms),
                        
                        const SizedBox(height: 20),
                        
                        // 🤖 GLOBAL SIMULATION TOGGLE
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.psychology_outlined, color: Colors.tealAccent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Simulation Mode",
                                      style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Text(
                                      "Enable AI-driven sensor fluctuations when offline.",
                                      style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: AppSettings.isSimulationEnabled,
                                activeColor: Colors.tealAccent,
                                onChanged: (val) async {
                                  setState(() => AppSettings.isSimulationEnabled = val);
                                  final token = await SecureStorageService.getToken();
                                  if (token != null) {
                                    await ApiService.updateAdminThresholds({'isSimulationEnabled': val}, token);
                                  }
                                },
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 150.ms),

                        const SizedBox(height: 20),
                        
                        _buildGlassSlider(
                          "Temperature Threshold",
                          AppSettings.temperatureThreshold,
                          AppSettings.adminMinTemperature,
                          AppSettings.adminMaxTemperature,
                          (val) => setState(() => AppSettings.temperatureThreshold = AppSettings.clampTemperature(val)),
                          Icons.thermostat,
                          isLight,
                          textColor,
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                        
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4, bottom: 20),
                          child: Text(
                            "Restricted range: ${AppSettings.adminMinTemperature.toStringAsFixed(1)}° — ${AppSettings.adminMaxTemperature.toStringAsFixed(1)}°",
                            style: TextStyle(color: isLight ? Colors.grey : Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                        
                        _buildGlassSlider(
                          "Humidity Threshold",
                          AppSettings.humidityThreshold,
                          AppSettings.adminMinHumidity,
                          AppSettings.adminMaxHumidity,
                          (val) => setState(() => AppSettings.humidityThreshold = AppSettings.clampHumidity(val)),
                          Icons.water_drop,
                          isLight,
                          textColor,
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                        
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4, bottom: 20),
                          child: Text(
                            "Restricted range: ${AppSettings.adminMinHumidity.toStringAsFixed(1)}% — ${AppSettings.adminMaxHumidity.toStringAsFixed(1)}%",
                            style: TextStyle(color: isLight ? Colors.grey : Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                        
                        _buildGlassSlider(
                          "Freshness Threshold",
                          AppSettings.freshnessThreshold,
                          AppSettings.adminMinFreshness,
                          AppSettings.adminMaxFreshness,
                          (val) => setState(() => AppSettings.freshnessThreshold = AppSettings.clampFreshness(val)),
                          Icons.eco,
                          isLight,
                          textColor,
                        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                        
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: Text(
                            "Restricted range: ${AppSettings.adminMinFreshness.toStringAsFixed(1)} — ${AppSettings.adminMaxFreshness.toStringAsFixed(1)}",
                            style: TextStyle(color: isLight ? Colors.grey : Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: AnimatedBottomDock(
              currentIndex: 4, // Device config maps to settings tab
              onTap: (index) {
                if (index != 4) {
                   Navigator.pushAndRemoveUntil(
                     context,
                     MaterialPageRoute(builder: (context) => HomeScreen(initialTab: index)),
                     (route) => false,
                   );
                } else {
                   Navigator.pop(context); // just popping if 4 is tapped since we came from there
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSlider(String label, double value, double min, double max, Function(double) onChanged, IconData icon, bool isLight, Color textColor) {
    Color iconColor = isLight ? Colors.teal : Colors.tealAccent;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: isLight ? Colors.grey.shade200 : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.tealAccent,
              inactiveTrackColor: Colors.white.withOpacity(0.2),
              thumbColor: Colors.white,
              overlayColor: Colors.tealAccent.withOpacity(0.2),
              trackHeight: 4.0,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
