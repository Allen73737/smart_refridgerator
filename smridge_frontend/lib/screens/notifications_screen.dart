import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/wave_background.dart';
import '../services/api_service.dart';
import 'notification_history_screen.dart';
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
  final Set<String> _animatingOutIds = {}; // 🔹 Track items sliding out

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
  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      return "${dt.day}/${dt.month}/${dt.year % 100}";
    } catch (e) {
      return "";
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
        actions: [
          IconButton(
            icon: Icon(Icons.done_all, color: textColor),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('token');
              if (token != null) {
                final success = await ApiService.clearNotifications(token); // clearAll in backend archives them
                if (success) _fetchNotifications();
              }
            },
            tooltip: "Mark All Read",
          ),
          IconButton(
            icon: Icon(Icons.history, color: textColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationHistoryScreen()),
              );
            },
            tooltip: "View History",
          ),
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token');
                if (token != null) {
                  // 🔹 Android-Style Sequential Slide-Left Animation
                  final itemsToClear = List<Map<String, dynamic>>.from(notifications);
                  for (var i = 0; i < itemsToClear.length; i++) {
                    if (!mounted) break;
                    setState(() {
                      _animatingOutIds.add(itemsToClear[i]['_id']);
                    });
                    await Future.delayed(const Duration(milliseconds: 80));
                  }
                  
                  // Wait for last animation to finish
                  await Future.delayed(const Duration(milliseconds: 300));

                  if (mounted) {
                    setState(() {
                      notifications.clear();
                      _animatingOutIds.clear();
                    });
                  }
                  
                  // Backend sync
                  await ApiService.clearNotifications(token);
                }
              },
              child: const Text("Clear All", style: TextStyle(color: Colors.redAccent)),
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
                  child: Dismissible(
                    key: Key(notif['_id']),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) async {
                      final dismissedId = notif['_id'];
                      // 1. Remove from local list immediately to prevent crash
                      setState(() {
                        notifications.removeAt(index);
                      });

                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('token');
                      if (token != null) {
                        // 2. Mark as archived in background
                        await ApiService.markNotificationRead(dismissedId, token);
                        // No need to call _fetchNotifications() here as it would trigger a full reload
                      }
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
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
                                child: Column(
                                  children: [
                                    Text(
                                      notif["message"] ?? "",
                                      style: TextStyle(color: isLight ? (isRead ? Colors.black45 : Colors.black54) : (isRead ? Colors.white54 : Colors.white70)),
                                    ),
                                    const SizedBox(height: 5),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        notif["createdAt"] != null 
                                            ? _formatTimestamp(notif["createdAt"])
                                            : "",
                                        style: TextStyle(color: isLight ? Colors.black38 : Colors.white38, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: !isRead ? IconButton(
                                icon: Icon(Icons.done_all, color: color, size: 20),
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  final token = prefs.getString('token');
                                  if (token != null) {
                                    await ApiService.markNotificationRead(notif['_id'], token);
                                    _fetchNotifications();
                                  }
                                },
                                tooltip: "Mark as Read",
                              ) : Icon(Icons.done_all, color: color.withOpacity(0.5), size: 18),
                            ),
                        ),
                      ),
                    ),
                  ).animate(
                    target: _animatingOutIds.contains(notif['_id']) ? 1 : 0,
                  ).slideX(begin: 0, end: -1.5, duration: 400.ms, curve: Curves.easeInCubic)
                   .fade(begin: 1.0, end: 0, duration: 300.ms)
                   .animate().fade(delay: (100 * (index % 5)).ms).slideX(begin: 0.1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
