import 'dart:io';
import 'package:flutter/material.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum AddFlowState { choice, scanner, manual }

class _HomeScreenState extends State<HomeScreen> {

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<State<Fridge3D>> _fridgeKey = GlobalKey<State<Fridge3D>>();
  int selectedTab = 0;
  List<InventoryItem> inventory = [];

  //////////////////////////////////////////////////////////////
  // 🔹 INVENTORY ADD FLOW STATE
  //////////////////////////////////////////////////////////////

  AddFlowState _addFlowState = AddFlowState.choice;
  InventoryItem? _scannedItem;
  int? _editItemIndex;

  //////////////////////////////////////////////////////////////
  // 🔹 PROFILE DATA
  //////////////////////////////////////////////////////////////

  String userName = "Loading...";
  String userEmail = "Loading...";
  File? profileImage;

  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _loadInventory();
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

  void addInventoryItem(InventoryItem item) async {
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

  //////////////////////////////////////////////////////////////
  // DELETE ITEM
  //////////////////////////////////////////////////////////////

  void deleteInventoryItem(int index) async {
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
              setState(() {
                inventory[_editItemIndex!] = item;
              });
            } else {
              addInventoryItem(item);
            }
            setState(() => selectedTab = 2);
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    final isDark = themeType == ThemeType.dark;

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
                        backgroundImage: profileImage != null ? FileImage(profileImage!) : null,
                        child: profileImage == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
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
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(context, FadeSlidePageRoute(page: const LoginScreen()), (route) => false);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

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
                    AccountProfileScreen(onBack: () => setState(() => selectedTab = 5)),
                    
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
              onTap: (index) async {
                if (selectedTab == 2 && index == 2) {
                  // If already on inventory tab and tapped again, auto-open door
                  final state = _fridgeKey.currentState as dynamic;
                  if (state != null && state.doorController != null) {
                    state.doorController.forward();
                  }
                }
                
                setState(() {
                  selectedTab = index;
                });
              },
              onDoubleTap: (index) {
                if (index == 1) { // Status Tab
                  setState(() {
                    selectedTab = 6; // Analytics Tab
                  });
                }
              },
            ),
          ),
        ],
      ),
    ),
    );
  }
}
