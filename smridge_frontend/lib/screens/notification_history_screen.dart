import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/wave_background.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
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
    // 🔔 Real-time: refresh when backend pushes a notification update (e.g., item archived)
    SocketService.on('notification_update', _onSocketNotification);
  }

  void _onSocketNotification(dynamic data) {
    if (!mounted) return;
    _fetchHistory();
  }

  @override
  void dispose() {
    SocketService.off('notification_update', _onSocketNotification);
    super.dispose();
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
      case 'add_item': return Icons.add_circle_outline;
      case 'update_item': return Icons.edit_note;
      case 'delete_item': return Icons.delete_forever;
      default: return Icons.notifications_none;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'expiry': return Colors.orange;
      case 'temperature': return Colors.red;
      case 'humidity': return Colors.blue;
      case 'spoilage': return Colors.purple;
      case 'door': return Colors.green;
      case 'add_item': return Colors.tealAccent;
      case 'update_item': return Colors.blueAccent;
      case 'delete_item': return Colors.redAccent;
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
        title: Text("Notification History", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        actions: [
          Theme(
            data: Theme.of(context).copyWith(
              cardColor: isLight ? Colors.white : const Color(0xFF1E2A33),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.filter_list, color: isLight ? Colors.teal : Colors.tealAccent),
              onSelected: (val) => setState(() => filterType = val),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'all', child: Text("All History")),
                const PopupMenuItem(value: 'expiry', child: Text("Expiry Only")),
                const PopupMenuItem(value: 'temperature', child: Text("Temp Alerts")),
                const PopupMenuItem(value: 'spoilage', child: Text("Spoilage")),
                const PopupMenuItem(value: 'door', child: Text("Door Alerts")),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep, color: Colors.redAccent.withOpacity(0.8)),
            onPressed: notifications.isEmpty ? null : _clearHistory,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isLight ? const Color(0xFFF3F6F8) : (isDark ? Colors.black : Colors.black),
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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 80, color: textColor.withOpacity(0.1)),
                const SizedBox(height: 16),
                Text(filterType == 'all' ? "No history available" : "No results for this filter", 
                  style: TextStyle(color: isLight ? Colors.black54 : Colors.white24, fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          )
          : SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 20, bottom: 40, left: 20, right: 20),
              itemCount: filteredNotifs.length,
              itemBuilder: (context, index) {
                final notif = filteredNotifs[index];
                final type = notif['type'] ?? 'info';
                final icon = _getIconForType(type);
                final color = _getColorForType(type);
                final isUrgent = type == 'expiry' || type == 'temperature' || type == 'spoilage';
 
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isLight 
                                  ? Colors.white.withOpacity(0.8) 
                                  : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isUrgent 
                                ? color.withOpacity(0.3) 
                                : (isLight ? Colors.transparent : Colors.white.withOpacity(0.1)),
                            width: isUrgent ? 1.5 : 1,
                          ),
                          boxShadow: [
                            if (isUrgent) BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)
                          ]
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, spreadRadius: -2)
                              ]
                            ),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  notif["title"] ?? "Alert",
                                  style: TextStyle(
                                    color: isLight ? Colors.black87 : Colors.white, 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (isUrgent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "PRIORITY",
                                    style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif["message"] ?? "",
                                  style: TextStyle(
                                    color: isLight ? Colors.black54 : Colors.white70,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 12, color: isLight ? Colors.black38 : Colors.white38),
                                    const SizedBox(width: 4),
                                    Text(
                                      notif["createdAt"] != null 
                                        ? DateTime.parse(notif["createdAt"]).toLocal().toString().substring(0, 16)
                                        : "Unknown Date",
                                      style: TextStyle(
                                        color: isLight ? Colors.black38 : Colors.white38, 
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: (40 * (index % 15)).ms).slideY(begin: 0.05, end: 0);
              },
            ),
          ),
        ],
      ),
    );
  }
}
