import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/wave_background.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/system_monitoring_indicators.dart';
import '../providers/sensor_provider.dart'; // 🚀 Added
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
  Timer? _loadingTimeout;
  
  List<FlSpot> _tempData = [];
  List<FlSpot> _humData = [];
  List<FlSpot> _freshData = [];
  List<FlSpot> _doorData = [];
  double _timeX = 1;

  DateTime? _lastUpdated;
  String _syncStatus = "Searching for ESP32...";

  @override
  void initState() {
    _fetchHistoricalData(); 
    
    // 🧬 DATA UNIFICATION: Listen to the central SensorProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) {
         context.read<SensorProvider>().addListener(_onSensorDataUpdate);
       }
    });

    _loadingTimeout = Timer(const Duration(seconds: 10), () {
      if (mounted && isLoading) {
        setState(() {
          isLoading = false;
          _syncStatus = "No sensor data — check ESP32 connection";
        });
      }
    });
  }

  Future<void> _fetchHistoricalData() async {
    final token = await SecureStorageService.getToken();
    if (token == null) return;
    
    final List<dynamic> trends = await ApiService.getTemperatureTrend(token);
    if (!mounted || trends.isEmpty) return;

    setState(() {
      _tempData.clear();
      _humData.clear();
      _freshData.clear();
      _doorData.clear();

      for (int i = 0; i < trends.length; i++) {
        final data = trends[i];
        double x = i.toDouble();
        _timeX = x + 1;

        double temp = double.tryParse(data['temperature']?.toString() ?? "8.0") ?? 8.0;
        double hum = double.tryParse(data['humidity']?.toString() ?? "60.0") ?? 60.0;
        double fresh = double.tryParse(data['calculatedFreshness']?.toString() ?? "85.0") ?? 85.0;
        double doorVal = data['doorStatus'] == 'open' ? 1.0 : 0.0;

        _tempData.add(FlSpot(x, temp));
        _humData.add(FlSpot(x, hum));
        _freshData.add(FlSpot(x, fresh));
        _doorData.add(FlSpot(x, doorVal));
      }
      
      _lastUpdated = DateTime.now();
      _syncStatus = "History Loaded";
      isLoading = false;
    });
  }

  void _onSensorDataUpdate() {
    if (!mounted) return;
    final sensor = context.read<SensorProvider>();
    
    setState(() {
      double x = _timeX;
      _timeX++;

      if (_tempData.length >= 30) {
        _tempData.removeAt(0);
        _humData.removeAt(0);
        _freshData.removeAt(0);
        _doorData.removeAt(0);
      }

      _tempData.add(FlSpot(x, sensor.temperature));
      _humData.add(FlSpot(x, sensor.humidity));
      _freshData.add(FlSpot(x, sensor.freshnessScore));
      _doorData.add(FlSpot(x, sensor.doorStatus == "OPEN" ? 1.0 : 0.0));

      _lastUpdated = sensor.lastUpdated;
      _syncStatus = sensor.isRealData ? "ESP32 Connected" : "ESP32 Connected(#)";
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    try {
      context.read<SensorProvider>().removeListener(_onSensorDataUpdate);
    } catch (e) {
      // Provider might be disposed
    }
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
                    _buildDoorStatusTimeline(isLight),
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

  // 🚪 NEW: Creative Animated Door Status Indicator
  Widget _buildDoorStatusTimeline(bool isLight) {
    Color subTextColor = isLight ? Colors.black54 : Colors.white70;
    bool isOpen = _doorData.isNotEmpty && _doorData.last.y == 1.0;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : (isOpen ? Colors.redAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isOpen ? Colors.redAccent.withOpacity(0.5) : (isLight ? Colors.transparent : Colors.tealAccent.withOpacity(0.3)), width: 1.5),
            boxShadow: isOpen 
              ? [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)]
              : [BoxShadow(color: Colors.tealAccent.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Text("SMART DOOR SENSOR", style: TextStyle(color: subTextColor, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Ring
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isOpen ? Colors.redAccent.withOpacity(0.3) : Colors.tealAccent.withOpacity(0.2), 
                        width: 4
                      ),
                    ),
                  ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1,1), end: const Offset(1.2,1.2), duration: 1.5.seconds).fadeOut(),
                  
                  // Inner Core
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOpen ? Colors.redAccent : Colors.tealAccent.withOpacity(0.2),
                      boxShadow: [
                        BoxShadow(
                          color: isOpen ? Colors.redAccent.withOpacity(0.5) : Colors.tealAccent.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isOpen ? Icons.door_front_door_outlined : Icons.lock_outline,
                        color: isOpen ? Colors.white : Colors.tealAccent,
                        size: 32,
                      ).animate(target: isOpen ? 1 : 0).shake(hz: 4, curve: Curves.easeInOut),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: isOpen ? Colors.redAccent : Colors.tealAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
                child: Text(isOpen ? "STATUS: OPEN" : "STATUS: SECURE"),
              ),
              if (isOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: const Text("Warning: Cooling loss detected", style: TextStyle(color: Colors.redAccent, fontSize: 12))
                    .animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(),
                ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}
