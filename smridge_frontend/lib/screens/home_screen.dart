import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inventory_item.dart';
import '../widgets/fridge_3d.dart';
import '../widgets/animated_bottom_dock.dart';
import '../widgets/creative_navbar.dart';
import '../core/page_transitions.dart';
import 'add_inventory_screen.dart';
import 'add_inventory_choice_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'analytics_screen.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/secure_storage_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/wave_background.dart';
import 'barcode_scanner_screen.dart';
import 'account_profile_screen.dart';
import 'privacy_policy_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/fridge_customization_provider.dart';
import 'help_support_screen.dart';
import 'theme_settings_screen.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/liquid_freshness_bar.dart'; // Added for completeness, though already used
import '../widgets/system_monitoring_indicators.dart'; // New import
import '../widgets/product_details_overlay.dart'; // New import
import '../widgets/chat_assistant_overlay.dart'; // New import
import '../services/socket_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum AddFlowState { choice, scanner, manual }

class _HomeScreenState extends State<HomeScreen> {

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<Fridge3DState> _fridgeKey = GlobalKey<Fridge3DState>();
  int selectedTab = 0;
  List<InventoryItem> inventory = [];

  //////////////////////////////////////////////////////////////
  // 🔹 INVENTORY ADD FLOW STATE
  //////////////////////////////////////////////////////////////

  AddFlowState _addFlowState = AddFlowState.choice;
  InventoryItem? _scannedItem;
  int? _editItemIndex;
  int unreadNotifications = 0; // 👈 New state

  //////////////////////////////////////////////////////////////
  // 🔹 PROFILE DATA
  //////////////////////////////////////////////////////////////

  int gasLevel = 15;
  double fridgeTemp = 3.5;
  String weatherTemp = "--";
  String weatherIcon = "01d";
  String timezone = "Loading...";
  InventoryItem? _selectedItemForDetails;
  bool _showChatbot = false; // Chatbot trigger

  String userName = "Loading...";
  String userEmail = "Loading...";
  String? profileImageUrl;
  File? profileImage;

