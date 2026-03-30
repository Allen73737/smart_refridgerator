import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_settings.dart';
import '../services/socket_service.dart';
import '../screens/analytics_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class StatusMetrics extends StatefulWidget {
  const StatusMetrics({super.key});

  @override
  State<StatusMetrics> createState() =>
      _StatusMetricsState();
}

class _StatusMetricsState
    extends State<StatusMetrics>
    with TickerProviderStateMixin {

  late AnimationController pulseController;

  double temperature = 8;
  double humidity = 60;
  double freshness = 85;
  bool isDoorOpen = false;
  bool _isHovering = false;
  bool isRealData = false;

  @override
  void initState() {
    super.initState();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _initSocketListeners();
  }

  void _initSocketListeners() {
    SocketService.on('sensor_data', (data) {
      if (!mounted) return;
      setState(() {
        temperature = double.tryParse(data['temperature']?.toString() ?? '8.0') ?? 8.0;
        humidity    = double.tryParse(data['humidity']?.toString() ?? '60.0') ?? 60.0;
        freshness   = double.tryParse(data['calculatedFreshness']?.toString() ?? '85.0') ?? 85.0;
        isDoorOpen  = data['doorStatus'] == 'open';
        isRealData  = data['isReal'] ?? false;
      });
    });
  }

  @override
  void dispose() {
    pulseController.dispose();
    super.dispose();
  }

  bool isTempDanger() =>
      temperature >
      AppSettings.temperatureThreshold;

  bool isHumidityDanger() =>
      humidity >
      AppSettings.humidityThreshold;

  bool isFreshDanger() =>
      freshness <
      AppSettings.freshnessThreshold;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    
    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, __) {
        bool danger = isTempDanger() || isHumidityDanger() || isFreshDanger();

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
            child: AnimatedScale(
              scale: _isHovering ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), // Even tighter
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: isLight 
                        ? Colors.white.withOpacity(0.85) 
                        : Colors.black.withOpacity(0.6),
                      border: Border.all(
                        color: danger 
                          ? Colors.redAccent.withOpacity(0.5 + 0.3 * pulseController.value)
                          : (_isHovering ? Colors.tealAccent.withOpacity(0.4) : Colors.white10), 
                        width: 1.5
                      ),
                      boxShadow: [
                        if (danger)
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.3 * pulseController.value),
                            blurRadius: 25,
                            spreadRadius: 2,
                          )
                        else if (_isHovering)
                          BoxShadow(
                            color: Colors.tealAccent.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.tealAccent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.hub_outlined, 
                                color: isLight ? const Color(0xFF007A7A) : Colors.tealAccent, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "SYSTEM MONITOR",
                                    style: GoogleFonts.orbitron(
                                      color: isLight ? const Color(0xFF007A7A) : Colors.tealAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(color: isLight ? Colors.black12 : Colors.white10, height: 1),
                        const SizedBox(height: 6),
                        buildMetric(
                            "Internal Temp",
                            "${temperature.toStringAsFixed(1)}°C",
                            isTempDanger() 
                              ? Colors.redAccent 
                              : (isLight ? const Color(0xFF007A7A) : Colors.tealAccent),
                            icon: Icons.thermostat_rounded,
                            isLight: isLight),
                        buildMetric(
                            "Air Humidity",
                            "${humidity.toStringAsFixed(0)}%",
                            isHumidityDanger() 
                              ? Colors.redAccent 
                              : (isLight ? const Color(0xFF007A7A) : Colors.tealAccent),
                            icon: Icons.water_drop_rounded,
                            isLight: isLight),
                        buildMetric(
                            "Freshness",
                            "",
                            isLight ? const Color(0xFF007A7A) : Colors.tealAccent,
                            icon: Icons.auto_awesome_outlined,
                            customValueWidget: _buildFreshnessIndicators(freshness),
                            isLight: isLight),
                        buildMetric(
                            "Smart Door",
                            isDoorOpen ? "OPEN" : "CLOSED",
                            isDoorOpen ? Colors.orangeAccent : (isLight ? const Color(0xFF007A7A) : Colors.tealAccent),
                            icon: Icons.door_front_door_outlined,
                            isLight: isLight),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color getFreshnessColor(double value) {
    if (value >= 70) return Colors.greenAccent;
    if (value >= 40) return Colors.yellow;
    return Colors.red;
  }

  Widget _buildFreshnessIndicators(double freshness) {
    Color activeColor = getFreshnessColor(freshness);
    
    Widget buildDot(Color color) {
      bool isActive = color == activeColor;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: isActive ? 14 : 10,
        height: isActive ? 14 : 10,
        decoration: BoxDecoration(
          color: color.withOpacity(isActive ? 1.0 : 0.3),
          shape: BoxShape.circle,
          boxShadow: isActive 
             ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)] 
             : [],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildDot(Colors.greenAccent),
        buildDot(Colors.yellow),
        buildDot(Colors.red),
      ],
    );
  }

  Widget buildMetric(String label, String value, Color color, {required IconData icon, Widget? customValueWidget, bool isLight = false}) {
    Color textColor = isLight ? Colors.black87 : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            label, 
            style: GoogleFonts.outfit(
              color: textColor.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            )
          ),
          const Spacer(),
          if (customValueWidget != null)
            customValueWidget
          else
            Text(
              value,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
