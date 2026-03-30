import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/wave_background.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'notification_history_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/secure_storage_service.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const NotificationsScreen({super.key, this.onBack});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> notifications = [];
  final Set<String> _animatingOutIds = {}; 

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    // 🔔 Real-time: refresh when backend pushes a new/updated notification
    SocketService.on('notification_update', _onSocketNotification);
  }

  void _onSocketNotification(dynamic data) {
    if (!mounted) return;
    // Refresh the full list from API to keep in sync
    _fetchNotifications();
  }

  @override
  void dispose() {
    SocketService.off('notification_update', _onSocketNotification);
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });
    final token = await SecureStorageService.getToken();
    
    if (token == null) {
      if (mounted) setState(() {
        isLoading = false;
        _errorMessage = "Not logged in. Please login to view notifications.";
      });
      return;
    }
    
    try {
      final data = await ApiService.getNotifications(token);
      if (mounted) {
        setState(() {
          notifications = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        isLoading = false;
        _errorMessage = "Failed to load notifications. Tap to retry.";
      });
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'expiry': return Icons.warning_amber_rounded;
      case 'temperature': return Icons.thermostat;
      case 'humidity': return Icons.water_drop;
      case 'gas': return Icons.air;
      case 'door': return Icons.door_front_door;
      default: return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
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
              final token = await SecureStorageService.getToken();
              if (token != null) {
                final success = await ApiService.clearNotifications(token);
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
                final token = await SecureStorageService.getToken();
                if (token != null) {
                  final itemsToClear = List<Map<String, dynamic>>.from(notifications);
                  for (var i = 0; i < itemsToClear.length; i++) {
                    if (!mounted) break;
                    setState(() {
                      _animatingOutIds.add(itemsToClear[i]['_id']);
                    });
                    await Future.delayed(const Duration(milliseconds: 80));
                  }
                  
                  await Future.delayed(const Duration(milliseconds: 300));

                  if (mounted) {
                    setState(() {
                      notifications.clear();
                      _animatingOutIds.clear();
                    });
                  }
                  
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

          isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent)) 
          : _errorMessage != null ?
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Colors.tealAccent, size: 64),
                  const SizedBox(height: 20),
                  Text(_errorMessage!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _fetchNotifications,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent.withOpacity(0.2),
                      foregroundColor: Colors.tealAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          )
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
                      setState(() {
                        notifications.removeAt(index);
                      });

                      final token = await SecureStorageService.getToken();
                      if (token != null) {
                        await ApiService.markNotificationRead(dismissedId, token);
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: isLight 
                                ? (isRead ? Colors.grey.shade200 : Colors.white) 
                                : (isRead ? Colors.white.withOpacity(0.05) : const Color(0xFF1E2A33).withOpacity(0.95)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border(
                          top: BorderSide(color: isLight ? Colors.white : Colors.white.withOpacity(0.12), width: 1.5),
                          left: BorderSide(color: isLight ? Colors.white : Colors.white.withOpacity(0.12), width: 1.5),
                          right: BorderSide(color: isLight ? Colors.white : Colors.white.withOpacity(0.12), width: 1.5),
                          bottom: BorderSide(color: color.withOpacity(isRead ? 0.2 : 0.8), width: 6), 
                        ),
                        boxShadow: isLight || isRead ? [] : [
                          BoxShadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ]
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(isRead ? 0.05 : 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withOpacity(isRead ? 0.1 : 0.3), width: 2),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Icon(icon, color: isRead ? color.withOpacity(0.4) : color, size: 28),
                              if (!isRead)
                                const Positioned(
                                  top: -8,
                                  right: -8,
                                  child: Text("🧊", style: TextStyle(fontSize: 14)), 
                                )
                            ],
                          ),
                        ),
                        title: Text(
                          notif["title"] ?? "Alert",
                          style: TextStyle(
                            color: isLight ? (isRead ? Colors.black54 : Colors.black87) : (isRead ? Colors.white70 : Colors.white), 
                            fontWeight: FontWeight.w900, 
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notif["message"] ?? "",
                                style: TextStyle(color: isLight ? (isRead ? Colors.black45 : Colors.black87) : (isRead ? Colors.white54 : Colors.white70), fontSize: 13, height: 1.3),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(isRead ? 0.05 : 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    notif["createdAt"] != null 
                                        ? _formatTimestamp(notif["createdAt"])
                                        : "",
                                    style: TextStyle(color: color.withOpacity(isRead ? 0.5 : 0.9), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: !isRead ? IconButton(
                          icon: Icon(Icons.done_all, color: color, size: 24),
                          onPressed: () async {
                            final token = await SecureStorageService.getToken();
                            if (token != null) {
                              await ApiService.markNotificationRead(notif['_id'], token);
                              _fetchNotifications();
                            }
                          },
                          tooltip: "Mark as Read",
                        ).animate().scale(duration: 300.ms, curve: Curves.elasticOut)
                        : Icon(Icons.done_all, color: color.withOpacity(0.3), size: 20),
                      ),
                    ),
                  ),
                ).animate(
                  target: _animatingOutIds.contains(notif['_id']) ? 1 : 0,
                )
                 .fadeIn(delay: (50 * index).ms, duration: 500.ms)
                 .scale(delay: (50 * index).ms, duration: 600.ms, curve: Curves.elasticOut, begin: const Offset(0.8, 0.8))
                 .then(delay: 0.ms)
                 .slideX(end: -1.5, duration: 400.ms, curve: Curves.easeInCubic)
                 .fadeOut(duration: 300.ms);
              },
            ),
          ),
        ],
      ),
    );
  }
}
