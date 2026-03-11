import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:math';
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
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/fridge_customization_provider.dart';

class AddInventoryScreen extends StatefulWidget {
  final Function(InventoryItem) onSave;
  final InventoryItem? existingItem;
  final InventoryItem? initialItem;
  final VoidCallback? onBack;

  const AddInventoryScreen({
    super.key,
    required this.onSave,
    this.existingItem,
    this.initialItem,
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
  String? imagePath;
  String? imageUrl;
  bool isPackaged = false;
  bool isLiquid = false;
  String? barcode;
  String? expirySource;
  final ImagePicker picker = ImagePicker();

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

  // Load cell mocking
  double currentWeight = 0.0;
  Timer? _weightSimulationTimer;
  String _lastAutoCategory = "Others";

  @override
  void initState() {
    super.initState();

    final item = widget.existingItem ?? widget.initialItem;

    if (item != null) {
      nameController.text = item.name;
      brandController.text = item.brand ?? "";
      categoryController.text = item.category ?? "";
      quantityController.text = item.quantity.toString();

      // Convert grams to kg if weight > 100 (likely grams from OpenFoodFacts)
      double rawWeight = item.weight ?? 0.0;
      if (rawWeight > 100) rawWeight = rawWeight / 1000;
      weightController.text = rawWeight.toStringAsFixed(3);
      currentWeight = rawWeight;

      // Detect liquid and convert ml to litres
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
      selectedDate = DateTime.now();
      _startLoadCellSimulation();
    }

    nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final newAutoCat = CategoryHelper.autoCategorizeProduct(nameController.text);
    
    // Auto-update the category field only if the user hasn't typed a custom category.
    // We assume they haven't if it's currently empty or strictly matches the last auto-prediction.
    if (categoryController.text.isEmpty || categoryController.text == _lastAutoCategory) {
      if (categoryController.text != newAutoCat) {
        setState(() {
          categoryController.text = newAutoCat;
        });
      }
    }
    _lastAutoCategory = newAutoCat;

    // Check if item is liquid
    _checkLiquid(nameController.text, categoryController.text);

    // Auto-update expiry date if the user hasn't manually overridden it
    if (expirySource != "manual") {
      final estimatedExpiry = ExpiryEstimator.estimateExpiryDate(nameController.text);
      if (selectedDate == null || selectedDate!.difference(estimatedExpiry).inDays.abs() > 0) {
        setState(() {
          selectedDate = estimatedExpiry;
          expirySource = "estimated";
        });
      }
    }
  }

  void _startLoadCellSimulation() {
    // Simulates a load cell reading fluctuations when placing an item in the fridge
    _weightSimulationTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) return;
      setState(() {
        // Mock a steady rise to a random weight then stabilize
        if (currentWeight < 2.5) {
          currentWeight += Random().nextDouble() * 0.5;
        } else {
          weightController.text = currentWeight.toStringAsFixed(2);
          _weightSimulationTimer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _weightSimulationTimer?.cancel();
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

  Future<void> pickImage(ImageSource source) async {
    final XFile? picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() => imagePath = picked.path);
    }
  }

  Widget _buildGlassInput({
    required String label, 
    required TextEditingController controller, 
    TextInputType type = TextInputType.text,
    IconData? icon,
    bool readOnly = false,
    Function(String)? onChanged,
    required bool isLight,
  }) {
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color iconColor = isLight ? Colors.teal : Colors.tealAccent;

    return Container(
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
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
        title: Text(
          widget.existingItem == null ? "Add Inventory" : "Edit Inventory",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ).animate().fadeIn(),
      ),
      body: Stack(
        children: [
          // Background Gradient + Snow
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

          // Main Glass Content Area
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 100, bottom: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                          label: "Item Name", 
                          controller: nameController, 
                          icon: Icons.fastfood,
                          isLight: isLight,
                        ).animate().slideX(begin: -0.1).fade(),

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
                            const SizedBox(width: 15),
                            Expanded(
                              child: Container(
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
                                    prefixIcon: Icon(Icons.category, color: isLight ? Colors.teal : Colors.tealAccent),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

                        Row(
                          children: [
                            Expanded(
                              child: _buildGlassInput(
                                label: "Quantity", 
                                controller: quantityController, 
                                type: TextInputType.number,
                                icon: Icons.numbers,
                                isLight: isLight,
                              ).animate().slideX(begin: -0.1).fade(delay: 100.ms),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: _buildGlassInput(
                                label: "Weight (kg)", 
                                controller: weightController, 
                                type: const TextInputType.numberWithOptions(decimal: true),
                                icon: Icons.monitor_weight_outlined,
                                readOnly: false,
                                isLight: isLight,
                                onChanged: (val) {
                                  // Stop simulation if user manually forces a weight
                                  _weightSimulationTimer?.cancel();
                                },
                              ).animate().slideX(begin: 0.1).fade(delay: 100.ms),
                            ),
                          ],
                        ),

                        if (widget.existingItem == null)
                           Padding(
                             padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.end,
                               children: [
                                 Text(
                                    _weightSimulationTimer?.isActive == true 
                                        ? "Reading Load Cell... ${currentWeight.toStringAsFixed(2)}kg"
                                        : "Load Cell Locked: ${currentWeight.toStringAsFixed(2)}kg",
                                     style: TextStyle(
                                      color: _weightSimulationTimer?.isActive == true ? (isLight ? Colors.teal : Colors.tealAccent) : Colors.grey,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic
                                    ),
                                 ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 800.ms),
                               ],
                             ),
                           ),

                        if (isLiquid) ...[
                          const SizedBox(height: 15),
                          _buildGlassInput(
                            label: "Volume (Litres)",
                            controller: litresController,
                            type: const TextInputType.numberWithOptions(decimal: true),
                            icon: Icons.water_drop,
                            isLight: isLight,
                          ).animate().slideX(begin: -0.1).fade(delay: 120.ms),
                        ],

                        const SizedBox(height: 15),

                        // Expiry Date Glass Button
                        Container(
                          decoration: BoxDecoration(
                            color: isLight ? Colors.grey.shade200 : Colors.tealAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isLight ? Colors.transparent : Colors.tealAccent.withOpacity(0.3)),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.calendar_month, color: isLight ? Colors.teal : Colors.tealAccent),
                            title: Text(expirySource == "estimated" ? "Expiry Date (Estimated)" : "Expiry Date", style: TextStyle(color: isLight ? Colors.black54 : Colors.white70)),
                            subtitle: Text(
                              selectedDate == null ? "Select Date" : selectedDate!.toLocal().toString().split(' ')[0],
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = picked;
                                  expirySource = "manual";
                                });
                              }
                            },
                          ),
                        ).animate().slideY(begin: 0.1).fade(delay: 200.ms),

                        const SizedBox(height: 15),

                        _buildGlassInput(
                          label: "Notes (Optional)", 
                          controller: notesController, 
                          icon: Icons.note_alt_outlined,
                          isLight: isLight,
                        ).animate().slideX(begin: -0.1).fade(delay: 250.ms),
                        
                        const SizedBox(height: 25),

                        // Image Picker Row
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isLight ? Colors.grey.shade200 : Colors.white.withOpacity(0.1),
                                  foregroundColor: textColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt, size: 20),
                                label: const Text("Camera"),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isLight ? Colors.grey.shade200 : Colors.white.withOpacity(0.1),
                                  foregroundColor: textColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo, size: 20),
                                label: const Text("Gallery"),
                              ),
                            ),
                          ],
                        ).animate().fade(delay: 300.ms),

                        const SizedBox(height: 20),

                        if (imagePath != null || imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: imagePath != null
                                ? Image.file(
                                    File(imagePath!),
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: imageUrl!,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
                                    errorWidget: (context, url, error) => Container(
                                      height: 160, 
                                      color: Colors.white10, 
                                      child: const Icon(Icons.broken_image, color: Colors.white54, size: 50)
                                    ),
                                  ),
                          ).animate().scale().fade(),

                        const SizedBox(height: 30),

                        SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLight ? Colors.teal : Colors.tealAccent.withOpacity(0.8),
                              foregroundColor: Colors.white,
                              elevation: 10,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              if (nameController.text.isEmpty || selectedDate == null) {
                                SnackbarUtils.showWarning(context, "Name and Expiry Date are required!");
                                return;
                              }

                              final item = InventoryItem(
                                name: nameController.text,
                                brand: brandController.text.isNotEmpty ? brandController.text : null,
                                category: categoryController.text.isNotEmpty ? categoryController.text : null,
                                quantity: int.tryParse(quantityController.text) ?? 1,
                                weight: double.tryParse(weightController.text) ?? currentWeight,
                                litres: isLiquid && litresController.text.isNotEmpty ? double.tryParse(litresController.text) : null,
                                notes: notesController.text.isNotEmpty ? notesController.text : null,
                                isPackaged: isPackaged,
                                barcode: barcode,
                                expiryDate: selectedDate!,
                                expirySource: expirySource,
                                imagePath: imagePath,
                                imageUrl: imageUrl,
                                dateAdded: widget.existingItem?.dateAdded ?? widget.initialItem?.dateAdded ?? DateTime.now(),
                              );

                              widget.onSave(item);
                              final customizer = Provider.of<FridgeCustomizationProvider>(context, listen: false);
                              AudioService.playSuccess(
                                index: customizer.inventorySaveSoundIndex, 
                                customPath: customizer.customInventorySaveSoundPath,
                              );
                            },
                            child: Text(
                              widget.existingItem == null ? "Save Inventory" : "Update Changes",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                          ),
                        ).animate().slideY(begin: 0.2).fade(delay: 400.ms),

                        const SizedBox(height: 100), // Ensures scroll clears dock
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