  // 🔹 DRAGGABLE CHAT ICON STATE
  Offset _chatIconPosition = const Offset(20, 140); // Default position (bottom-right area)

  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    _fetchProfile();
    _loadInventory();
    _fetchNotificationsCount();
    _initSocket();
    _startSensorSync();
  }

  Timer? _sensorSyncTimer;
  void _startSensorSync() {
    _sensorSyncTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final data = _fridgeKey.currentState?.simulator.getData();
        if (data != null) {
          ApiService.pushSensorData(data.temp, data.humidity, data.freshness);
        }
      }
    });
  }

  @override
  void dispose() {
    _sensorSyncTimer?.cancel();
    SocketService.off('inventory_update');
    SocketService.off('sensor_data');
    SocketService.off('notification_update');
    super.dispose();
  }

  Future<void> _fetchNotificationsCount() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      final notifs = await ApiService.getNotifications(token);
      if (mounted) {
        setState(() {
          unreadNotifications = notifs.where((n) => n != null && n['isRead'] == false).length.toInt();
        });
      }
    }
  }

  void _initSocket() {
    SocketService.init();
    
    // Listen for inventory updates
    SocketService.on('inventory_update', (data) {
      print('📺 Socket Inventory Update Received: $data');
      _loadInventory(); // Re-fetch inventory when any change occurs
      
      if (data['action'] == 'add') {
        SnackbarUtils.showInfo(context, 'New item added to your fridge!');
      } else if (data['action'] == 'delete') {
        SnackbarUtils.showInfo(context, 'An item was removed from your fridge.');
      }
    });

    // Listen for real-time sensor data
    SocketService.on('sensor_data', (data) {
      if (mounted) {
        setState(() {
          gasLevel = (data['gasLevel'] as num).toInt();
          fridgeTemp = (data['temperature'] as num).toDouble();
          // You can update more metrics here if needed
        });
      }
    });

    // 🔹 Listen for notification updates to sync badge count
    SocketService.on('notification_update', (data) {
      print('🔔 Notification Update Received: $data');
      _fetchNotificationsCount();
    });
  }

  void _addFood() {
    setState(() {
      _editItemIndex = null;
      _scannedItem = null;
      _addFlowState = AddFlowState.choice;
      selectedTab = 3;
    });
  }

  Future<void> _loadInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token != null) {
      final items = await ApiService.getInventory(token);
      if (mounted) {
        setState(() {
          inventory = items;
        });
      }
    }
  }

  Future<void> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty && token != 'mock-token') {
      final profile = await ApiService.getProfile(token);
      if (profile != null && mounted) {
        setState(() {
          userName = profile['name'] ?? "Smridge User";
          userEmail = profile['email'] ?? "user@email.com";
          final rawImg = profile['profileImage'];
          if (rawImg != null && rawImg.isNotEmpty) {
            profileImageUrl = rawImg.startsWith('http') ? rawImg : "${ApiService.baseDomain}/uploads/$rawImg";
          } else {
            profileImageUrl = null;
          }
        });
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

  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        profileImage = File(pickedFile.path);
      });

      // --- IMMEDIATE CLOUD SYNC ---
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
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
                final token = prefs.getString('token');
                
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
    final token = prefs.getString('token'); 
    
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
    final token = prefs.getString('token'); 
    
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
       final token = prefs.getString('token');
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
          onTap: () {
            _triggerAnalysisSync(item);
          },
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
          ),
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
      backgroundColor: isLight ? const Color(0xFFF3F6F8) : (isDark ? Colors.black : const Color(0xFF0E1215)),

      ////////////////////////////////////////////////////////////
      // 🔹 DRAWER (HAMBURGER MENU)
      ////////////////////////////////////////////////////////////

      drawer: Drawer(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isLight ? Colors.white.withOpacity(0.95) : (isDark ? Colors.grey.shade900.withOpacity(0.95) : null),
            gradient: (isLight || isDark) ? null : LinearGradient(
              colors: [const Color(0xFF16222A).withOpacity(0.95), const Color(0xFF3A6073).withOpacity(0.95)],
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
                  color: isLight ? Colors.black87 : Colors.white,
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

              const Spacer(),
              Divider(color: isLight ? Colors.black12 : Colors.white24, thickness: 1, indent: 20, endIndent: 20),

              ListTile(
                leading: Icon(Icons.logout, color: isLight ? Colors.red : Colors.redAccent),
                title: Text("Logout", style: TextStyle(color: isLight ? Colors.red : Colors.redAccent, fontSize: 16)),
                onTap: () async {
                  await SecureStorageService.clearAll();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(context, FadeSlidePageRoute(page: const LoginScreen()), (route) => false);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      // REMOVED: Replaced with draggable icon in body Stack
      floatingActionButton: null,

      ////////////////////////////////////////////////////////////
      // BODY
      ////////////////////////////////////////////////////////////

      body: Stack(
        children: [

          //////////////////////////////////////////////////////////
          // BACKGROUND
          //////////////////////////////////////////////////////////

          Container(
            decoration: BoxDecoration(
              color: isLight ? const Color(0xFFF3F6F8) : (isDark ? Colors.black : null),
              gradient: (isLight || isDark) ? null : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                ],
              ),
            ),
          ),
          
          const Positioned.fill(child: WaveBackground()),

          //////////////////////////////////////////////////////////
          // INDEXED STACK
          //////////////////////////////////////////////////////////

          Stack(
            children: [
              Offstage(
                offstage: selectedTab > 2,
                child: Center(
                  child: Fridge3D(
                    key: _fridgeKey,
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
              ),
            ),

          //////////////////////////////////////////////////////////
          // BOTTOM DOCK
          //////////////////////////////////////////////////////////

          if (MediaQuery.of(context).viewInsets.bottom == 0)
            Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: AnimatedBottomDock(
              currentIndex: selectedTab,
              notificationCount: unreadNotifications, 
              onTap: (index) async {
                if (index == 3) {
                  setState(() {
                    _editItemIndex = null;
                    _scannedItem = null;
                    _addFlowState = AddFlowState.choice;
                    selectedTab = 3;
                  });
                  return;
                }

                if (selectedTab == 2 && index == 2) {
                  final state = _fridgeKey.currentState;
                  if (state != null) {
                    state.doorController.forward();
                  }
                }
                
                setState(() {
                  selectedTab = index;
                });
              },
              onDoubleTap: (index) {
                if (index == 1) { 
                  setState(() {
                    selectedTab = 6; 
                  });
                }
              },
            ),
          ),

          //////////////////////////////////////////////////////////
          // PRODUCT DETAILS OVERLAY
          //////////////////////////////////////////////////////////
          if (_selectedItemForDetails != null)
            Positioned.fill(
              child: ProductDetailsOverlay(
                item: _selectedItemForDetails!,
                onClose: () => setState(() => _selectedItemForDetails = null),
                onEdit: () {
                  final idx = inventory.indexOf(_selectedItemForDetails!);
                  setState(() => _selectedItemForDetails = null);
                  if (idx != -1) editInventoryItem(idx, inventory[idx]);
                },
                onDelete: () {
                  final idx = inventory.indexOf(_selectedItemForDetails!);
                  setState(() => _selectedItemForDetails = null);
                  if (idx != -1) deleteInventoryItem(idx);
                },
              ),
            ),

          //////////////////////////////////////////////////////////
          // 🤖 MOVABLE AI CHAT ICON
          //////////////////////////////////////////////////////////
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
                                    expirySource: "AI_EDIT",
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
                backgroundColor: Colors.tealAccent,
                child: const Icon(Icons.smart_toy, color: Colors.black),
              ),
            ).animate().scale(delay: 500.ms).fadeIn(),
          ),
        ],
      ),
      ),
    );
  }
  void _triggerAnalysisSync(InventoryItem item) async {
    // 🔹 Instant sync for "Elite intelligence" before opening overlay
    final data = _fridgeKey.currentState?.simulator.getData();
    if (data != null) {
       await ApiService.pushSensorData(data.temp, data.humidity, data.freshness);
    }
    if (mounted) {
      setState(() {
        _selectedItemForDetails = item;
      });
    }
  }
}
