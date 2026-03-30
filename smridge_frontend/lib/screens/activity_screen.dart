import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../services/socket_service.dart'; // 🔹 Added SocketService
import '../providers/theme_provider.dart';
import '../widgets/wave_background.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ActivityScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ActivityScreen({super.key, required this.onBack});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<dynamic> activities = [];
  List<dynamic> stats = [];
  bool isLoading = true;
  bool isTodayView = false; // Default to All Time so existing data shows immediately
  bool isChartView = true; // 🔹 Toggle between Pie and List
  int touchedIndex = -1; // 🔹 Track selected slice

  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupSocket();
  }

  @override
  void dispose() {
    SocketService.off('activity_update');
    super.dispose();
  }

  void _setupSocket() {
    SocketService.on('activity_update', (data) {
      if (mounted) {
        final timestamp = DateTime.parse(data['timestamp']);
        final now = DateTime.now();
        bool isFromToday = timestamp.day == now.day && timestamp.month == now.month && timestamp.year == now.year;

        if (!isTodayView || isFromToday) {
          setState(() {
            activities.insert(0, data);
            if (activities.length > 100) activities.removeLast();
            _fetchStats(); 
          });
        }
      }
    });
  }

  Future<void> _fetchData() async {
    final token = await SecureStorageService.getToken();
    if (token == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    final period = isTodayView ? 'today' : 'all';
    
    try {
      final results = await Future.wait([
        ApiService.getActivities(token, period: period),
        ApiService.getActivityStats(token, period: period),
      ]);

      if (mounted) {
        setState(() {
          activities = results[0];
          stats = results[1];
        });
      }
    } catch (e) {
      print("Error fetching activity data: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  Future<void> _fetchStats() async {
    final token = await SecureStorageService.getToken();
    if (token == null) return;
    final period = isTodayView ? 'today' : 'all';
    final result = await ApiService.getActivityStats(token, period: period);
    if (mounted) setState(() => stats = result);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLight = themeProvider.currentTheme == ThemeType.light;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isTodayView ? "Today's Activity" : "My Activity History", 
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(isChartView ? "Distribution View" : "Timeline View",
              style: TextStyle(color: Colors.cyanAccent.withOpacity(0.8), fontSize: 12)),
          ],
        ),
        actions: [
          // 🔹 TOGGLE BETWEEN LOGS AND CHART
          IconButton(
            icon: Icon(isChartView ? Icons.list_alt_rounded : Icons.pie_chart_rounded, color: Colors.cyanAccent),
            tooltip: isChartView ? "Show Log List" : "Show Distribution Chart",
            onPressed: () => setState(() => isChartView = !isChartView),
          ),
          // 🔹 TOGGLE BETWEEN TODAY AND ALL TIME
          IconButton(
            icon: Icon(isTodayView ? Icons.calendar_month_rounded : Icons.history_rounded, color: Colors.cyanAccent),
            tooltip: isTodayView ? "Switch to All Time" : "Switch to Today",
            onPressed: () {
              setState(() {
                isTodayView = !isTodayView;
                isLoading = true;
              });
              _fetchData();
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isLight ? const Color(0xFFF3F6F8) : Colors.black,
              gradient: isLight ? null : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F2027), Color(0xFF203A43)],
              ),
            ),
          ),
          const Positioned.fill(child: WaveBackground()),

          SafeArea(
            child: isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
            : RefreshIndicator(
                onRefresh: _fetchData,
                child: AnimatedSwitcher(
                  duration: 500.ms,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: isChartView ? _buildStatsCard(isLight, textColor) : _buildActivityList(isLight, textColor),
                ),
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(bool isLight, Color textColor) {
    if (stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline_rounded, size: 80, color: textColor.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text("No distribution data available", style: TextStyle(color: textColor.withOpacity(0.4))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => isLoading = true);
                _fetchData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Retry Connection"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                foregroundColor: Colors.cyanAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: isLight ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, spreadRadius: -5)
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          // 👆 Change to "Sticky Tap" instead of "Hold"
                          if (event is FlTapUpEvent || event is FlPanDownEvent) {
                            if (pieTouchResponse != null && pieTouchResponse.touchedSection != null) {
                              setState(() {
                                final newIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                // 🔹 Toggle selection: if same slice tapped, deselect it
                                touchedIndex = (touchedIndex == newIndex) ? -1 : newIndex;
                              });
                            }
                          }
                          // Do not reset touchedIndex = -1 on other events
                        },
                      ),
                      sectionsSpace: 4,
                      centerSpaceRadius: 50,
                      sections: () {
                        final total = stats.fold<int>(0, (sum, s) => sum + (s['value'] as int));
                        return stats.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final s = entry.value;
                          final isTouched = idx == touchedIndex;
                          final color = HexColor(s['color']);
                          final pct = total > 0 ? ((s['value'] as int) / total * 100).toStringAsFixed(0) : '0';
                          
                          return PieChartSectionData(
                            color: color,
                            value: (s['value'] as int).toDouble(),
                            title: isTouched ? '${s['value']}' : '$pct%',
                            radius: isTouched ? 85 : 70,
                            titleStyle: TextStyle(
                              fontSize: isTouched ? 18 : 14, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white,
                              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                            gradient: LinearGradient(
                              colors: [color, color.withOpacity(0.8), color.withOpacity(0.5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            badgeWidget: _buildActionIcon(s['name'].toUpperCase(), size: isTouched ? 24 : 18),
                            badgePositionPercentageOffset: 1.15,
                          );
                        }).toList();
                      }(),
                    ),
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 30),
                _buildSelectionDetails(isLight, textColor),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 20,
                  runSpacing: 15,
                  alignment: WrapAlignment.center,
                  children: stats.map((s) => _buildLegend(s['name'], HexColor(s['color']), textColor)).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _buildSmartInsights(textColor),
          const SizedBox(height: 20),
          _buildSummaryInfo(textColor),
          const SizedBox(height: 220), // 🔹 Extra space for the Bottom Dock
        ],
      ),
    );
  }

  Widget _buildSelectionDetails(bool isLight, Color textColor) {
    if (touchedIndex == -1 || stats.isEmpty || touchedIndex >= stats.length) {
      return Text("Tap a slice to view detailed statistics", 
        style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 13, fontStyle: FontStyle.italic));
    }

    final selected = stats[touchedIndex];
    final color = HexColor(selected['color']);
    final name = selected['name'].toString().replaceAll('_', ' ');
    final count = selected['value'];
    
    // 🔹 Filter activities of this type based on the same logic as backend categorization
    final filtered = activities.where((a) {
      final action = a['action'].toString().toUpperCase();
      if (name == "Inventory") return action.contains("ITEM");
      if (name == "System") return action.contains("DOOR") || action.contains("ALERT");
      if (name == "Account") return action.contains("LOGIN") || action.contains("PROFILE");
      if (name == "App") return !action.contains("ITEM") && !action.contains("DOOR") && !action.contains("ALERT") && !action.contains("LOGIN") && !action.contains("PROFILE");
      return false;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   _buildActionIcon(selected['name'], size: 24),
                   const SizedBox(width: 12),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(name, style: GoogleFonts.orbitron(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
                       Text("Category Statistics", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 10)),
                     ],
                   ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text("$count Total", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
            const SizedBox(height: 20),
            Text("DETAILED ACTIONS", style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 10),
            // 🔹 Make this internal list scrollable if it grows too long
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final a = filtered[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(Icons.circle, size: 6, color: color.withOpacity(0.5)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(a['action']?.toString().replaceAll('_', ' ') ?? "ACTION", 
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                  Text(
                                    DateFormat('HH:mm').format(DateTime.parse(a['timestamp'])),
                                    style: TextStyle(color: color.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(a['details'] ?? "No details", 
                                style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11, height: 1.3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildSmartInsights(Color textColor) {
    if (stats.isEmpty) return const SizedBox.shrink();
    
    // 🔹 Sort by value to find the leader
    final sortedStats = List.from(stats)..sort((a, b) => (b['value'] as int).compareTo(a['value'] as int));
    final leader = sortedStats[0];
    final percentage = ((leader['value'] / activities.length) * 100).toStringAsFixed(0);
    
    String insightText = "";
    if (leader['name'].contains("ITEM")) {
      insightText = "You've been focused on inventory management. Most of your actions ($percentage%) involve adding or removing items.";
    } else if (leader['name'].contains("DOOR")) {
      insightText = "The fridge door has been your most frequent interaction ($percentage% of activity). Make sure it's always sealed properly!";
    } else if (leader['name'].contains("WEIGHT")) {
      insightText = "Load cell activity is dominant ($percentage%). You're frequently adding or removing weighted items.";
    } else {
      insightText = "Your app usage is well distributed. '${leader['name']}' is currently your primary activity at $percentage%.";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 10),
              Text("SMART INSIGHTS", style: GoogleFonts.orbitron(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insightText,
            style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSummaryInfo(Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Total Actions", activities.length.toString(), Icons.bolt, Colors.amber),
          _buildStatItem("Most Frequent", stats.isNotEmpty ? stats[0]['name'] : "N/A", Icons.star, Colors.cyanAccent),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
      ],
    );
  }

  Widget _buildLegend(String label, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: textColor.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActivityList(bool isLight, Color textColor) {
    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 80, color: textColor.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text("No activity logs captured yet", style: TextStyle(color: textColor.withOpacity(0.4))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 220), // 🔹 Added bottom padding for dock
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final act = activities[index];
        final timestamp = DateTime.parse(act['timestamp']);
        final dayStr = "${timestamp.day}/${timestamp.month}/${timestamp.year}";
        final timeStr = "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isLight ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              if (isLight) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: _buildActionIcon(act['action'], customColor: act['color']),
                title: Text(act['action'].replaceAll('_', ' '), 
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(act['details'] ?? "", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13)),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(timeStr, style: TextStyle(color: Colors.cyanAccent.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(dayStr, style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(delay: (index * 40).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
      },
    );
  }

  Widget _buildActionIcon(String action, {double size = 20, String? customColor}) {
    IconData icon;
    Color color;

    if (customColor != null && customColor.isNotEmpty) {
      try {
        color = HexColor(customColor);
      } catch (e) {
        color = Colors.cyanAccent;
      }
    } else {
      if (action.contains("ITEM")) {
        color = const Color(0xFF00F2FF);
      } else if (action.contains("DOOR")) {
        color = const Color(0xFF7000FF);
      } else if (action.contains("LOGIN")) {
        color = const Color(0xFFFF007A);
      } else if (action.contains("WEIGHT") || action.contains("INTEL")) {
        color = const Color(0xFF00FFAB);
      } else {
        color = Colors.cyanAccent;
      }
    }

    if (action.contains("ITEM")) {
      icon = Icons.inventory_2_rounded;
    } else if (action.contains("DOOR")) {
      icon = Icons.door_front_door_rounded;
    } else if (action.contains("LOGIN")) {
      icon = Icons.login_rounded;
    } else if (action.contains("WEIGHT") || action.contains("INTEL")) {
      icon = Icons.monitor_weight_rounded;
    } else if (action.contains("APP_OPEN")) {
      icon = Icons.phonelink_setup;
    } else {
      icon = Icons.touch_app_rounded;
    }

    return Container(
      padding: EdgeInsets.all(size / 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, spreadRadius: -2)
        ],
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) hexColor = "FF$hexColor";
    return int.parse(hexColor, radix: 16);
  }
  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}
