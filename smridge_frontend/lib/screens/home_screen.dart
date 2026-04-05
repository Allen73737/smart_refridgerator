import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_device_screen.dart';
import '../models/inventory_item.dart';
import '../widgets/fridge_3d.dart';
import '../widgets/animated_bottom_dock.dart';
import '../widgets/creative_navbar.dart';
import '../core/page_transitions.dart';
import 'add_inventory_screen.dart';
import 'add_inventory_choice_screen.dart';
import 'inventory_list_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'analytics_screen.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/wave_background.dart';
import 'barcode_scanner_screen.dart';
import 'account_profile_screen.dart';
import '../services/notification_service.dart';
import 'privacy_policy_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/fridge_customization_provider.dart';
import '../providers/sensor_provider.dart'; // 🚀 Added
import 'activity_screen.dart';
import 'help_support_screen.dart';
import 'theme_settings_screen.dart';
import 'about_screen.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/liquid_freshness_bar.dart'; // Added for completeness, though already used
import '../widgets/system_monitoring_indicators.dart'; // New import
import '../widgets/product_details_overlay.dart'; // New import
import '../widgets/chat_assistant_overlay.dart'; // New import
import '../services/socket_service.dart';
import '../services/icon_service.dart';
import '../services/haptic_service.dart';
import '../services/widget_service.dart'; // 🚀 Added
import '../widgets/app_walkthrough.dart'; // 🎯
import 'package:vibration/vibration.dart'; // 📳 Added for intense alerts

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum AddFlowState { choice, scanner, manual }

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<Fridge3DState> _fridgeKey = GlobalKey<Fridge3DState>();
  StreamSubscription<String?>? _notifSubscription; // 🔹 For deep links
  StreamSubscription<String>? _emergencySubscription; // 🚨 For urgent alerts
  double? _swipeStartX; // 🔹 For swipe navigation tracking
  double _swipeDelta = 0; // 🔹 Track swipe distance
  
  // 🎯 Walkthrough Keys
  final GlobalKey _wtFridgeKey = GlobalKey();
  final GlobalKey _wtStatusKey = GlobalKey();
  final GlobalKey _wtInventoryKey = GlobalKey();
  final GlobalKey _wtAddKey = GlobalKey();
  final GlobalKey _wtSettingsKey = GlobalKey();
  final GlobalKey _wtNotificationKey = GlobalKey();
  
  // 🎯 Dock Unique Keys (to prevent GlobalKey duplicate conflict)
  final GlobalKey _wtDockFridgeKey = GlobalKey();
  final GlobalKey _wtDockStatusKey = GlobalKey();
  final GlobalKey _wtDockInventoryKey = GlobalKey();
  final GlobalKey _wtDockAddKey = GlobalKey();
  final GlobalKey _wtDockNotificationKey = GlobalKey();
  final GlobalKey _wtDockSettingsKey = GlobalKey();

  int selectedTab = 0;
  List<InventoryItem> inventory = [];
  bool _showWalkthrough = false; // 🎯
  List<WalkthroughStep> _currentWalkthroughSteps = []; // 🎯
  final Set<String> _activeAlertItems = {}; // 🚨 Track items currently showing alerts

  //////////////////////////////////////////////////////////////
  // 🔹 INVENTORY ADD FLOW STATE
  //////////////////////////////////////////////////////////////

  AddFlowState _addFlowState = AddFlowState.choice;
  InventoryItem? _scannedItem;
  bool _isInventoryLoading = true; 
  int? _editItemIndex;
  int unreadNotifications = 0;
  Timer? _expiryCheckTimer; // 🔹 Added for periodic check
  DateTime? _lastSyncTime;
  final Duration _syncThrottle = const Duration(seconds: 10);

  //////////////////////////////////////////////////////////////
  // 🔹 PROFILE DATA
  //////////////////////////////////////////////////////////////

  // 🛡️ DATA UNIFICATION: Multi-sensor state handled by SensorProvider
  String weatherTemp = "--";
  String weatherIcon = "01d";
  String timezone = "Loading...";
  InventoryItem? _selectedItemForDetails;
  bool _showChatbot = false; // Chatbot trigger

  String? currentDeviceId; // 🆕 Track linked device serial
  String? deviceName;
  bool _isDeviceLoading = true;
  
  String userName = "Loading...";
  String userEmail = "Loading...";
  String? profileImageUrl;
  File? profileImage;

  // 🔹 DRAGGABLE CHAT ICON STATE
  Offset _chatIconPosition = const Offset(20, 140); // Default position (bottom-right area)

  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialTab;
    _fetchProfile();
    _loadInventory();
    _fetchNotificationsCount();
    _initSocket();
    _setupNotifications();
    _setupDeepLinking(); // 🔹 Handle notification taps
    _logAppOpen();

    // 🚨 Emergency Protocol: Listen for foreground timer expirations
    _emergencySubscription = NotificationService.expiredTimerStream.stream.listen((itemName) {
      _handleEmergency(itemName);
    });

    // 🔹 Start periodic expiry check & widget sync
    _checkExpiryTimers(); 
    _updateWidgetTimers(); 
    _expiryCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkExpiryTimers();
      _updateWidgetTimers();
    });

    _checkInitialUnreadAlert();

    WidgetsBinding.instance.addObserver(this);

    // 🎯 Walkthrough and Network Check
    Future.delayed(1.seconds, () {
      _checkWalkthrough();
      _checkNetworkChange();
    });
  }

  void _handleEmergency(String itemName) {
    if (!mounted || _activeAlertItems.contains(itemName)) return;
    
    setState(() => _activeAlertItems.add(itemName));
    
    // 📳 Trigger Intense Vibration Loop
    Vibration.vibrate(pattern: [500, 500, 500, 500], repeat: 0);

    // 🔊 Play Urgent Audio Loop
    AudioService.playUrgentAlert();

    // 🖼️ Show Cinematic Dialog
    _showEmergencyDialog(itemName);
  }

  void _showEmergencyDialog(String itemName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) {
        return WillPopScope(
          onWillPop: () async => false,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Material(
              type: MaterialType.transparency,
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 80)
                        .animate(onPlay: (controller) => controller.repeat())
                        .shake(duration: 800.ms, hz: 6)
                        .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.1, 1.1), curve: Curves.easeInOut)
                        .then().scale(begin: const Offset(1.1, 1.1), end: const Offset(1.0, 1.0)),
                      const SizedBox(height: 20),
                      Text(
                        "TIMER EXPIRED",
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          decoration: TextDecoration.none, // Explicitly safe
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Protocol 🚨: $itemName",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.none, 
                        ),
                      ),
                      const SizedBox(height: 40),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (mounted) {
                                Navigator.pop(context);
                                setState(() => _activeAlertItems.remove(itemName));
                              }
                              HapticService.heavy();
                              NotificationService().cancelAllForItem(itemName);
                              Vibration.cancel();
                              AudioService.stopUrgentAlert();
                            },
                            splashColor: Colors.white.withOpacity(0.3),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF3D00), Color(0xFFFF8A65)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  "DISMISS ALERT",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    fontSize: 15,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
              ),
            ),
          ),
        );
      },
    );
  }

  /// ⏲️ Sync active timers to the Android Home Screen Chrono widget
  void _updateWidgetTimers() {
    try {
      final now = DateTime.now().toUtc();
      
      // 🎯 Prioritize items with manual reminders or early expiries
      final activeTimers = inventory.where((item) {
        final targetDate = item.reminderDate ?? item.expiryDate;
        return targetDate.toUtc().isAfter(now) && targetDate.toUtc().difference(now).inHours <= 168; // 7 Day Window
      }).toList();

      // 🕒 Sort by earliest timer first
      activeTimers.sort((a, b) {
        final dateA = a.reminderDate ?? a.expiryDate;
        final dateB = b.reminderDate ?? b.expiryDate;
        return dateA.compareTo(dateB);
      });

      final timerList = activeTimers.map((item) {
        final targetDate = item.reminderDate ?? item.expiryDate;
        return {
          "name": item.name,
          "target": targetDate.toUtc().millisecondsSinceEpoch,
        };
      }).toList();

      WidgetService.updateTimerListWidget(jsonEncode(timerList));
    } catch (e) {
      debugPrint("❌ SMRIDGE WIDGET Error: $e");
    }
  }

  Future<void> _checkNetworkChange() async {
    final token = await SecureStorageService.getToken();
    if (token == null) return; // Only for logged in users

    try {
      final info = NetworkInfo();
      String? currentSsid = await info.getWifiName();
      if (currentSsid == null) return;
      
      // Remove quotes
      if (currentSsid.startsWith('"') && currentSsid.endsWith('"')) {
        currentSsid = currentSsid.substring(1, currentSsid.length - 1);
      }

      final lastSsid = await SecureStorageService.getString('last_known_ssid');
      
      if (lastSsid != null && lastSsid != currentSsid && !currentSsid.contains("SMRIDGE_SETUP")) {
        print("🌐 Network Change Detected: $lastSsid -> $currentSsid");
        if (mounted) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDeviceScreen()));
        }
      }

      await SecureStorageService.saveString('last_known_ssid', currentSsid);
    } catch (e) {
      print("Network Check Error: $e");
    }
  }

  Future<void> _checkWalkthrough() async {
    final seen = await SecureStorageService.hasSeenWalkthrough();
    if (!seen && mounted) {
      _triggerTabWalkthrough(0);
      await SecureStorageService.setWalkthroughSeen(true); // Mark general as seen
    }
  }

  Future<void> _logAppOpen() async {
    final token = await SecureStorageService.getToken();
    if (token != null) {
      await ApiService.logActivity("APP_OPEN", "User opened the Smridge app", token, color: '#FFAA00');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryCheckTimer?.cancel(); 
    _notifSubscription?.cancel(); 
    _emergencySubscription?.cancel();
    AudioService.stopUrgentAlert();
    Vibration.cancel();
    SocketService.off('inventory_update');
    SocketService.off('sensor_data');
    SocketService.off('notification_update');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print("🚀 App Resumed: Syncing timers and notifications...");
      _checkExpiryTimers();
      _fetchNotificationsCount();
    }
  }

  // 🚀 Notification Deep Linking Logic
  Future<void> _setupDeepLinking() async {
    // 1. App launched from terminated state via notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleNotificationPayload(initialMessage.data['payload'] ?? initialMessage.data['itemId']);

    // 2. App opened from background via Firebase Push
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationPayload(message.data['payload'] ?? message.data['itemId']);
    });

    // 3. Local Notification Clicked (Foreground or Background)
    _notifSubscription = NotificationService.selectNotificationStream.stream.listen((payload) {
      if (payload != null) _handleNotificationPayload(payload);
    });
  }

  void _handleNotificationPayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    print("🚀 Deep Link Triggered: $payload");

    // 1. JSON Payload Handling Feature (Navigation)
    if (payload.startsWith('{') && payload.endsWith('}')) {
      try {
        final data = json.decode(payload);
        if (data['route'] == '/add_inventory') {
          // Open Add Inventory and optionally pass recorded weight
          String rawWeight = data['recordedWeight'] ?? "";
          double? initialWeight;
          if (rawWeight.isNotEmpty) {
            initialWeight = double.tryParse(rawWeight);
          }
          
          if (mounted) {
             Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => AddInventoryScreen(
                 initialWeight: initialWeight,
               )),
             );
          }
        }
        return;
      } catch (e) {
        print("Error parsing deep link JSON: $e");
      }
    }

    // 2. Legacy text payload handling
    if (payload.startsWith('inventory:')) {
      final itemName = payload.split('inventory:').last;
      
      // Wait for inventory to load if app just started
      for (int i=0; i<10; i++) {
        if (inventory.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      try {
        final item = inventory.firstWhere((i) => i.name == itemName);
        if (mounted) {
          setState(() => selectedTab = 0); // Open Fridge view as safest
          // Give UI a moment to build tab
          await Future.delayed(const Duration(milliseconds: 300));
          _showProductDetails(item);
        }
      } catch (e) {
        print("Item not found for deep link: $itemName");
      }
    }
  }

  // 🚀 Schedule background notifications for all items
  Future<void> _scheduleExpiryAlerts(List<InventoryItem> items) async {
    final service = NotificationService();
    // ⚠️ DO NOT call cancelAllScheduled() here - it destroys reminder timers!
    // Only cancel and re-schedule expiry alerts (IDs based on stableId directly)

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final stableId = (item.id.hashCode.abs()) % 100000;

      // 🚨 Cancel previous expiry alert for this item then re-schedule
      await service.cancelNotification(stableId);
      await service.scheduleExpiryNotification(stableId, item.name, item.expiryDate);

      // ⏰ Schedule reminder timer only if set and in the future
      if (item.reminderDate != null && item.reminderDate!.toLocal().isAfter(DateTime.now())) {
        await service.scheduleLocalReminder(stableId, item.name, item.reminderDate!.toLocal());
      }
    }
  }

  Future<void> _checkInitialUnreadAlert() async {
    await Future.delayed(const Duration(seconds: 3)); // Wait for data to load
    if (unreadNotifications > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "You have $unreadNotifications unread notifications, watch out!",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: "VIEW",
            textColor: Colors.white,
            onPressed: () => setState(() => selectedTab = 4),
          ),
        ),
      );
    }
  }

  Future<void> _fetchNotificationsCount() async {
    final token = await SecureStorageService.getToken();
    if (token != null) {
      final notifs = await ApiService.getNotifications(token);
      if (mounted) {
        final List<dynamic> unreadNotifs = notifs.where((n) => n != null && n['isRead'] == false).toList();
        setState(() {
          unreadNotifications = unreadNotifs.length;
        });

        // 📡 Sync unread backend notifications to local device notification shade
        final prefs = await SharedPreferences.getInstance();
        final List<String> shownNotifIds = prefs.getStringList('shown_notif_ids') ?? [];
        
        for (var n in unreadNotifs) {
          final String id = n['_id']?.toString() ?? "";
          if (id.isNotEmpty && !shownNotifIds.contains(id)) {
            // New unread notification! Show it in the shade
            final String type = (n['type'] ?? '').toString().toLowerCase();
            
            // 🛡️ DEDUPLICATION: Skip expiry/reminder notifications here 
            // as they are handled by the specialized Timer logic or direct FCM
            if (type == 'expiry' || type == 'reminder') {
              shownNotifIds.add(id);
              continue;
            }

            await NotificationService().showNotification(
              n['title'] ?? "Smridge Alert",
              n['message'] ?? "",
              colorHex: type == 'critical' ? '#FF007A' : '#00F2FF',
              context: context,
            );
            shownNotifIds.add(id);
          }
        }
        
        // Keep only last 50 IDs to avoid hitting SharedPreferences limits
        if (shownNotifIds.length > 50) {
          shownNotifIds.removeRange(0, shownNotifIds.length - 50);
        }
        await prefs.setStringList('shown_notif_ids', shownNotifIds);
      }
    }
  }

  Future<void> _setupNotifications() async {
    final service = NotificationService();
    await service.requestPermissions();
    
    // 📡 Get current token and sync to backend
    final fcmToken = await service.getToken();
    if (fcmToken != null) {
      final authToken = await SecureStorageService.getToken();
      if (authToken != null) {
        print("📲 Syncing FCM Token: $fcmToken");
        await ApiService.saveFcmToken(fcmToken, authToken);
      }
    }

    service.listenToTokenRefresh((token) async {
      final authToken = await SecureStorageService.getToken();
      if (authToken != null) {
        print("📲 Token Refreshed: $token");
        await ApiService.saveFcmToken(token, authToken);
      }
    });
  }

  void _initSocket() {
    SocketService.init();
    
    // Listen for inventory updates
    SocketService.on('inventory_update', (data) {
      print('📺 Socket Inventory Update Received: $data');
      _loadInventory(); // Re-fetch inventory when any change occurs
      
      if (data['action'] == 'add') {
        SnackbarUtils.showInfo(context, 'New item ${data['item']['name']} added! 🧊');
      } else if (data['action'] == 'update') {
        SnackbarUtils.showInfo(context, 'Item ${data['item']['name']} updated! ✨');
      } else if (data['action'] == 'delete') {
        SnackbarUtils.showInfo(context, 'Item ${data['name'] ?? 'Unknown'} removed from fridge.');
      }
    });

    // 🧬 DATA UNIFICATION: Sensor data is now handled centrally by SensorProvider
    // but we still sync it to the Home Widget here to ensure background consistency
    SocketService.on('sensor_data', (data) {
       if (mounted) {
         final sensor = context.read<SensorProvider>();
         final isCritical = sensor.temperature > 5.0 || sensor.gasLevel > 200 || (sensor.freshnessScore / 100.0) < 0.3;
         
         if (isCritical) {
            IconService.updateToCriticalIcon();
         } else {
            IconService.updateToNormalIcon();
         }

         WidgetService.updateWidgetData(
           temperature: sensor.temperature,
           humidity: sensor.humidity,
           freshness: sensor.freshnessScore / 100.0,
           doorStatus: sensor.doorStatus ?? "CLOSED",
           status: isCritical ? "CRITICAL" : "OPTIMAL",
           inventoryJson: jsonEncode(inventory.map((i) => i.name).toList()),
           notificationsJson: jsonEncode(["$unreadNotifications Unread ALERTS"]),
         );
       }
    });

    // 🔹 Listen for notification updates to sync badge count
    SocketService.on('notification_update', (data) {
      print('🔔 Notification Update Received: $data');
      _fetchNotificationsCount();
    });
  }

  // 🧬 DATA UNIFICATION: Logic removed in favor of SensorProvider

  void _addFood() {
    setState(() {
      _editItemIndex = null;
      _scannedItem = null;
      _addFlowState = AddFlowState.choice;
      selectedTab = 3;
    });
  }

  Future<void> _loadInventory() async {
    final token = await SecureStorageService.getToken();
    
    if (token != null) {
      final items = await ApiService.getInventory(token);
      if (mounted) {
        setState(() {
          inventory = items;
          _isInventoryLoading = false; 
        });
        
        // 🕒 Schedule Background Notifications for Expiry
        _scheduleExpiryAlerts(items);
        IconService.updateAppIcon(items); 
        WidgetService.updateInventoryCount(items.length); // 🚀 Update Widget
      }
    }
  }

  void _checkExpiryTimers() {
    if (inventory.isEmpty) return;
    
    InventoryItem? nearestItem;
    DateTime? nearestTime;
    final now = DateTime.now();

    for (var item in inventory) {
       final stableId = (item.id.hashCode.abs()) % 100000;
       final localExpiry = item.expiryDate.toLocal();
       
       // ⏲️ AUTOMATIC LIVE TIMER: Show tracker if within 72 hours (3 days)
       if (localExpiry.difference(now).inHours <= 72) {
         NotificationService().showCountdownNotification(item.name, localExpiry, itemId: stableId);
       }
       
       // Track nearest for Widget
       final itemTarget = (item.reminderDate != null && item.reminderDate!.toLocal().isAfter(now)) 
           ? item.reminderDate!.toLocal() 
           : localExpiry;
           
       if (itemTarget.isAfter(now)) {
         if (nearestTime == null || itemTarget.isBefore(nearestTime)) {
           nearestTime = itemTarget;
           nearestItem = item;
         }
       }
    }

    // 📡 SYNC NEAREST TIMER TO WIDGETS
    if (nearestItem != null && nearestTime != null) {
      final sensor = context.read<SensorProvider>();
      final isCritical = sensor.temperature > 5.0 || sensor.gasLevel > 200 || (sensor.freshnessScore / 100.0) < 0.3;
      WidgetService.updateWidgetData(
        temperature: sensor.temperature,
        humidity: sensor.humidity,
        freshness: sensor.freshnessScore / 100.0,
        doorStatus: sensor.doorStatus ?? "CLOSED",
        status: isCritical ? "CRITICAL" : "OPTIMAL",
        timerTitle: nearestItem.name,
        targetTimestamp: nearestTime.millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _fetchProfile() async {
    final token = await SecureStorageService.getToken();
    if (token != null && token.isNotEmpty && token != 'mock-token') {
      final profile = await ApiService.getProfile(token);
      if (profile != null && mounted) {
        setState(() {
          userName = profile['name'] ?? "Smridge User";
          userEmail = profile['email'] ?? "user@email.com";
          
          // 🆕 Extract Device Info (Populated ObjectId from Backend)
          if (profile['deviceId'] != null) {
            final dev = profile['deviceId'];
            if (dev is Map) {
              currentDeviceId = dev['deviceId'];
              deviceName = dev['name'];
            }
          }
          
          final rawImg = profile['profileImage'];
          if (rawImg != null && rawImg.isNotEmpty) {
            profileImageUrl = rawImg.startsWith('http') ? rawImg : "${ApiService.baseDomain}/uploads/$rawImg";
          } else {
            profileImageUrl = null;
          }
          _isDeviceLoading = false;
        });
        
        // 🔄 Always fetch latest data (Backend now resolves by User ID)
        _fetchLatestDeviceData();
      } else if (mounted) {
        setState(() {
          userName = "Session Expired";
          userEmail = "Please login again";
        });
      }
    } else {
      if (mounted) {
        setState(() {
          userName = "Guest User";
          userEmail = "Please login via settings";
        });
      }
    }
  }

  Future<void> _fetchLatestDeviceData() async {
    final token = await SecureStorageService.getToken();
    if (token == null) return;
    
    final data = await ApiService.getLatestSensorData(currentDeviceId ?? 'auto', token);
    if (data != null && mounted) {
      // 🚀 Sync to centralized provider
      final sensorProv = context.read<SensorProvider>();
      sensorProv.updateFromData(data);
      
      // 📊 Also preload history for the Sparkline
      final trendData = await ApiService.getTemperatureTrend(token);
      if (trendData.isNotEmpty) {
        sensorProv.setInitialHistory(trendData);
      }
    }
  }

  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        profileImage = File(pickedFile.path);
      });

      // --- IMMEDIATE CLOUD SYNC ---
      final token = await SecureStorageService.getToken();
      if (token != null && token.isNotEmpty && token != 'mock-token') {
        final success = await ApiService.uploadProfileImage(File(pickedFile.path), token);
        if (success) {
           _fetchProfile(); // Refresh to get the new URL
        } else {
           if (mounted) SnackbarUtils.showError(context, "Failed to sync profile photo to cloud/local storage.");
        }
      }
    }
  }

  void editProfileDialog() {
    TextEditingController nameController =
        TextEditingController(text: userName);
    TextEditingController emailController =
        TextEditingController(text: userEmail);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2A33),
          title: const Text("Edit Profile",
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Name",
                    labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Email",
                    labelStyle: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = await SecureStorageService.getToken();
                
                if (token != null) {
                  final success = await ApiService.updateProfile(nameController.text, emailController.text, token);
                  if (success && mounted) {
                    setState(() {
                      userName = nameController.text;
                      userEmail = emailController.text;
                    });
                  } else if (mounted) {
                    SnackbarUtils.showError(context, "Failed to save profile");
                  }
                }
                
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            )
          ],
        );
      },
    );
  }

  //////////////////////////////////////////////////////////////
  // ADD ITEM
  //////////////////////////////////////////////////////////////

  Future<void> addInventoryItem(InventoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final token = await SecureStorageService.getToken();
    
    if (token == null || token.isEmpty || token == 'mock-token') {
      if (mounted) {
        SnackbarUtils.showWarning(context, "Warning: Not logged in. Cloud sync failed.");
      }
      return;
    }
    
    bool success = await ApiService.addFood(item, token);
    if (!success && mounted) {
      SnackbarUtils.showError(context, "Warning: Failed to sync item to cloud.");
    } else {
       _loadInventory(); // Refresh from DB to ensure IDs propagate
    }
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final token = await SecureStorageService.getToken();
    
    if (token == null || token.isEmpty || token == 'mock-token') {
      if (mounted) {
        SnackbarUtils.showWarning(context, "Warning: Not logged in. Update not synced.");
      }
      return;
    }
    
    bool success = await ApiService.updateFood(item, token);
    if (!success && mounted) {
      SnackbarUtils.showError(context, "Warning: Failed to sync update to cloud.");
    } else {
       _loadInventory(); // Refresh to get updated data
    }
  }

  //////////////////////////////////////////////////////////////
  // DELETE ITEM
  //////////////////////////////////////////////////////////////

  Future<void> deleteInventoryItem(int index) async {
    final customizer = Provider.of<FridgeCustomizationProvider>(context, listen: false);
    AudioService.playSuccess(index: customizer.inventorySaveSoundIndex, customPath: customizer.customInventorySaveSoundPath);
    
    final item = inventory[index];
    setState(() {
      inventory.removeAt(index);
    });

    if (item.id != null) {
       final prefs = await SharedPreferences.getInstance();
       final token = await SecureStorageService.getToken();
       if (token != null) {
          await ApiService.deleteFood(item.id!, token);
       }
    }
  }

  //////////////////////////////////////////////////////////////
  // EDIT ITEM
  //////////////////////////////////////////////////////////////

  void editInventoryItem(int index, InventoryItem oldItem) {
    setState(() {
      _editItemIndex = index;
      _scannedItem = oldItem;
      _addFlowState = AddFlowState.manual;
      selectedTab = 3;
    });
  }

  //////////////////////////////////////////////////////////////
  // UI
  //////////////////////////////////////////////////////////////

  Widget _buildAddInventoryFlow() {
    switch (_addFlowState) {
      case AddFlowState.choice:
        return AddInventoryChoiceScreen(
          onPackaged: () => setState(() => _addFlowState = AddFlowState.scanner),
          onNonPackaged: () => setState(() {
            _scannedItem = null;
            _addFlowState = AddFlowState.manual;
          }),
          onBack: () => setState(() => selectedTab = 2),
        );
      case AddFlowState.scanner:
        return BarcodeScannerScreen(
          onSave: (item) {
            setState(() {
              _scannedItem = item;
              _addFlowState = AddFlowState.manual;
            });
          },
          onBack: () => setState(() => _addFlowState = AddFlowState.choice),
        );
      case AddFlowState.manual:
        return AddInventoryScreen(
          existingItem: _editItemIndex != null ? _scannedItem : null,
          initialItem: _editItemIndex == null ? _scannedItem : null,
          onSave: (item) {
            if (_editItemIndex != null) {
              updateInventoryItem(item);
            } else {
              addInventoryItem(item);
            }
            setState(() {
              _editItemIndex = null;
              _scannedItem = null;
              selectedTab = 2; // Return to inventory list
            });
            _loadInventory(); // Refresh list
          },
          onBack: () {
            if (_editItemIndex != null) {
              setState(() => selectedTab = 2);
            } else {
              setState(() => _addFlowState = AddFlowState.choice);
            }
          },
        );
    }
  }

  Widget _buildVerticalInventoryList() {
    if (_isInventoryLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.5.seconds, color: Colors.tealAccent.withOpacity(0.1)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      itemCount: inventory.length,
      itemBuilder: (context, index) {
        final item = inventory[index];
        final daysLeft = item.expiryDate.difference(DateTime.now()).inDays;
        
        Color statusColor = Colors.greenAccent;
        if (daysLeft < 0) statusColor = Colors.redAccent;
        else if (daysLeft <= 2) statusColor = Colors.orangeAccent;

        return GestureDetector(
          onTap: () => _showProductDetails(item),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Item Image/Icon
                  Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade700,
                          borderRadius: BorderRadius.circular(8),
                          image: _buildItemImage(item),
                        ),
                        child: _hasNoImage(item)
                            ? const Icon(Icons.fastfood, color: Colors.white70, size: 30)
                            : null,
                      ),
                      if (item.expiryDate.isBefore(DateTime.now()))
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: const Text(
                              "EXPIRED",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(width: 12),
                // Item Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quantity: ${item.quantity}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LiquidFreshnessBar(
                        value: daysLeft > 0 ? (daysLeft / 14.0).clamp(0.0, 1.0) : 0.0,
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => editInventoryItem(index, item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => deleteInventoryItem(index),
                    ),
                  ],
                ),
              ],
            ),
          ).animate(delay: (index * 50).ms).fadeIn(duration: 400.ms).slideX(begin: 0.1, curve: Curves.easeOutQuad),
        );
      },
    );
  }

  DecorationImage? _buildItemImage(InventoryItem item) {
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      final file = File(item.imagePath!);
      if (file.existsSync()) {
        return DecorationImage(image: FileImage(file), fit: BoxFit.cover);
      }
    }
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover);
    }
    return null;
  }

  bool _hasNoImage(InventoryItem item) {
    bool localExists = false;
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      localExists = File(item.imagePath!).existsSync();
    }
    return (item.imageUrl == null || item.imageUrl!.isEmpty) && !localExists;
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    final isDark = themeType == ThemeType.dark;

    ImageProvider? profileImageProvider;
    if (profileImage != null) {
      profileImageProvider = FileImage(profileImage!);
    } else if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      profileImageProvider = NetworkImage(profileImageUrl!);
    }

    return PopScope(
      canPop: selectedTab == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;

        if (selectedTab == 3) {
          if (_addFlowState == AddFlowState.manual) {
            if (_editItemIndex != null) {
              setState(() => selectedTab = 2);
            } else {
              setState(() => _addFlowState = AddFlowState.choice);
            }
          } else if (_addFlowState == AddFlowState.scanner) {
            setState(() => _addFlowState = AddFlowState.choice);
          } else if (_addFlowState == AddFlowState.choice) {
            setState(() => selectedTab = 2);
          }
        } else if (selectedTab == 7 || selectedTab == 8 || selectedTab == 9) {
          setState(() => selectedTab = 5);
        } else if (selectedTab == 6) {
          setState(() => selectedTab = 1);
        } else {
          setState(() => selectedTab = 0);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false, // 🛠️ Prevents dock shifting when keyboard opens
      backgroundColor: isLight ? const Color(0xFFF3F6F8) : (isDark ? Colors.black : const Color(0xFF050B12)),

      ////////////////////////////////////////////////////////////
      // 🔹 DRAWER (HAMBURGER MENU)
      ////////////////////////////////////////////////////////////

      drawer: RepaintBoundary(
        child: Drawer(
          backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isLight ? Colors.white.withOpacity(0.95) : (isDark ? Colors.grey.shade900.withOpacity(0.95) : null),
            gradient: (isLight || isDark) ? null : LinearGradient(
              colors: [const Color(0xFF050B12).withOpacity(0.95), const Color(0xFF0D2137).withOpacity(0.95)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)
            ],
          ),
          child: Column(
            children: [

              const SizedBox(height: 40),
              
              Text(
                "SMRIDGE",
                style: GoogleFonts.orbitron(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isLight ? const Color(0xFF007A7A) : Colors.white, // 🔥 Brand color in drawer
                  letterSpacing: 4.0,
                ),
              ),

              const SizedBox(height: 20),

              //////////////////////////////////////////////////////
              // PROFILE SECTION
              //////////////////////////////////////////////////////

              GestureDetector(
                onTap: editProfileDialog,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.tealAccent.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blueGrey,
                        backgroundImage: profileImageProvider,
                        child: profileImageProvider == null 
                          ? const Icon(Icons.person, size: 50, color: Colors.white) 
                          : null,
                      ),
                    ),
                    const SizedBox(height: 15),

                    Text(userName, style: TextStyle(color: isLight ? Colors.black87 : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(userEmail, style: TextStyle(color: isLight ? Colors.black54 : Colors.white70)),
                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: Icon(Icons.camera_alt, color: isLight ? Colors.black87 : Colors.white), onPressed: () => pickImage(ImageSource.camera)),
                        IconButton(icon: Icon(Icons.photo, color: isLight ? Colors.black87 : Colors.white), onPressed: () => pickImage(ImageSource.gallery)),
                      ],
                    ),
                  ],
                ),
              ),

              Divider(color: isLight ? Colors.black12 : Colors.white24, thickness: 1, indent: 20, endIndent: 20),
              const SizedBox(height: 10),

              //////////////////////////////////////////////////////
              // EXTRA OPTIONS
              //////////////////////////////////////////////////////

              ListTile(
                leading: Icon(Icons.notifications, color: isLight ? Colors.teal : Colors.tealAccent),
                title: Text("Notifications", style: TextStyle(color: isLight ? Colors.black87 : Colors.white, fontSize: 16)),
                trailing: unreadNotifications > 0 ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)
                    ],
                  ),
                  child: Text(
                    unreadNotifications > 99 ? "99+" : unreadNotifications.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ) : null,
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  setState(() => selectedTab = 4);
                },
              ),

              ListTile(
                leading: Icon(Icons.palette_outlined, color: isLight ? Colors.deepPurple : Colors.purpleAccent),
                title: Text("App Theme", style: TextStyle(color: isLight ? Colors.black87 : Colors.white, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()));
                },
              ),

              ListTile(
                leading: Icon(Icons.settings, color: isLight ? Colors.teal : Colors.tealAccent),
                title: Text("Settings", style: TextStyle(color: isLight ? Colors.black87 : Colors.white, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  setState(() => selectedTab = 5);
                },
              ),

              ListTile(
                leading: Icon(Icons.info_outline, color: isLight ? Colors.teal : Colors.tealAccent),
                title: Text("About Smridge", style: TextStyle(color: isLight ? Colors.black87 : Colors.white, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                },
              ),

              const Spacer(),
              Divider(color: isLight ? Colors.black12 : Colors.white24, thickness: 1, indent: 20, endIndent: 20),

              ListTile(
                leading: Icon(Icons.logout, color: isLight ? Colors.red : Colors.redAccent),
                title: Text("Logout", style: TextStyle(color: isLight ? Colors.red : Colors.redAccent, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  _showLogoutDialog();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),

      // REMOVED: Replaced with draggable icon in body Stack
      floatingActionButton: null,

      ////////////////////////////////////////////////////////////
      // BODY
      ////////////////////////////////////////////////////////////

      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          if (_addFlowState != AddFlowState.scanner && !_showWalkthrough) {
            _swipeStartX = details.globalPosition.dx;
            _swipeDelta = 0;
          }
        },
        onHorizontalDragUpdate: (details) {
          if (_swipeStartX != null) {
            _swipeDelta += details.delta.dx;
          }
        },
        onHorizontalDragEnd: (details) {
          if (_swipeStartX == null) return;
          final velocity = details.primaryVelocity ?? 0;
          final totalDx = _swipeDelta;
          _swipeStartX = null;
          _swipeDelta = 0;

          const maxSwipeTab = 4;
          // Swipe RIGHT (go to lower tab)
          if ((totalDx > 40 || velocity > 200) && selectedTab > 0) {
            HapticService.light();
            setState(() {
              selectedTab = selectedTab - 1;
              if (selectedTab == 3) {
                _addFlowState = AddFlowState.choice;
                _scannedItem = null;
                _editItemIndex = null;
              }
            });
          } 
          // Swipe LEFT (go to higher tab)
          else if ((totalDx < -40 || velocity < -200) && selectedTab < maxSwipeTab) {
            HapticService.light();
            setState(() {
              selectedTab = selectedTab + 1;
              if (selectedTab == 3) {
                _addFlowState = AddFlowState.choice;
                _scannedItem = null;
                _editItemIndex = null;
              }
            });
          }
        },
        child: Stack(
          children: [

          //////////////////////////////////////////////////////////
          // BACKGROUND
          //////////////////////////////////////////////////////////

          Container(
            decoration: BoxDecoration(
              color: isLight ? null : Colors.black,
              gradient: isLight ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)], // Light Ice Blue theme
              ) : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                ],
              ),
            ),
          ),
          
          const Positioned.fill(child: RepaintBoundary(child: WaveBackground())),

          //////////////////////////////////////////////////////////
          // INDEXED STACK
          //////////////////////////////////////////////////////////

          Stack(
            children: [
              ClipRect(
                child: Offstage(
                  offstage: selectedTab > 2,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 100, bottom: 120),
                    child: Center(
                      child: Fridge3D(
                        key: _fridgeKey,
                        walkthroughKey: _wtFridgeKey, // 🎯
                        selectedTab: selectedTab <= 2 ? selectedTab : 0,
                        inventory: inventory,
                        onAddPressed: () {
                          setState(() {
                            selectedTab = 3;
                            _addFlowState = AddFlowState.choice;
                            _scannedItem = null;
                            _editItemIndex = null;
                          });
                        },
                        onDelete: deleteInventoryItem,
                        onEdit: editInventoryItem,
                        onItemTap: (item) {
                          _triggerAnalysisSync(item);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (selectedTab > 2)
                IndexedStack(
                  index: selectedTab - 3,
                  children: [
                    // 3: ADD INVENTORY FLOW
                    _buildAddInventoryFlow(),

                    // 4: NOTIFICATIONS
                    NotificationsScreen(onBack: () => setState(() => selectedTab = 0)),

                    // 5: SETTINGS
                    SettingsScreen(
                      onBack: () => setState(() => selectedTab = 0),
                      onProfileTap: () => setState(() => selectedTab = 7),
                      onHelpTap: () => setState(() => selectedTab = 8),
                      onPrivacyTap: () => setState(() => selectedTab = 9),
                      onActivityTap: () => setState(() => selectedTab = 10),
                    ),

                    // 6: ANALYTICS
                    AnalyticsScreen(onBack: () => setState(() => selectedTab = 1)),

                    // 7: PROFILE
                    AccountProfileScreen(onBack: () {
                      _fetchProfile(); // Re-fetch to update side panel
                      setState(() => selectedTab = 5);
                    }),
                    
                    // 8: HELP & SUPPORT
                    HelpSupportScreen(onBack: () => setState(() => selectedTab = 5)),

                    // 9: PRIVACY POLICY
                    PrivacyPolicyScreen(onBack: () => setState(() => selectedTab = 5)),

                    // 10: ACTIVITY
                    ActivityScreen(onBack: () => setState(() => selectedTab = 5)),
                  ],
                ),
            ],
          ),
          
          //////////////////////////////////////////////////////////
          // FLOATING NAVBAR (GLASSMORPHIC)
          //////////////////////////////////////////////////////////

          if (selectedTab <= 2)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              right: 20,
              child: CreativeNavbar(
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                walkthroughKey: _wtNotificationKey,
                notificationCount: unreadNotifications,
              ).animate().slideY(begin: -1, duration: 800.ms, curve: Curves.easeOutQuart).fadeIn(),
            ),


          //////////////////////////////////////////////////////////
          // BOTTOM DOCK
          //////////////////////////////////////////////////////////

          // Dock shows on tabs 0-10. Hide only during scanner or when keyboard is open.
          if (selectedTab <= 10 &&
              _addFlowState != AddFlowState.scanner &&
              MediaQuery.of(context).viewInsets.bottom == 0)
            Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 10,
            left: 20,
            right: 20,
            child: AnimatedBottomDock(
              currentIndex: selectedTab,
              notificationCount: unreadNotifications, 
              itemKeys: [_wtDockFridgeKey, _wtDockStatusKey, _wtDockInventoryKey, _wtDockAddKey, _wtDockNotificationKey, _wtDockSettingsKey],
              onTap: (index) async {
                HapticService.medium(); // 🚀 High-Fidelity Navigation Snap
                
                // 🔄 Reset Add flow if navigating to any other tab
                if (index != 3) {
                  setState(() {
                    _addFlowState = AddFlowState.choice;
                    _scannedItem = null;
                    _editItemIndex = null;
                  });
                }

                if (index == 3) {
                  setState(() {
                    _editItemIndex = null;
                    _scannedItem = null;
                    _addFlowState = AddFlowState.choice;
                    selectedTab = 3;
                  });
                  return;
                }

                if (index == 4) {
                   setState(() => selectedTab = 5); // Dock 4 -> Settings
                   return;
                }

                if (selectedTab == 2 && index == 2) {
                  final state = _fridgeKey.currentState;
                  if (state != null) {
                    state.doorController.forward();
                  }
                }
                
                setState(() => selectedTab = index);
                // 🎯 Trigger Tab-Specific Walkthrough
                _triggerTabWalkthrough(index);
              },
              onDoubleTap: (index) async {
                if (index == 1) { 
                  setState(() {
                    selectedTab = 6; // Double tap status -> Analytics
                  });
                } else if (index == 2) {
                  // 🚀 Double tap Inventory → Navigate to Detailed Screen!
                  final result = await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => InventoryListScreen(
                      inventory: inventory, 
                      onDelete: deleteInventoryItem, 
                      onEdit: editInventoryItem,
                      onItemTap: (item) {
                         _triggerAnalysisSync(item);
                         _showProductDetails(item);
                      },
                    ))
                  );
                  if (result == "TRIGGER_ADD") {
                     setState(() {
                       _addFlowState = AddFlowState.choice;
                       selectedTab = 3;
                     });
                  }
                }
              },
            ).animate().slideY(begin: 1, duration: 800.ms, curve: Curves.easeOutQuart).fadeIn(),
          ),

          //////////////////////////////////////////////////////////
          // PRODUCT DETAILS OVERLAY
          //////////////////////////////////////////////////////////

          //////////////////////////////////////////////////////////
          // 🤖 MOVABLE AI CHAT ICON
          //////////////////////////////////////////////////////////
          if (_addFlowState != AddFlowState.scanner)
            Positioned(
              right: _chatIconPosition.dx,
              bottom: _chatIconPosition.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                setState(() {
                  double nextX = _chatIconPosition.dx - details.delta.dx;
                  double nextY = _chatIconPosition.dy - details.delta.dy;
                  
                  // Keep it on screen
                  final size = MediaQuery.of(context).size;
                  _chatIconPosition = Offset(
                    nextX.clamp(0, size.width - 60),
                    nextY.clamp(0, size.height - 100),
                  );
                });
              },
              child: FloatingActionButton(
                backgroundColor: isLight ? const Color(0xFF007A7A) : Colors.tealAccent, // 🔥 Improved light mode contrast
                elevation: 12,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: ChatAssistantOverlay(
                        onClose: () => Navigator.pop(context),
                        onActionTriggered: (action, value) {
                          if (action == "ADD_ITEM" || action == "ADD_ITEM_AI") {
                            if (value != null && value.startsWith("{")) {
                              try {
                                final details = jsonDecode(value);
                                final newItem = InventoryItem(
                                  name: details['name'] ?? "Unknown",
                                  category: details['category'] ?? "Others",
                                  quantity: (details['qty'] ?? 1).toInt(),
                                  weight: 0.0,
                                  expiryDate: DateTime.now().add(Duration(days: (details['expiryDays'] ?? 7).toInt())),
                                  dateAdded: DateTime.now(),
                                  imageUrl: details['imageUrl'],
                                  expirySource: "AI",
                                );
                                addInventoryItem(newItem).then((_) {
                                  _loadInventory();
                                  _fetchNotificationsCount();
                                });
                                SnackbarUtils.showSuccess(context, "Added ${newItem.quantity} ${newItem.name} via AI.");
                              } catch (e) {
                                SnackbarUtils.showError(context, "AI Add failed: $e");
                              }
                            } else {
                              _addFood(); // Fallback to manual
                            }
                          } else if (action == "EDIT_ITEM") {
                            try {
                              final details = jsonDecode(value ?? "{}");
                              final itemName = details['name'] ?? value ?? "";
                              final index = inventory.indexWhere((i) => i.name.toLowerCase() == itemName.toLowerCase());
                              
                              if (index != -1) {
                                // 🔹 Direct Edit Check: If AI provides specific fields (qty, category), update directly
                                if (details.containsKey('qty') || details.containsKey('category') || details.containsKey('expiryDays')) {
                                  final oldItem = inventory[index];
                                  final updatedItem = InventoryItem(
                                    id: oldItem.id,
                                    name: details['name'] ?? oldItem.name,
                                    category: details['category'] ?? oldItem.category,
                                    quantity: (details['qty'] ?? oldItem.quantity).toInt(),
                                    weight: oldItem.weight,
                                    expiryDate: details.containsKey('expiryDays') 
                                      ? DateTime.now().add(Duration(days: (details['expiryDays'] as num).toInt()))
                                      : oldItem.expiryDate,
                                    dateAdded: oldItem.dateAdded,
                                    imageUrl: oldItem.imageUrl,
                                    imagePath: oldItem.imagePath,
                                    notes: oldItem.notes, // 🚀 PRESERVE USER NOTES
                                    expirySource: "AI",
                                  );
                                  updateInventoryItem(updatedItem).then((_) => _loadInventory()); 
                                  SnackbarUtils.showSuccess(context, "Updated '$itemName' via AI Assistant.");
                                } else {
                                  // Fallback: Open manual edit screen
                                  editInventoryItem(index, inventory[index]);
                                }
                              } else {
                                SnackbarUtils.showError(context, "Could not find '$itemName' in your fridge to edit.");
                              }
                            } catch (e) {
                              // Fallback if not JSON
                              final index = inventory.indexWhere((i) => i.name.toLowerCase() == (value ?? "").toLowerCase());
                              if (index != -1) editInventoryItem(index, inventory[index]);
                            }
                          } else if (action == "DELETE_ITEM") {
                            try {
                              final details = jsonDecode(value ?? "{}");
                              final itemName = details['name'] ?? value ?? "";
                              final index = inventory.indexWhere((i) => i.name.toLowerCase() == itemName.toLowerCase());
                              if (index != -1) {
                                deleteInventoryItem(index);
                                SnackbarUtils.showSuccess(context, "'$itemName' discarded via AI Assistant.");
                                _loadInventory(); // Ensure real-time refresh
                              } else {
                                SnackbarUtils.showError(context, "Could not find '$itemName' in your fridge to discard.");
                              }
                            } catch (e) {
                                // Fallback
                                final index = inventory.indexWhere((i) => i.name.toLowerCase() == (value ?? "").toLowerCase());
                                if (index != -1) deleteInventoryItem(index);
                            }
                          } else if (action == "OPEN_SCREEN") {
                            String screen = "";
                            try {
                               final details = jsonDecode(value ?? "{}");
                               screen = details['screen'] ?? value ?? "";
                            } catch (e) {
                               screen = value ?? "";
                            }
                            
                            if (screen.isNotEmpty) {
                               _loadInventory();
                               _fetchNotificationsCount();
                               if (screen == "Analytics") setState(() => selectedTab = 6);
                               if (screen == "Settings") setState(() => selectedTab = 5);
                               if (screen == "Inventory") setState(() => selectedTab = 2);
                               if (screen == "Profile") setState(() => selectedTab = 7);
                               if (screen == "Notifications") setState(() => selectedTab = 4);
                               if (screen == "Recipes") setState(() => selectedTab = 3);
                            }
                          } else if (action == "CUSTOMIZE") {
                            try {
                              final details = jsonDecode(value ?? "{}");
                              final customizer = Provider.of<FridgeCustomizationProvider>(context, listen: false);
                              final type = details['type'];
                              final val = details['value'];

                              if (type == "exterior_color" && val != null) {
                                final color = Color(int.parse(val.replaceAll('#', '0xFF')));
                                customizer.setExteriorColor(color);
                                SnackbarUtils.showSuccess(context, "Fridge exterior color updated.");
                              } else if (type == "interior_color" && val != null) {
                                final color = Color(int.parse(val.replaceAll('#', '0xFF')));
                                customizer.setInteriorColor(color);
                                SnackbarUtils.showSuccess(context, "Fridge interior color updated.");
                              } else if (type == "reset") {
                                customizer.resetToDefault();
                                SnackbarUtils.showSuccess(context, "Fridge customization reset to defaults.");
                              }
                            } catch (e) {
                              SnackbarUtils.showError(context, "Customization failed: $e");
                            }
                          } else if (action == "SET_SOUND") {
                            try {
                              final details = jsonDecode(value ?? "{}");
                              final customizer = Provider.of<FridgeCustomizationProvider>(context, listen: false);
                              final category = details['category'];
                              final index = (details['index'] ?? 0).toInt();

                              if (category == "fridge_hum") customizer.setVibratingSound(index);
                              if (category == "door_open") customizer.setDoorSound(index);
                              if (category == "notification") customizer.setNotificationSound(index);
                              if (category == "expiry") customizer.setExpiryNotificationSound(index);
                              if (category == "success") customizer.setInventorySaveSound(index);
                              
                              SnackbarUtils.showSuccess(context, "Sound settings updated for $category.");
                            } catch (e) {
                              SnackbarUtils.showError(context, "Sound update failed: $e");
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
                child: Icon(Icons.smart_toy, color: isLight ? Colors.white : Colors.black), // 🔥 White icon on dark teal in light mode
              ),
            ).animate().scale(delay: 500.ms).fadeIn(),
          ),

          //////////////////////////////////////////////////////////
          // 🎯 WALKTHROUGH OVERLAY
          //////////////////////////////////////////////////////////
          if (_showWalkthrough && _currentWalkthroughSteps.isNotEmpty)
            AppWalkthrough(
              steps: _currentWalkthroughSteps,
              onFinish: () async {
                setState(() => _showWalkthrough = false);
              },
              onSkip: () async {
                setState(() => _showWalkthrough = false);
              },
            ),
        ],
      ),
    ),
    ),
    );
  }

  void _triggerTabWalkthrough(int index) async {
    final key = 'seen_walkthrough_tab_$index';
    final seen = await SecureStorageService.getString(key);
    if (seen == 'true') return;

    List<WalkthroughStep> steps = [];
    if (index == 0) {
      steps = [
        WalkthroughStep(
          targetKey: _wtFridgeKey,
          title: "Smridge Core",
          description: "Welcome to your Smridge command center. Interact with the 3D model to toggle doors, check slots, or rotate your perspective.",
        ),
        WalkthroughStep(
          targetKey: _wtNotificationKey,
          title: "Smart Alerts",
          description: "Keep track of unread notifications and system alerts here. We'll warn you about expiry or unusual temperature spikes.",
        ),
      ];
    } else if (index == 1) {
      steps = [
        WalkthroughStep(
          targetKey: _wtDockStatusKey,
          title: "Real-time Monitoring",
          description: "This precision panel displays live sensor data from your ESP32. Monitor temperature, humidity, and atmospheric freshness instantly.",
        ),
        WalkthroughStep(
          targetKey: _wtDockStatusKey,
          title: "System Insights",
          description: "Double-tap this status panel to enter detailed Analytics, where you can view historical data trends and door-opened logs.",
        ),
      ];
    } else if (index == 2) {
      steps = [
        WalkthroughStep(
          targetKey: _wtDockInventoryKey,
          title: "Smart Inventory",
          description: "Your fridge contents are mapped to these cards. Tap any slot to view detailed item analytics or edit its metadata.",
        ),
        WalkthroughStep(
          targetKey: _wtDockInventoryKey,
          title: "Door Control",
          description: "Tap the Inventory icon again while selected to remotely open or close the physical fridge door via your ESP32.",
        ),
        WalkthroughStep(
          targetKey: _wtDockInventoryKey,
          title: "Detailed View",
          description: "Double-tap this icon for the Master Inventory List—a full-screen table for high-volume item management and search.",
        ),
      ];
    } else if (index == 3) {
      steps = [
        WalkthroughStep(
          targetKey: _wtDockAddKey,
          title: "Expanding Your Kit",
          description: "Use this portal to add new items. You can leverage the AI Scanner for automatic recognition or use Manual Entry for custom logs.",
        ),
        WalkthroughStep(
          targetKey: _wtDockAddKey,
          title: "Automatic Tracking",
          description: "Once added, Smridge uses weight sensors to track activity patterns and predict expiry dates with clinical accuracy.",
        ),
      ];
    } else if (index == 5 || index == 4) { // Handling both internal and dock indices
      steps = [
        WalkthroughStep(
          targetKey: _wtDockSettingsKey,
          title: "Config & Customization",
          description: "Tailor your Smridge experience. Change visual themes, set security PINs, or calibrate your ESP32 sensor thresholds here.",
        ),
      ];
    }

    if (steps.isNotEmpty) {
      await SecureStorageService.saveString(key, 'true');
      setState(() {
        _currentWalkthroughSteps = steps;
        _showWalkthrough = true;
      });
    }
  }

  void _triggerAnalysisSync(InventoryItem item) async {
    if (mounted) {
      _showProductDetails(item);
    }
  }

  void _showProductDetails(InventoryItem item) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Details",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return ProductDetailsOverlay(
          item: item,
          onClose: () => Navigator.pop(context),
          onEdit: () {
            Navigator.pop(context);
            final idx = inventory.indexOf(item);
            if (idx != -1) editInventoryItem(idx, item);
          },
          onDelete: () {
            Navigator.pop(context);
            final idx = inventory.indexOf(item);
            if (idx != -1) deleteInventoryItem(idx);
          },
          onUpdate: (updated) {
            // 🔹 Refresh local state to reflect the new image immediately
            _loadInventory();
            _fetchNotificationsCount();
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Logout",
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2A33).withOpacity(0.95),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, spreadRadius: 10)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.logout, color: Colors.redAccent, size: 32),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "End Session?",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Are you sure you want to log out of Smridge? Your local inventory cache will be secured.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("CANCEL", style: TextStyle(color: Colors.white54, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 8,
                            shadowColor: Colors.redAccent.withOpacity(0.4),
                          ),
                          onPressed: () async {
                            HapticService.heavy();
                            await SecureStorageService.clearAll();
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(context, FadeSlidePageRoute(page: const LoginScreen()), (route) => false);
                            }
                          },
                          child: const Text("LOGOUT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack).fadeIn(),
          ),
        );
      },
    );
  }
}
