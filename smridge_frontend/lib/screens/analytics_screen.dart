import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/wave_background.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../widgets/system_monitoring_indicators.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const AnalyticsScreen({super.key, this.onBack});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool isLoading = true;
  
  List<FlSpot> _tempData = [];
  List<FlSpot> _humData = [];
  List<FlSpot> _freshData = [];
  double _timeX = 1;
  DateTime? _lastUpdated;
  String _syncStatus = "Syncing";

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    SocketService.on('sensor_data', _onHardwareUpdate);
  }

  void _onHardwareUpdate(dynamic data) {
    if (!mounted) return;

    setState(() {
      double x = _timeX;
      _timeX++;

      if (_tempData.length >= 30) {
        _tempData.removeAt(0);
        _humData.removeAt(0);
        _freshData.removeAt(0);
      }

      double temp = (data['temperature'] as num).toDouble();
      double hum = (data['humidity'] as num).toDouble();
      double fresh = (data['calculatedFreshness'] as num).toDouble();

      _tempData.add(FlSpot(x, temp));
      _humData.add(FlSpot(x, hum));
      _freshData.add(FlSpot(x, fresh));

      _lastUpdated = DateTime.now();
      
      bool isReal = data['isReal'] ?? false;
      _syncStatus = isReal ? "ESP32 Connected" : "ESP32 Connected (#)";
      isLoading = false;
    });
  }

  @override
  void dispose() {
    SocketService.off('sensor_data', _onHardwareUpdate);
    super.dispose();
  }

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
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text("Device Analytics", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))
            .animate().fadeIn(),
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

          if (isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.tealAccent).animate().scale(),
                  const SizedBox(height: 20),
                  const Text("Connecting to Sensors...", style: TextStyle(color: Colors.tealAccent, fontSize: 16))
                      .animate(onPlay: (c) => c.repeat(reverse: true)).fade(),
                ],
              ),
            )
          else
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    _buildGraphCard("Internal Temperature (°C)", "${_tempData.last.y.toStringAsFixed(1)}°C", Colors.blueAccent, _tempData, isLight),
                    const SizedBox(height: 20),
                    _buildGraphCard("Relative Humidity (%)", "${_humData.last.y.toInt()}%", Colors.cyanAccent, _humData, isLight),
                    const SizedBox(height: 20),
                    _buildGraphCard("Freshness Index", "${_freshData.last.y.toInt()}%", Colors.greenAccent, _freshData, isLight),
                    const SizedBox(height: 20),
                    _buildSystemMonitoringCard(isLight),
                    const SizedBox(height: 100), // Padding for bottom dock
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSystemMonitoringCard(bool isLight) {
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color subTextColor = isLight ? Colors.black54 : Colors.white70;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isLight ? Colors.white : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isLight ? 0.05 : 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "System Monitoring",
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
              ).animate().fadeIn().slideX(),
              const SizedBox(height: 20),
              DeviceStatusIndicator(lastUpdated: _lastUpdated),
              const SizedBox(height: 12),
              LastUpdatedIndicator(lastUpdated: _lastUpdated),
              const SizedBox(height: 12),
              BackendSyncIndicator(status: _syncStatus),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraphCard(String title, String currentValue, Color color, List<FlSpot> points, bool isLight) {
    Color subTextColor = isLight ? Colors.black54 : Colors.white70;
    Color graphTitleColor = isLight ? ((color == Colors.cyanAccent || color == Colors.greenAccent) ? Colors.teal : color) : color;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isLight ? 0.05 : 0.3), blurRadius: 20, offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    title,
                    style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.normal),
                  ).animate().fadeIn().slideX(),
                  Text(
                    currentValue,
                    style: TextStyle(color: graphTitleColor, fontSize: 24, fontWeight: FontWeight.bold),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.5),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => Colors.black87,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((LineBarSpot touchedSpot) {
                            return LineTooltipItem(
                              touchedSpot.y.toString(),
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(color: isLight ? Colors.black12 : Colors.white10, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: TextStyle(color: isLight ? Colors.black54 : Colors.white54, fontSize: 12)))),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    minX: points.first.x,
                    maxX: points.last.x,
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: points,
                        isCurved: true,
                        color: graphTitleColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: graphTitleColor.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 800.ms).scaleY(alignment: Alignment.bottomCenter),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
