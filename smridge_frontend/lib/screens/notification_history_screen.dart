import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/wave_background.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/secure_storage_service.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  String filterType = 'all';

  Future<void> _fetchHistory() async {
    final token = await SecureStorageService.getToken();
    
    if (token != null) {
      final data = await ApiService.getNotificationHistory(token);
      if (mounted) {
        setState(() {
          notifications = data;
          isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    final token = await SecureStorageService.getToken();
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear History?"),
        content: const Text("This will permanently delete all notification history."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Clear", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );

    if (confirmed == true) {
      setState(() => isLoading = true);
      final success = await ApiService.clearNotificationHistory(token);
      if (success) _fetchHistory();
      else setState(() => isLoading = false);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'expiry': return Icons.history;
      case 'temperature': return Icons.thermostat;
      case 'humidity': return Icons.water_drop;
      case 'spoilage': return Icons.air;
      case 'door': return Icons.door_front_door;
      default: return Icons.notifications_paused;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'expiry': return Colors.orange;
      case 'temperature': return Colors.red;
      case 'humidity': return Colors.blue;
      case 'spoilage': return Colors.purple;
      case 'door': return Colors.green;
      default: return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    final isDark = themeType == ThemeType.dark;
    
    Color textColor = isLight ? Colors.black87 : Colors.white;

    final filteredNotifs = filterType == 'all' 
      ? notifications 
      : notifications.where((n) => (n['type'] ?? 'info') == filterType).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Notification History", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: textColor),
            onSelected: (val) => setState(() => filterType = val),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'all', child: Text("All History")),
              const PopupMenuItem(value: 'expiry', child: Text("Expiry Only")),
              const PopupMenuItem(value: 'temperature', child: Text("Temp Alerts")),
              const PopupMenuItem(value: 'spoilage', child: Text("Spoilage")),
              const PopupMenuItem(value: 'door', child: Text("Door Alerts")),
            ],
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep, color: textColor.withOpacity(0.6)),
            onPressed: notifications.isEmpty ? null : _clearHistory,
          ),
        ],
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

          isLoading ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent)) 
          : filteredNotifs.isEmpty ? 
          Center(child: Text(filterType == 'all' ? "No history available" : "No results for this filter", style: TextStyle(color: isLight ? Colors.black54 : Colors.white70, fontSize: 16)))
          : SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 80, bottom: 20, left: 16, right: 16),
              itemCount: filteredNotifs.length,
              itemBuilder: (context, index) {
                final notif = filteredNotifs[index];
                final type = notif['type'] ?? 'info';
                final icon = _getIconForType(type);
                final color = _getColorForType(type);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Opacity(
                    opacity: 0.7, // Muted history
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isLight 
                                    ? Colors.grey.shade200 
                                    : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.05)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color),
                            ),
                            title: Text(
                              notif["title"] ?? "Alert",
                              style: TextStyle(color: isLight ? Colors.black54 : Colors.white70, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notif["message"] ?? "",
                                    style: TextStyle(color: isLight ? Colors.black45 : Colors.white54),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notif["createdAt"] != null 
                                      ? DateTime.parse(notif["createdAt"]).toLocal().toString().substring(0, 16)
                                      : "",
                                    style: TextStyle(color: isLight ? Colors.black38 : Colors.white38, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ).animate().fade(delay: (50 * (index % 10)).ms),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
