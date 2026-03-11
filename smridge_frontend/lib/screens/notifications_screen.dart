import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/wave_background.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const NotificationsScreen({super.key, this.onBack});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token != null) {
      final data = await ApiService.getNotifications(token);
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

  IconData _getIconForType(String type) {
    switch (type) {
      case 'expiry': return Icons.warning_amber_rounded;
      case 'temperature': return Icons.thermostat;
      case 'humidity': return Icons.water_drop;
      case 'gas': return Icons.air;
      case 'door': return Icons.door_front_door;
      default: return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'expiry': return Colors.orangeAccent;
      case 'temperature': return Colors.redAccent;
      case 'humidity': return Colors.blueAccent;
      case 'gas': return Colors.yellowAccent;
      case 'door': return Colors.purpleAccent;
      default: return Colors.tealAccent;
    }
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
        title: Text("Notifications", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))
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

          isLoading ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent)) 
          : notifications.isEmpty ? 
          Center(child: Text("No new notifications", style: TextStyle(color: isLight ? Colors.black54 : Colors.white70, fontSize: 16)))
          : SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 80, bottom: 20, left: 16, right: 16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final type = notif['type'] ?? 'info';
                final icon = _getIconForType(type);
                final color = _getColorForType(type);
                final isRead = notif['isRead'] == true;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isLight 
                                  ? (isRead ? Colors.grey.shade200 : Colors.white) 
                                  : (isRead ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.08)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(isRead ? 0.05 : 0.15)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(isRead ? 0.1 : 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: isRead ? color.withOpacity(0.6) : color),
                          ),
                          title: Text(
                            notif["title"] ?? "Alert",
                            style: TextStyle(color: isLight ? (isRead ? Colors.black54 : Colors.black87) : (isRead ? Colors.white70 : Colors.white), fontWeight: FontWeight.bold),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              notif["message"] ?? "",
                              style: TextStyle(color: isLight ? (isRead ? Colors.black45 : Colors.black54) : (isRead ? Colors.white54 : Colors.white70)),
                            ),
                          ),
                          trailing: !isRead ? IconButton(
                            icon: Icon(Icons.check_circle_outline, color: isLight ? Colors.teal : Colors.tealAccent),
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              final token = prefs.getString('token');
                              if (token != null) {
                                await ApiService.markNotificationRead(notif['_id'], token);
                                _fetchNotifications();
                              }
                            },
                          ) : null,
                        ),
                      ),
                    ),
                  ).animate().fade(delay: (100 * (index % 5)).ms).slideX(begin: 0.1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
