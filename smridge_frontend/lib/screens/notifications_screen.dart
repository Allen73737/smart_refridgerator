import 'dart:async';
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
import '../models/inventory_item.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const NotificationsScreen({super.key, this.onBack});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool isLoading = true;
  String? _errorMessage;
  
  // 🛡️ Track timers already sent to shade in this session to prevent spam suppression
  static final Set<int> _triggeredTimers = {};
  // 🗑️ Track timers manually dismissed by the user in this session
  static final Set<int> _dismissedTimerIds = {};
  List<Map<String, dynamic>> notifications = [];
  List<InventoryItem> activeReminders = [];
  List<dynamic> combinedFeed = [];
  final Set<String> _animatingOutIds = {};
  Timer? _countdownTimer; // For live countdown refresh

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    // 🔔 Refresh countdown every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && activeReminders.isNotEmpty) setState(() {});
    });
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
    _countdownTimer?.cancel();
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
      final items = await ApiService.getInventory(token);
      
      final now = DateTime.now();
      // 🔔 User-set Reminders
      final reminders = items.where((i) => i.reminderDate != null && i.reminderDate!.toLocal().isAfter(now)).toList();
      // 🔔 Items expiring within 72 hours (3 days) - Matched to HomeScreen logic
      final expiringSoon = items.where((i) {
        final diff = i.expiryDate.toLocal().difference(now);
        return diff.isNegative == false && diff.inHours < 72;
      }).toList();

      final List<InventoryItem> timers = [...reminders, ...expiringSoon];
      // deduplicate if an item is in both (though reminder is usually set before expiry)
      final seenIds = <String>{};
      timers.retainWhere((item) {
        final id = item.id ?? item.name;
        final int safeId = (id.hashCode).abs() % 100000;
        return seenIds.add(id) && !_dismissedTimerIds.contains(safeId);
      });

      List<dynamic> combined = [];
      if (timers.isNotEmpty) {
        combined.add("HEADER_TIMERS");
        combined.addAll(timers);
        // 🔔 Re-trigger live shade countdown for each active timer (Once per session to avoid spam)
        for (final t in timers) {
          final int safeId = (t.id?.hashCode ?? t.name.hashCode).abs() % 100000;
          if (t.reminderDate != null && t.reminderDate!.toLocal().isAfter(now)) {
            NotificationService().scheduleLocalReminder(
              safeId, t.name, t.reminderDate!.toLocal(),
              imagePath: t.imagePath,
            );
          } else {
            // Expiring item (no custom reminder set but within 3h)
            NotificationService().showCountdownNotification(
              t.name, t.expiryDate.toLocal(),
              itemId: safeId,
            );
          }
        }
      }
      if (data.isNotEmpty) {
        combined.add("HEADER_ALERTS");
        combined.addAll(data);
      }

      if (mounted) {
        setState(() {
          notifications = data;
          activeReminders = timers;
          combinedFeed = combined;
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
      case 'reminder': return Icons.timer;
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
      case 'reminder': return Colors.amberAccent;
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
          if (notifications.isNotEmpty || activeReminders.isNotEmpty)
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
                      combinedFeed.removeWhere((item) => item is Map<String, dynamic> || item == "HEADER_ALERTS");
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
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
              
              SafeArea(
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: isLoading 
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
                  : combinedFeed.isEmpty ? 
                  RefreshIndicator(
                    onRefresh: _fetchNotifications,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: constraints.maxHeight * 0.4),
                        Center(child: Text("No new notifications", style: TextStyle(color: isLight ? Colors.black54 : Colors.white70, fontSize: 16))),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                      onRefresh: _fetchNotifications,
                      color: Colors.tealAccent,
                      backgroundColor: const Color(0xFF1E2A33),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 80, bottom: 20, left: 16, right: 16),
                        itemCount: combinedFeed.length,
                        itemBuilder: (context, index) {
                          final item = combinedFeed[index];

                          if (item == "HEADER_TIMERS") {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 12, left: 8, top: 8),
                              child: Text("⚡ LIVE TIMERS", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                            );
                          } else if (item == "HEADER_ALERTS") {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 12, left: 8, top: 16),
                              child: Text("🔔 ALERTS & HISTORY", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                            );
                          } else if (item is InventoryItem) {
                            return _buildLiveTimerCard(item, isLight, isDark);
                          }

                          // Standard Backend Notification
                          final notif = item as Map<String, dynamic>?;
                          if (notif == null) return const SizedBox.shrink();

                          final type = (notif['type'] ?? 'info').toString().toLowerCase();
                          final icon = _getIconForType(type);
                          final color = _getColorForType(type);
                          final isRead = notif['isRead'] == true;

                          Widget baseWidget = Padding(
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
                                  border: Border.all(
                                    color: isLight ? Colors.white : Colors.white.withOpacity(0.12),
                                    width: 1.5,
                                  ),
                                  boxShadow: isLight || isRead ? [] : [
                                    BoxShadow(
                                      color: color.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    )
                                  ]
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
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
                                                  color: color.withOpacity(0.05),
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
                                    // 🔹 Bottom accent bar (replaces non-uniform border bottom)
                                    Container(
                                      height: 5,
                                      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(isRead ? 0.2 : 0.8),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );

                          if (_animatingOutIds.contains(notif['_id'])) {
                            return baseWidget.animate()
                              .slideX(begin: 0.0, end: -1.5, duration: 400.ms, curve: Curves.easeInCubic)
                              .fadeOut(duration: 300.ms);
                          }
                          return baseWidget;
                        },
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLiveTimerCard(InventoryItem item, bool isLight, bool isDark) {
    final now = DateTime.now().toUtc();
    final isReminder = item.reminderDate != null && item.reminderDate!.toUtc().isAfter(now);
    final targetTime = isReminder ? item.reminderDate!.toUtc() : item.expiryDate.toUtc();
    Color color = isReminder ? Colors.amberAccent : Colors.redAccent;
    final diff = targetTime.difference(now);

    // ⏳ Format as countdown: "in 2h 30m 15s" or "OVERDUE"
    String countdownStr;
    if (diff.isNegative) {
      countdownStr = "DEADLINE PASSED";
      color = Colors.redAccent;
    } else if (diff.inHours >= 24) {
      final d = diff.inDays;
      final h = diff.inHours % 24;
      countdownStr = "in ${d}d ${h}h";
    } else if (diff.inHours >= 1) {
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      countdownStr = "in ${h}h ${m}m";
    } else if (diff.inMinutes >= 1) {
      final m = diff.inMinutes;
      final s = diff.inSeconds % 60;
      countdownStr = "in ${m}m ${s}s";
      color = Colors.orangeAccent;
    } else {
      countdownStr = "in ${diff.inSeconds}s";
      color = Colors.redAccent;
    }

    // Wall-clock time for reference
    final timeStr = "${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}";
    final dateStr = "${targetTime.day}/${targetTime.month}/${targetTime.year}";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF1E2A33).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: isLight ? [] : [
          BoxShadow(color: color.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
        ]
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, color: color, size: 16),
              Text(
                countdownStr.startsWith("in ") ? countdownStr.substring(3) : countdownStr,
                style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        title: Text(
          "⏳ ${item.name.toUpperCase()}",
          style: TextStyle(
            color: isLight ? Colors.black87 : Colors.white, 
            fontWeight: FontWeight.w900, 
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Deadline: $dateStr at $timeStr",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: isLight ? Colors.black54 : Colors.white60, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(countdownStr.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                    child: Text(isReminder ? "REMINDER ACTIVE" : "EXPIRY PROTOCOL", style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, color: color.withOpacity(0.6), size: 20),
          onPressed: () async {
            final int safeId = (item.id?.hashCode ?? item.name.hashCode).abs() % 100000;
            // 1. Cancel in OS shade
            await NotificationService().cancelNotification(safeId + 30000); // For reminders
            await NotificationService().cancelNotification(safeId); // For expiry
            
            // 2. Hide in App UI
            if (mounted) {
              setState(() {
                _dismissedTimerIds.add(safeId);
                // Also update combined feed right away
                combinedFeed.remove(item);
                activeReminders.removeWhere((t) => (t.id ?? t.name) == (item.id ?? item.name));
              });
            }
          },
          tooltip: "Dismiss Timer",
        ).animate().scale(duration: 200.ms),
      ),
    );
  }
}
