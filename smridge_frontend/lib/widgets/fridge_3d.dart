import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'dart:ui'; // Added for ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/inventory_item.dart';
import 'status_metrics.dart';
import '../services/socket_service.dart';
import '../config/app_settings.dart';
import '../services/audio_service.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/fridge_customization_provider.dart';
import '../screens/inventory_list_screen.dart';

class Fridge3D extends StatefulWidget {
  final int selectedTab; // 0 home, 1 status, 2 inventory
  final List<InventoryItem> inventory;
  final VoidCallback onAddPressed;
  final Function(int) onDelete;
  final Function(int, InventoryItem) onEdit;
  final Function(InventoryItem)? onItemTap;
  final GlobalKey? walkthroughKey; // 🎯

  const Fridge3D({
    super.key,
    required this.selectedTab,
    required this.inventory,
    required this.onAddPressed,
    required this.onDelete,
    required this.onEdit,
    this.onItemTap,
    this.walkthroughKey, // 🎯
  });

  @override
  State<Fridge3D> createState() => Fridge3DState();
}

class Fridge3DState extends State<Fridge3D>
    with TickerProviderStateMixin {

  late AnimationController cameraController;
  late AnimationController doorController;

  bool showInventoryList = false;
  bool _isDoorOpenSensor = false;
  bool _isThresholdDanger = false;
  bool _isESP32Connected = false;
  bool _isUserInteracting = false; // 🛠️ Manual Override flag
  Timer? _interactionTimer;
  bool? _lastSensorState; // 🛡️ Hardware transition tracker
  int _prevInventoryCount = 0;
  bool _isTwinkling = false;
  double _panX = 0;
  double _panY = 0;
  bool _isDoorOpen = false; // Tracks logical door state to prevent audio loops

  int get rows => (max(9, widget.inventory.length + 1) / 3).ceil();

  @override
  void initState() {
    super.initState();
    _prevInventoryCount = widget.inventory.length;

    cameraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    doorController = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 2.6, // 🧊 Increased to 150 degrees for a very wide swing
      duration: const Duration(milliseconds: 600),
    );

    _initSocketListeners();
  }

  void _initSocketListeners() {
    SocketService.on('sensor_data', (data) {
      if (!mounted) return;

      // Safe parsing: backend may send values as String or num
      double temp   = double.tryParse(data['temperature']?.toString() ?? '4.0') ?? 4.0;
      double hum    = double.tryParse(data['humidity']?.toString() ?? '60.0') ?? 60.0;
      double fresh  = double.tryParse(data['calculatedFreshness']?.toString() ?? '85.0') ?? 85.0;
      bool door = data['doorStatus'] == 'open';

      bool tempDanger = temp > AppSettings.temperatureThreshold;
      bool humDanger = hum > AppSettings.humidityThreshold;
      bool freshDanger = fresh < AppSettings.freshnessThreshold;

      setState(() {
        _isDoorOpenSensor = door;
        _isThresholdDanger = tempDanger || humDanger || freshDanger;
        _isESP32Connected = data['isReal'] ?? false;
      });

      // 🚪 Sync 3D door with sensor state ONLY on hardware transitions
      // This allows manual opening/closing to stay put until the real door is touched
      if (_lastSensorState != null && _lastSensorState != _isDoorOpenSensor) {
        if (_isDoorOpenSensor && !_isDoorOpen) {
          _openDoor();
        } else if (!_isDoorOpenSensor && _isDoorOpen) {
          _closeDoor();
        }
      }
      _lastSensorState = _isDoorOpenSensor;
    });
  }

  @override
  void didUpdateWidget(covariant Fridge3D oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.inventory.length > _prevInventoryCount) {
      _isTwinkling = true;
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _isTwinkling = false);
      });
    }
    _prevInventoryCount = widget.inventory.length;

    // ✅ FIX: Only trigger camera animation when the tab actually changes
    if (oldWidget.selectedTab != widget.selectedTab) {
      cameraController.forward(from: 0);

      if (widget.selectedTab == 2) {
        _openDoor(); // Auto-open when 'Inventory' pressed
      } else if (oldWidget.selectedTab == 2 && !_isDoorOpenSensor) {
        _closeDoor(); // Auto-close when leaving 'Inventory', ONLY if sensor doesn't say it's open
      }
    }

    if (oldWidget.selectedTab != widget.selectedTab && widget.selectedTab != 2) {
      showInventoryList = false;
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    doorController.dispose();
    super.dispose();
  }

  // Opens the fridge door
  void _openDoor() {
    if (!_isDoorOpen) {
      final customizer = Provider.of<FridgeCustomizationProvider>(context, listen: false);
      setState(() => _isDoorOpen = true);
      AudioService.playDoorOpen(index: customizer.fridgeDoorSoundIndex, customPath: customizer.customDoorSoundPath);
      AudioService.playFridgeHum(index: customizer.fridgeVibratingSoundIndex, customPath: customizer.customVibratingSoundPath);
      doorController.forward();
    }
  }

  // Closes the fridge door
  void _closeDoor() {
    if (_isDoorOpen || doorController.value > 0.1) {
      final customizer = Provider.of<FridgeCustomizationProvider>(context, listen: false);
      setState(() => _isDoorOpen = false);
      AudioService.playDoorOpen(index: customizer.fridgeDoorSoundIndex, customPath: customizer.customDoorSoundPath);
      AudioService.stopFridgeHum();
      doorController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;

    bool zoomStatus = widget.selectedTab == 1; // STATUS
    bool zoomInventory = widget.selectedTab == 2; // INVENTORY

    return Stack(
      clipBehavior: Clip.none,
      children: [


        AnimatedBuilder(
          animation: Listenable.merge([cameraController, doorController]),
          builder: (_, __) {

            final t =
                Curves.easeInOutCubic.transform(cameraController.value);

            int totalSlots = max(9, widget.inventory.length + 1);
            int rows = (totalSlots / 3).ceil();
            double fridgeHeight = max(640.0, 340.0 + (rows * 105.0) + 40.0);
            double lowerDoorHeight = max(350.0, fridgeHeight - 290.0);

            Matrix4 transform = Matrix4.identity()
              ..setEntry(3, 2, 0.002); // 📐 Increased perspective depth

            // ✅ STATUS = cinematic downward zoom + tilt (Focus on Upper Fridge)
            if (zoomStatus) {
              transform
                ..translate(0.0, 320 * t) // Pushed down heavily to show TOP
                ..scale(1 + 0.55 * t);     // Very deep zoom for focus
            }

            // ✅ INVENTORY = cinematic upward zoom + tilt
            if (zoomInventory) {
              transform
                ..translate(0.0, -220 * t) // Pushed up slightly more
                ..scale(1 + 0.5 * t);       // Increased zoom for impact
            }
            
            // Allow manual pan hover within limits
            transform..rotateY(_panX)..rotateX(-_panY);

            return GestureDetector(
              onPanUpdate: (details) {
                if (zoomStatus || zoomInventory) {
                  setState(() {
                    _panX += details.delta.dx * 0.005;
                    _panY += details.delta.dy * 0.005;
                    _panX = _panX.clamp(-0.2, 0.2);
                    _panY = _panY.clamp(-0.2, 0.2);
                  });
                }
              },
              onPanEnd: (_) {
                setState(() {
                  _panX = 0;
                  _panY = 0;
                });
              },
              child: Transform(
                alignment: Alignment.center,
                transform: transform,
                child: SizedBox(
                  key: widget.walkthroughKey,
                  width: 340,
                  height: fridgeHeight,
                  child: GestureDetector(
                    onTap: () {
                      if (_isDoorOpen || doorController.value > 0.1) {
                        _closeDoor();
                      }
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_isDoorOpen || doorController.value > 0.1) {
                                _closeDoor();
                              }
                            },
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                        buildFridgeBody(),
                        buildShelves(),
                        buildLowerDoor(lowerDoorHeight),
                        buildStatusPanel(),
                        buildHinge(),
                        buildListButton(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        if (showInventoryList)
          buildInventoryList(isLight),
      ],
    );
  }

  //////////////////////////////////////////////////////////////
  // FRIDGE BODY WITH THRESHOLD REACTIVE GLOW
  //////////////////////////////////////////////////////////////

  Widget buildFridgeBody() {
    final customizationProvider = Provider.of<FridgeCustomizationProvider>(context);
    final extColor = customizationProvider.fridgeExteriorColor;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    bool danger = _isThresholdDanger || widget.inventory.any(
      (item) {
        final exp = DateTime(item.expiryDate.year, item.expiryDate.month, item.expiryDate.day);
        return exp.isBefore(today);
      }
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: extColor == const Color(0xFF2B4162)
              ? const [
                  Color(0xFF2B4162), // Metallic cool grey-blue
                  Color(0xFF101B2E), // Deep brushed metal
                  Color(0xFF0A111F), // Dark shadow
                ]
              : [
                  extColor, 
                  extColor.withOpacity(0.7), 
                  extColor.withOpacity(0.4), 
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: _isTwinkling
            ? [
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: Colors.tealAccent.withOpacity(0.8),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ]
            : danger
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 6,
                    )
                  ]
                : [],
      ),
    );
  }

  //////////////////////////////////////////////////////////////
  // STATUS PANEL
  //////////////////////////////////////////////////////////////

  Widget buildStatusPanel() {
    return const Positioned(
      top: 25, // Moved UP to stay within the 290px upper door limit
      left: 30,
      right: 30,
      child: StatusMetrics(),
    );
  }

  //////////////////////////////////////////////////////////////
  // UPPER DOOR
  //////////////////////////////////////////////////////////////

  Widget buildUpperDoor() {
    final customizationProvider = Provider.of<FridgeCustomizationProvider>(context);
    final intColor = customizationProvider.fridgeInteriorColor;

    return Positioned(
      top: 0,
      child: AnimatedBuilder(
        animation: doorController,
        builder: (_, __) {
          return Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(doorController.value), // 📐 Swings OUTWARD
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_isDoorOpen || doorController.value > 0.0) {
                  _closeDoor();
                } else {
                  _openDoor();
                }
              },
              child: Container(
                width: 340,
                height: 290,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: intColor.withOpacity(0.45),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      offset: const Offset(0, 10),
                      blurRadius: 15,
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  //////////////////////////////////////////////////////////////
  // LOWER DOOR (LEFT HINGE + MANUAL)
  //////////////////////////////////////////////////////////////

  Widget buildLowerDoor(double lowerDoorHeight) {
    final customizationProvider = Provider.of<FridgeCustomizationProvider>(context);
    final extColor = customizationProvider.fridgeExteriorColor;

    return Positioned(
      top: 290,
      child: AnimatedBuilder(
        animation: doorController,
        builder: (_, __) {
          return Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(doorController.value), // 📐 Unified OUTWARD swing
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_isDoorOpen || doorController.value > 0.0) {
                  _closeDoor();
                } else {
                  _openDoor();
                }
              },
              onHorizontalDragStart: (_) {
                setState(() => _isUserInteracting = true);
                _interactionTimer?.cancel();
              },
              onHorizontalDragUpdate: (details) {
                // 🛠️ Unify Drag (Positive Delta = Open Outwards)
                double delta = details.delta.dx / 80; 
                doorController.value = (doorController.value + delta).clamp(0.0, 2.6);
              },
              onHorizontalDragEnd: (details) {
                // 🛠️ snap threshold (15% of 2.6)
                if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                   _closeDoor();
                } else if (doorController.value > 2.6 * 0.15) {
                   _openDoor();
                } else {
                   _closeDoor();
                }
                
                // 🛠️ Keep override active for a moment to prevent "snap-back" from sensor
                _interactionTimer = Timer(const Duration(seconds: 3), () {
                  if (mounted) setState(() => _isUserInteracting = false);
                });
              },
              child: Container(
                width: 340,
                height: lowerDoorHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: extColor == const Color(0xFF2B4162)
                        ? const [
                            Color(0xFF334D6C), // Edge highlight
                            Color(0xFF1E314D), // Mid metal
                            Color(0xFF0C1929), // Shadow edge
                          ]
                        : [
                            extColor.withOpacity(0.8), // Edge highlight
                            extColor.withOpacity(0.5), // Mid metal
                            extColor.withOpacity(0.2), // Shadow edge
                          ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      offset: Offset(15, 0),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  //////////////////////////////////////////////////////////////
  // HINGE
  //////////////////////////////////////////////////////////////

  Widget buildHinge() {
    return Positioned(
      top: 330,
      left: 0,
      child: Container(
        width: 10,
        height: 120,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.grey, Colors.black87, Colors.grey],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: Colors.white38, width: 0.5),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(2, 0))
          ],
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////////
  // SHELVES
  //////////////////////////////////////////////////////////////

  Color _getFreshnessColor(InventoryItem item) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(item.expiryDate.year, item.expiryDate.month, item.expiryDate.day);
    
    if (exp.isBefore(today)) return Colors.redAccent;
    final diff = exp.difference(today).inDays;
    if (diff <= 3) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  Widget buildShelves() {
    final customizationProvider = Provider.of<FridgeCustomizationProvider>(context);
    int totalSlots = max(9, widget.inventory.length + 1);

    return Positioned(
      top: 340,
      left: 30,
      right: 30,
      bottom: 20,
      child: Column(
        children: List.generate(
            rows,
            (row) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.3), width: 3)),
                    color: customizationProvider.fridgeInteriorColor.withOpacity(0.25),
                    boxShadow: const [BoxShadow(color: Colors.white10, offset: Offset(0, -2), blurRadius: 2)],
                  ),
                  padding: const EdgeInsets.only(bottom: 5, top: 2),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: List.generate(3, (col) {
                      int index = row * 3 + col;

                      if (index >= totalSlots) {
                        return const SizedBox(width: 90, height: 90);
                      }

                      // 🎰 DOMINO SHIVER EFFECT
                      return buildSlot(index)
                        .animate(target: widget.selectedTab == 2 ? 1 : 0)
                        .shimmer(delay: (index * 50).ms, duration: 400.ms, color: Colors.white24)
                        .shake(delay: (index * 50).ms, hz: 4, curve: Curves.easeInOut);
                    }),
                  ),
                )),
      ),
    );
  }

  Widget buildSlot(int index) {

    if (index == widget.inventory.length) {
      return GestureDetector(
        onTap: widget.onAddPressed,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.add,
              color: Colors.white),
        ),
      );
    }

    if (index >= widget.inventory.length) {
      return Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.05),
        ),
      );
    }

    final item = widget.inventory[index];

    ImageProvider? imageProvider;
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      final file = File(item.imagePath!);
      if (file.existsSync()) {
        imageProvider = FileImage(file);
      }
    }
    
    if (imageProvider == null && item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(item.imageUrl!);
    }

    final freshnessColor = _getFreshnessColor(item);

    return GestureDetector(
      onTap: () {
        if (widget.onItemTap != null) {
          widget.onItemTap!(item);
        } else {
          showEditPanel(index);
        }
      },
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              image: imageProvider != null
                  ? DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
              color: imageProvider == null
                  ? Colors.white10
                  : null,
              border: Border.all(
                color: freshnessColor.withOpacity(0.8),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: freshnessColor.withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: imageProvider == null
                ? Icon(Icons.fastfood, color: freshnessColor.withOpacity(0.5))
                : null,
          ),
          if (item.expiryDate.isBefore(DateTime.now()))
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: const Text(
                  "EXPIRED",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  //////////////////////////////////////////////////////////////
  // LIST BUTTON
  //////////////////////////////////////////////////////////////

  Widget buildListButton() {
  return Positioned(
    top: 295,
    right: 10,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isDoorOpen)
          IconButton(
            icon: Icon(Icons.door_front_door,
                color: Colors.tealAccent.withOpacity(0.9), size: 28),
            tooltip: "Close Door",
            onPressed: _closeDoor,
          ),
        IconButton(
          icon: const Icon(Icons.view_list,
              color: Colors.white, size: 28),
          onPressed: () {
            setState(() {
              showInventoryList = true;
            });
          },
        ),
      ],
    ),
  );
}

  //////////////////////////////////////////////////////////////
  // INVENTORY LIST
  //////////////////////////////////////////////////////////////

  Widget buildInventoryList(bool isLight) {
    Color textColor = isLight ? Colors.black87 : Colors.white;

    return Positioned.fill(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: isLight ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.4),
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // GLASS HEADER
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: isLight ? Colors.white : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.15)),
                    boxShadow: [if (isLight) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Inventory List",
                        style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.fullscreen, color: textColor),
                            tooltip: "Full Screen View",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InventoryListScreen(
                                    inventory: widget.inventory,
                                    onDelete: widget.onDelete,
                                    onEdit: widget.onEdit,
                                    onItemTap: widget.onItemTap,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: textColor),
                            onPressed: () => setState(() => showInventoryList = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 15),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: widget.inventory.length,
                    itemBuilder: (_, index) {
                      final item = widget.inventory[index];

                      return Dismissible(
                        key: ValueKey(item.name + index.toString()),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => widget.onDelete(index),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isLight ? Colors.white : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getFreshnessColor(item).withOpacity(0.4),
                              width: 1.2,
                            ),
                            boxShadow: [
                              if (isLight) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                              BoxShadow(
                                color: _getFreshnessColor(item).withOpacity(0.1),
                                blurRadius: 6,
                              )
                            ]
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() => showInventoryList = false);
                              if (widget.onItemTap != null) {
                                widget.onItemTap!(item);
                              } else {
                                showEditPanel(index);
                              }
                            },
                            leading: _buildInventoryItemImage(item, isLight),
                            title: Text(item.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                "Qty: ${item.quantity}  •  Exp: ${item.expiryDate.toString().split(' ')[0]}",
                                style: TextStyle(color: isLight ? Colors.black54 : Colors.white70),
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.edit, color: isLight ? Colors.teal : Colors.tealAccent),
                              onPressed: () => widget.onEdit(index, item),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////////
  // EDIT PANEL
  //////////////////////////////////////////////////////////////

  void showEditPanel(int initialIndex) {
    int currentIndex = initialIndex;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final item = widget.inventory[currentIndex];

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Image & Arrows Header
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 300,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                image: item.imagePath != null
                                    ? DecorationImage(
                                        image: FileImage(File(item.imagePath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: item.imagePath == null
                                  ? const Center(
                                      child: Icon(Icons.fastfood, size: 80, color: Colors.white38),
                                    )
                                  : null,
                            ),
                            
                            // Left Arrow
                            if (currentIndex > 0)
                              Positioned(
                                left: 10,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30),
                                  onPressed: () => setStateDialog(() => currentIndex--),
                                ),
                              ),
                              
                            // Right Arrow
                            if (currentIndex < widget.inventory.length - 1)
                              Positioned(
                                right: 10,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 30),
                                  onPressed: () => setStateDialog(() => currentIndex++),
                                ),
                              ),

                            // Close Button
                            Positioned(
                              top: 10,
                              right: 10,
                              child: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.white, size: 30),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                        
                        // Details Section
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                              if (item.brand != null && item.brand!.isNotEmpty)
                                Text(item.brand!, style: const TextStyle(color: Colors.tealAccent, fontSize: 16)),
                              
                              const SizedBox(height: 10),
                              Divider(color: Colors.white.withOpacity(0.2)),
                              const SizedBox(height: 10),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Category:", style: TextStyle(color: Colors.white70, fontSize: 16)),
                                  Text(item.category ?? "Others", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Quantity:", style: TextStyle(color: Colors.white70, fontSize: 16)),
                                  Text("${item.quantity}", style: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (item.weight != null && item.weight! > 0) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Weight:", style: TextStyle(color: Colors.white70, fontSize: 16)),
                                    Text("${item.weight!.toStringAsFixed(3)} kg", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (item.litres != null && item.litres! > 0) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Volume:", style: TextStyle(color: Colors.white70, fontSize: 16)),
                                    Text("${item.litres} L", style: const TextStyle(color: Colors.cyan, fontSize: 16, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Expiration:", style: TextStyle(color: Colors.white70, fontSize: 16)),
                                  Text(item.expiryDate.toString().split(' ')[0], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              
                              if (item.notes != null && item.notes!.isNotEmpty) ...[
                                const SizedBox(height: 15),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text("Notes: ${item.notes}", style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                                ),
                              ],
                              
                              const SizedBox(height: 30),
                              
                              // Actions
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.tealAccent),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        widget.onEdit(currentIndex, item);
                                      },
                                      child: const Text("Edit Item", style: TextStyle(color: Colors.tealAccent, fontSize: 16)),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        widget.onDelete(currentIndex);
                                      },
                                      child: const Text("Discard", style: TextStyle(color: Colors.white, fontSize: 16)),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInventoryItemImage(InventoryItem item, bool isLight) {
    ImageProvider? provider;
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      final file = File(item.imagePath!);
      if (file.existsSync()) provider = FileImage(file);
    }
    if (provider == null && item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      provider = NetworkImage(item.imageUrl!);
    }

    if (provider != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image(
          image: provider,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        ),
      );
    }

    final freshnessColor = _getFreshnessColor(item);

    return Stack(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: freshnessColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: freshnessColor.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: freshnessColor.withOpacity(0.2), blurRadius: 4, spreadRadius: 1)
            ],
          ),
          child: Icon(Icons.inventory, color: freshnessColor, size: 24),
        ),
        if (item.expiryDate.isBefore(DateTime.now()))
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: const Text(
                "EXP",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
