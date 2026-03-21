import 'dart:math';
import 'package:flutter/material.dart';
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
        temperature = (data['temperature'] as num).toDouble();
        humidity = (data['humidity'] as num).toDouble();
        freshness = (data['calculatedFreshness'] as num).toDouble();
        isDoorOpen = data['doorStatus'] == 'open';
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
    
    Color textColor = isLight ? Colors.black87 : Colors.white;

    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, __) {

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
            child: AnimatedScale(
              scale: _isHovering ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(20),
                  color: isLight ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.7),
                  border: Border.all(color: _isHovering ? (isLight ? Colors.teal : Colors.tealAccent).withOpacity(0.5) : Colors.transparent, width: 1.5),
                  boxShadow: [
                    if (isTempDanger() ||
                        isHumidityDanger() ||
                        isFreshDanger())
                      BoxShadow(
                        color: Colors.red
                            .withOpacity(
                                (0.5 *
                                    pulseController
                                        .value).clamp(0.0, 1.0)),
                        blurRadius: 30,
                      )
                    else if (_isHovering)
                      BoxShadow(
                        color: isLight ? Colors.black.withOpacity(0.1) : Colors.tealAccent.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Column(
                  children: [

              buildMetric(
                  "Temperature",
                  "${temperature.toStringAsFixed(1)}°C",
                  isTempDanger() ? Colors.red : (isLight ? Colors.teal : Colors.greenAccent),
                  isLight: isLight),

              buildMetric(
                  "Humidity",
                  "${humidity.toStringAsFixed(0)}%",
                  isHumidityDanger() ? Colors.red : (isLight ? Colors.teal : Colors.greenAccent),
                  isLight: isLight),

              buildMetric(
                  "Freshness",
                  "",
                  Colors.transparent,
                  customValueWidget: _buildFreshnessIndicators(freshness),
                  isLight: isLight
              ),
                  
              buildMetric(
                  "Door",
                  isDoorOpen ? "Open" : "Closed",
                  isDoorOpen ? Colors.orange : (isLight ? Colors.teal : Colors.greenAccent),
                  isDoorMetric: true,
                  isLight: isLight
              ),
            ],
          ),
        ),
      ),
    ));
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

  Widget buildMetric(String label, String value, Color color, {bool isDoorMetric = false, Widget? customValueWidget, bool isLight = false}) {
    Color textColor = isLight ? Colors.black87 : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textColor)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customValueWidget != null)
                customValueWidget
              else
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  child: Text(value),
                ),
              if (isDoorMetric) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isLight ? Colors.grey.shade200 : Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.keyboard_arrow_down, color: isLight ? Colors.teal : Colors.tealAccent, size: 16),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
