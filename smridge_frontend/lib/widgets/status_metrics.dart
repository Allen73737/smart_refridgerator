import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_settings.dart';
import 'package:fl_chart/fl_chart.dart'; // 🚀 Added
import '../services/socket_service.dart';
import '../screens/analytics_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/sensor_provider.dart'; // 🚀 Added
import '../screens/inventory_list_screen.dart'; // Extra sync for UI
import '../models/inventory_item.dart'; // Extra sync

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

  bool _isHovering = false;

  @override
  void initState() {
    super.initState();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

  }


  @override
  void dispose() {
    pulseController.dispose();
    super.dispose();
  }

  bool isTempDanger(double t) => t > AppSettings.temperatureThreshold;
  bool isHumidityDanger(double h) => h > AppSettings.humidityThreshold;
  bool isFreshDanger(double f) => f < AppSettings.freshnessThreshold;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    
    final sensor = context.watch<SensorProvider>();
    final temperature = sensor.temperature;
    final humidity = sensor.humidity;
    final freshness = sensor.freshnessScore;
    final isDoorOpen = sensor.doorStatus == "OPEN";

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
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: AnimatedBuilder(
                animation: pulseController,
                builder: (_, __) {
                  bool danger = isTempDanger(temperature) || isHumidityDanger(humidity) || isFreshDanger(freshness);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            isTempDanger(temperature) 
                              ? Colors.redAccent 
                              : (isLight ? const Color(0xFF007A7A) : Colors.tealAccent),
                            icon: Icons.thermostat_rounded,
                            isLight: isLight),
                        buildMetric(
                            "Air Humidity",
                            "${humidity.toStringAsFixed(0)}%",
                            isHumidityDanger(humidity) 
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
                        
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
              ),
            ),
          ),
        ),
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
        Text(
          "${freshness.toStringAsFixed(0)}% ", 
          style: GoogleFonts.outfit(
            color: activeColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
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
