import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/inventory_item.dart';
import '../widgets/wave_background.dart';
import '../utils/category_helper.dart';
import 'package:intl/intl.dart';
import '../utils/snackbar_utils.dart';
import '../utils/expiry_estimator.dart';
import '../services/audio_service.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/fridge_customization_provider.dart';
import '../services/socket_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/app_walkthrough.dart'; // 🎯

class AddInventoryScreen extends StatefulWidget {
  final Function(InventoryItem)? onSave;
  final InventoryItem? existingItem;
  final InventoryItem? initialItem;
  final VoidCallback? onBack;
  final double? initialWeight; // 🆕 Added for deep linking

  const AddInventoryScreen({
    super.key,
    this.onSave,
    this.existingItem,
    this.initialItem,
    this.initialWeight,
    this.onBack,
  });

  @override
  State<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends State<AddInventoryScreen> {
  final nameController = TextEditingController();
  final brandController = TextEditingController();
  final categoryController = TextEditingController();
  final quantityController = TextEditingController();
  final weightController = TextEditingController();
  final litresController = TextEditingController();
  final notesController = TextEditingController();

  DateTime? selectedDate;
  DateTime? selectedReminderDate; 
  String? imagePath;
  String? imageUrl;
  bool isPackaged = false;
  bool isLiquid = false;
  String? barcode;
  String? expirySource;
  final ImagePicker picker = ImagePicker();
  
  bool _isFetchingAiImage = false;
  String? _aiSuggestedImageUrl;
  String? _originalLocalImagePath; 

  static const List<String> categoryOptions = [
    'Dairy', 'Fruits', 'Vegetables', 'Meat', 'Seafood', 'Beverages',
    'Snacks', 'Condiments', 'Bakery', 'Frozen', 'Leftovers', 'Others',
  ];

  static const Set<String> liquidCategories = {
    'Beverages', 'Dairy', 'Condiments',
  };

  static const Set<String> liquidKeywords = {
    'milk', 'juice', 'water', 'soda', 'cola', 'yogurt', 'yoghurt',
    'drink', 'sauce', 'oil', 'vinegar', 'cream', 'syrup', 'soup',
    'broth', 'smoothie', 'shake', 'tea', 'coffee', 'lemonade',
    'curd', 'buttermilk', 'lassi', 'beer', 'wine',
  };

  double currentWeight = 0.0;
  Timer? _weightSimulationTimer;
  
  Timer? _aiDebounceTimer;
  bool _isAiDetecting = false;

  // 🎯 Walkthrough Goals
  final GlobalKey _wtNameKey = GlobalKey();
  final GlobalKey _wtCategoryKey = GlobalKey();
  final GlobalKey _wtWeightKey = GlobalKey();
  final GlobalKey _wtExpiryKey = GlobalKey();
  final GlobalKey _wtSaveKey = GlobalKey();
  
  bool _showWalkthrough = false;
  List<WalkthroughStep> _currentSteps = [];

  @override
  void initState() {
    super.initState();
    _checkFirstVisit();

    final item = widget.existingItem ?? widget.initialItem;

    if (widget.initialWeight != null) {
      double rawWeight = widget.initialWeight!;
      if (rawWeight > 100) rawWeight = rawWeight / 1000; // Convert to KG
      weightController.text = rawWeight.toStringAsFixed(3);
      currentWeight = rawWeight;
      SnackbarUtils.showInfo(context, "Weight data captured. Please enter details.");
    }

    if (item != null) {
      nameController.text = item.name;
      brandController.text = item.brand ?? "";
      categoryController.text = item.category ?? "";
      quantityController.text = item.quantity.toString();

      double rawWeight = item.weight ?? 0.0;
      if (rawWeight > 100) rawWeight = rawWeight / 1000;
      weightController.text = rawWeight.toStringAsFixed(3);
      currentWeight = rawWeight;

      _checkLiquid(item.name, item.category);
      if (item.litres != null && item.litres! > 0) {
        litresController.text = item.litres.toString();
      }

      notesController.text = item.notes ?? "";
      selectedDate = item.expiryDate;
      imagePath = item.imagePath;
      imageUrl = item.imageUrl;
      isPackaged = item.isPackaged;
      barcode = item.barcode;
      expirySource = item.expirySource;
    } else {
      nameController.text = "";
      brandController.text = "";
      categoryController.text = "";
      quantityController.text = "1";
      weightController.text = "0.0";
      litresController.text = "";
      notesController.text = "";
      imagePath = null;
      imageUrl = null;
      barcode = null;
      expirySource = null;
      selectedDate = DateTime.now().add(const Duration(days: 7));
      _startLoadCellSimulation();
    }

    nameController.addListener(_onNameChanged);
  }

  Future<void> _checkFirstVisit() async {
    final visited = await SecureStorageService.getString('visited_manual_entry');
    if (visited == null && widget.existingItem == null) {
      _triggerWalkthrough();
    }
  }

  void _triggerWalkthrough() {
    setState(() {
      _currentSteps = [
        WalkthroughStep(
          targetKey: _wtNameKey,
          title: "Intelligent Naming",
          description: "Start typing an item name. Our AI will predict the category and estimate a safe expiry date based on thousands of food types.",
        ),
        WalkthroughStep(
          targetKey: _wtCategoryKey,
          title: "Precise Categorization",
          description: "Categories help Smridge apply specific freshness algorithms. For example, dairy items have stricter temp-stability requirements.",
        ),
        WalkthroughStep(
          targetKey: _wtExpiryKey,
          title: "Dynamic Expiry",
          description: "Adjust the expiry date manually or trust our AI-suggested estimates. You'll get a notification 48 hours before this date.",
        ),
        WalkthroughStep(
          targetKey: _wtSaveKey,
          title: "Cloud Sync",
          description: "Save your item to sync it with the 3D fridge view and all connected mobile devices.",
        ),
      ];
      _showWalkthrough = true;
    });
    SecureStorageService.saveString('visited_manual_entry', 'true');
  }

  Future<void> _pickDateTime({required bool isExpiry}) async {
    DateTime initial = (isExpiry ? selectedDate : selectedReminderDate) ?? DateTime.now();
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );

      if (pickedTime != null) {
        setState(() {
          final fullDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isExpiry) {
            selectedDate = fullDateTime;
            expirySource = "manual";
          } else {
            selectedReminderDate = fullDateTime;
          }
        });
      }
    }
  }

  void _onNameChanged() {
    _checkLiquid(nameController.text, categoryController.text);
    if (_aiDebounceTimer?.isActive ?? false) _aiDebounceTimer!.cancel();
    final text = nameController.text.trim();
    if (text.isEmpty) return;
    _aiDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _fetchAiPredictions(text);
    });
  }

  Future<void> _fetchAiPredictions(String name) async {
    if (!mounted) return;
    setState(() => _isAiDetecting = true);

    try {
      final token = await SecureStorageService.getToken();
      if (token != null) {
        final prediction = await ApiService.autoDetectItemDetails(name, token);
        if (prediction != null && mounted) {
          setState(() {
            final aiCategory = prediction['category'];
            if (aiCategory != null && categoryOptions.contains(aiCategory)) {
               categoryController.text = aiCategory;
            }
            if (expirySource != "manual" && prediction['expiryDays'] != null) {
               final int days = (prediction['expiryDays'] as num).toInt();
               selectedDate = DateTime.now().add(Duration(days: days));
               expirySource = "estimated";
            }
          });
          _checkLiquid(nameController.text, categoryController.text);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isAiDetecting = false;
          // ⚖️ AI Weight Simulation (under 5kg)
          if (weightController.text == "0.0" || weightController.text.isEmpty) {
            final qty = int.tryParse(quantityController.text) ?? 1;
            final predicted = _estimateWeight(name, qty);
            if (predicted > 0) {
              weightController.text = predicted.toStringAsFixed(3);
              currentWeight = predicted;
            }
          }
        });
      }
    }
  }

  double _estimateWeight(String name, int quantity) {
    final n = name.toLowerCase();
    double unitWeight = 0.2; // default 200g
    if (n.contains('apple')) unitWeight = 0.18;
    else if (n.contains('banana')) unitWeight = 0.15;
    else if (n.contains('milk') || n.contains('juice') || n.contains('water')) unitWeight = 1.0; 
    else if (n.contains('egg')) unitWeight = 0.05;
    else if (n.contains('bread')) unitWeight = 0.4;
    else if (n.contains('carrot') || n.contains('potato')) unitWeight = 0.12;
    else if (n.contains('meat')) unitWeight = 0.5;
    
    double total = unitWeight * quantity;
    return total > 5.0 ? 4.95 : total; 
  }

  void _startLoadCellSimulation() {
    SocketService.on('sensor_data', _onHardwareWeightUpdate);
  }

  void _onHardwareWeightUpdate(dynamic data) {
    if (!mounted) return;
    final rawGrams = (data['weight'] as num?)?.toDouble() ?? 0.0;
    final weightKg = rawGrams / 1000.0;
    setState(() {
      currentWeight = weightKg;
    });
  }

  @override
  void dispose() {
    _aiDebounceTimer?.cancel();
    _weightSimulationTimer?.cancel();
    SocketService.off('sensor_data', _onHardwareWeightUpdate);
    nameController.removeListener(_onNameChanged);
    nameController.dispose();
    brandController.dispose();
    categoryController.dispose();
    quantityController.dispose();
    weightController.dispose();
    litresController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _checkLiquid(String name, String? category) {
    final nameLower = name.toLowerCase();
    final catLower = (category ?? '').toLowerCase();
    bool liquid = liquidCategories.any((c) => catLower.contains(c.toLowerCase()));
    if (!liquid) {
      liquid = liquidKeywords.any((kw) => nameLower.contains(kw));
    }
    if (liquid != isLiquid) {
      setState(() => isLiquid = liquid);
    }
  }

  Future<void> _refreshAiImage() async {
    if (_isFetchingAiImage) return;
    setState(() => _isFetchingAiImage = true);

    try {
      final token = await SecureStorageService.getToken();
      if (token == null) {
        setState(() => _isFetchingAiImage = false);
        return;
      }
      final name = nameController.text.trim().isNotEmpty ? nameController.text.trim() : "food";
      final response = await http.post(
        Uri.parse('${ApiService.baseDomain}/api/ai/suggest-image'),
        headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      );
      if (response.statusCode == 200) {
        final suggestedData = jsonDecode(response.body);
        setState(() {
          _aiSuggestedImageUrl = suggestedData['suggested_url'];
          imageUrl = _aiSuggestedImageUrl; 
          _isFetchingAiImage = false;
        });
      } else {
        setState(() => _isFetchingAiImage = false);
      }
    } catch (e) {
      setState(() => _isFetchingAiImage = false);
    }
  }

  Future<void> pickImage(ImageSource source) async {
    final XFile? picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        imagePath = picked.path;
        _originalLocalImagePath = picked.path; 
        _isFetchingAiImage = true;
        _aiSuggestedImageUrl = null;
      });

      try {
        final token = await SecureStorageService.getToken();
        if (token == null) {
          setState(() => _isFetchingAiImage = false);
          return;
        }
        final name = nameController.text.trim().isNotEmpty ? nameController.text.trim() : "food";
        final request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseDomain}/api/ai/suggest-image'));
        request.headers['x-auth-token'] = token;
        request.fields['name'] = name;
        request.files.add(await http.MultipartFile.fromPath('image', picked.path));
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 200) {
          final suggestedData = jsonDecode(response.body);
          if (suggestedData != null && suggestedData['detected_info'] != null) {
            final info = suggestedData['detected_info'];
            setState(() {
              if (nameController.text.isEmpty || nameController.text == "food") {
                nameController.text = info['name'] ?? "";
              }
              if (info['category'] != null && categoryOptions.contains(info['category'])) {
                categoryController.text = info['category'];
              }
              if (info['expiryDays'] != null) {
                final int days = (info['expiryDays'] as num).toInt();
                selectedDate = DateTime.now().add(Duration(days: days));
                expirySource = "estimated";
              }
              _aiSuggestedImageUrl = suggestedData['suggested_url'];
              _isFetchingAiImage = false;
            });
            _checkLiquid(nameController.text, categoryController.text);
          } else {
             setState(() => _isFetchingAiImage = false);
          }
        } else {
           setState(() => _isFetchingAiImage = false);
        }
      } catch (e) {
          setState(() => _isFetchingAiImage = false);
      }
    }
  }

  Widget _buildGlassInput({
    Key? key,
    required String label, 
    required TextEditingController controller, 
    TextInputType type = TextInputType.text,
    IconData? icon,
    bool readOnly = false,
    Function(String)? onChanged,
    required bool isLight,
    double hPadding = 12, 
  }) {
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color iconColor = isLight ? Colors.teal : Colors.tealAccent;

    return Container(
      key: key, // 🎯
      decoration: BoxDecoration(
        color: isLight ? Colors.grey.shade200 : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.15)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        readOnly: readOnly,
        onChanged: onChanged,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isLight ? Colors.black54 : Colors.white54),
          prefixIcon: icon != null ? Icon(icon, color: iconColor) : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLight = themeProvider.currentTheme == ThemeType.light;
    final isDark = themeProvider.currentTheme == ThemeType.dark;
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
        title: Text(
          widget.existingItem == null ? "Add Inventory" : "Edit Inventory",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ).animate().fadeIn(),
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

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 100, bottom: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(isLight ? 0.05 : 0.2), blurRadius: 30)
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildGlassInput(
                          key: _wtNameKey, // 🎯
                          label: "Item Name", 
                          controller: nameController, 
                          icon: Icons.fastfood,
                          isLight: isLight,
                        ).animate().slideX(begin: -0.1).fade(),

                        if (_isAiDetecting)
                          Padding(
                           padding: const EdgeInsets.only(top: 8.0, right: 10),
                           child: Align(
                             alignment: Alignment.centerRight,
                             child: Text("✨ AI is analyzing item...", style: TextStyle(color: isLight ? Colors.teal : Colors.tealAccent, fontSize: 12, fontStyle: FontStyle.italic)),
                           ),
                          ).animate().fadeIn(),

                        const SizedBox(height: 15),

                        Row(
                          children: [
                            Expanded(
                              child: _buildGlassInput(
                                label: "Brand", 
                                controller: brandController, 
                                icon: Icons.branding_watermark,
                                isLight: isLight,
                              ).animate().slideX(begin: -0.1).fade(delay: 50.ms),
                            ),
                            const SizedBox(width: 6), 
                            Expanded(
                              child: Container(
                                key: _wtCategoryKey, // 🎯
                                decoration: BoxDecoration(
                                  color: isLight ? Colors.grey.shade200 : Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.15)),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: categoryOptions.contains(categoryController.text) ? categoryController.text : null,
                                  decoration: InputDecoration(
                                    labelText: "Category",
                                    labelStyle: TextStyle(color: isLight ? Colors.black54 : Colors.white54),
                                    prefixIcon: Icon(Icons.category, color: isLight ? Colors.teal : Colors.tealAccent, size: 20), 
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), 
                                  ),
                                  dropdownColor: isLight ? Colors.white : const Color(0xFF1E2A33),
                                  style: TextStyle(color: textColor),
                                  items: categoryOptions.map((cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat, style: TextStyle(color: textColor)),
                                  )).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      categoryController.text = val ?? '';
                                      _checkLiquid(nameController.text, val);
                                    });
                                  },
                                ),
                              ).animate().slideX(begin: 0.1).fade(delay: 50.ms),
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        _buildGlassInput(
                          label: "Quantity", 
                          controller: quantityController, 
                          type: TextInputType.number,
                          icon: Icons.numbers,
                          isLight: isLight,
                        ).animate().slideX(begin: -0.1).fade(delay: 100.ms),

                        const SizedBox(height: 15),

                        if (isLiquid)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: _buildGlassInput(
                              label: "Capacity (Litres)", 
                              controller: litresController, 
                              type: const TextInputType.numberWithOptions(decimal: true),
                              icon: Icons.opacity,
                              isLight: isLight,
                            ).animate().slideX(begin: -0.1).fade(delay: 150.ms),
                          ),

                        Container(
                          key: _wtExpiryKey, // 🎯
                          decoration: BoxDecoration(
                            color: isLight ? Colors.grey.shade200 : Colors.tealAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isLight ? Colors.transparent : Colors.tealAccent.withOpacity(0.3)),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.calendar_month, color: isLight ? Colors.teal : Colors.tealAccent),
                            title: Text(expirySource == "estimated" ? "Expiry Date (Estimated)" : "Expiry Date", style: TextStyle(color: isLight ? Colors.black54 : Colors.white70)),
                            subtitle: Text(
                              selectedDate == null ? "Select Date" : DateFormat('MMM dd, yyyy').format(selectedDate!),
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                            ),
                            onTap: () => _pickDateTime(isExpiry: true),
                          ),
                        ).animate().slideY(begin: 0.1).fade(delay: 200.ms),
                        
                        const SizedBox(height: 15),

                        // 🔔 Reminder Date Selection
                        Container(
                          decoration: BoxDecoration(
                            color: isLight ? Colors.grey.shade200 : Colors.blueAccent.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isLight ? Colors.transparent : Colors.blueAccent.withOpacity(0.2)),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.notifications_active_outlined, color: isLight ? Colors.blue : Colors.blueAccent),
                            title: Text("Custom Reminder", style: TextStyle(color: isLight ? Colors.black54 : Colors.white70)),
                            subtitle: Text(
                              selectedReminderDate == null ? "None (Tap to set)" : DateFormat('MMM dd, HH:mm').format(selectedReminderDate!),
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                            ),
                            trailing: selectedReminderDate != null ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () => setState(() => selectedReminderDate = null),
                            ) : null,
                            onTap: () => _pickDateTime(isExpiry: false),
                          ),
                        ).animate().slideY(begin: 0.1).fade(delay: 220.ms),

                        const SizedBox(height: 15),

                        _buildGlassInput(
                          label: "Notes (Optional)", 
                          controller: notesController, 
                          icon: Icons.note_alt_outlined,
                          isLight: isLight,
                        ).animate().slideX(begin: -0.1).fade(delay: 250.ms),
                        
                        const SizedBox(height: 35),

                        SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            key: _wtSaveKey, // 🎯
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLight ? Colors.teal : Colors.tealAccent,
                              foregroundColor: isLight ? Colors.white : Colors.black,
                              elevation: 10,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () async {
                               if (nameController.text.isEmpty || selectedDate == null) {
                                SnackbarUtils.showWarning(context, "Name and Expiry Date are required!");
                                return;
                              }
                              final item = InventoryItem(
                                id: widget.existingItem?.id,
                                name: nameController.text,
                                brand: brandController.text,
                                category: categoryController.text,
                                quantity: int.tryParse(quantityController.text) ?? 1,
                                weight: double.tryParse(weightController.text) ?? currentWeight,
                                litres: isLiquid ? double.tryParse(litresController.text) : null,
                                expiryDate: selectedDate!,
                                reminderDate: selectedReminderDate, // 👈 Added
                                imagePath: imagePath,
                                imageUrl: imageUrl,
                                notes: notesController.text, // 👈 Added (was missing notes too!)
                                dateAdded: widget.existingItem?.dateAdded ?? DateTime.now(),
                              );
                              widget.onSave?.call(item);
                            },
                            child: Text(
                              widget.existingItem == null ? "Save Inventory" : "Update Changes",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                          ),
                        ).animate().slideY(begin: 0.2).fade(delay: 400.ms),

                        const SizedBox(height: 60), 
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          if (_showWalkthrough)
            AppWalkthrough(
              steps: _currentSteps,
              onFinish: () => setState(() => _showWalkthrough = false),
              onSkip: () => setState(() => _showWalkthrough = false),
            ),
        ],
      ),
    );
  }
}
