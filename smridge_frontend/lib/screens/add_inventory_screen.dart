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
  String _lastAutoCategory = "Others";
  
  Timer? _aiDebounceTimer;
  bool _isAiDetecting = false;

  @override
  void initState() {
    super.initState();

    final item = widget.existingItem ?? widget.initialItem;

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
      if (mounted) setState(() => _isAiDetecting = false);
    }
  }

  void _startLoadCellSimulation() {
    SocketService.on('sensor_data', _onHardwareWeightUpdate);
  }

  void _onHardwareWeightUpdate(dynamic data) {
    if (!mounted) return;
    final rawGrams = (data['weight'] as num?)?.toDouble() ?? 0.0;
    // ESP32 and simulator both send weight in grams → convert to kg
    final weightKg = rawGrams / 1000.0;
    setState(() {
      currentWeight = weightKg;
      // Only populate the field if there's a meaningful weight on the scale
      if (rawGrams > 0) {
        weightController.text = weightKg.toStringAsFixed(3);
      }
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
                                hPadding: 12, 
                              ).animate().slideX(begin: -0.1).fade(delay: 50.ms),
                            ),
                            const SizedBox(width: 6), 
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
                            const SizedBox(width: 8), 
                            Expanded(
                              child: _buildGlassInput(
                                label: "Weight (kg)", 
                                controller: weightController, 
                                type: const TextInputType.numberWithOptions(decimal: true),
                                icon: Icons.monitor_weight_outlined,
                                readOnly: false,
                                isLight: isLight,
                                onChanged: (val) {
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

                        Container(
                          decoration: BoxDecoration(
                            color: isLight ? Colors.grey.shade200 : Colors.tealAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isLight ? Colors.transparent : Colors.tealAccent.withOpacity(0.3)),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.calendar_month, color: isLight ? Colors.teal : Colors.tealAccent),
                            title: Text(expirySource == "estimated" ? "Expiry Date & Time (Estimated)" : "Expiry Date & Time", style: TextStyle(color: isLight ? Colors.black54 : Colors.white70)),
                            subtitle: Text(
                              selectedDate == null ? "Select Date & Time" : DateFormat('MMM dd, yyyy - HH:mm').format(selectedDate!),
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                            ),
                            onTap: () => _pickDateTime(isExpiry: true),
                          ),
                        ).animate().slideY(begin: 0.1).fade(delay: 200.ms),

                        const SizedBox(height: 15),

                        Container(
                          decoration: BoxDecoration(
                            color: isLight ? Colors.grey.shade200 : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isLight ? Colors.transparent : Colors.white10),
                          ),
                          child: Column(
                            children: [
                                ListTile(
                                  leading: Icon(Icons.alarm_add, color: isLight ? Colors.orange : Colors.orangeAccent),
                                  title: Text("Custom Reminder (Optional)", style: TextStyle(color: isLight ? Colors.black54 : Colors.white70)),
                                  subtitle: Text(
                                    selectedReminderDate == null ? "None" : DateFormat('MMM dd, yyyy - HH:mm').format(selectedReminderDate!),
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                  ),
                                  trailing: selectedReminderDate != null ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => setState(() => selectedReminderDate = null),
                                  ) : null,
                                  onTap: () => _pickDateTime(isExpiry: false),
                                ),
                            ],
                          ),
                        ).animate().slideY(begin: 0.1).fade(delay: 220.ms),

                        const SizedBox(height: 15),

                        _buildGlassInput(
                          label: "Notes (Optional)", 
                          controller: notesController, 
                          icon: Icons.note_alt_outlined,
                          isLight: isLight,
                        ).animate().slideX(begin: -0.1).fade(delay: 250.ms),
                        
                        const SizedBox(height: 25),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isFetchingAiImage)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      CircularProgressIndicator(color: Colors.tealAccent),
                                      SizedBox(height: 10),
                                      Text("AI is analyzing image...", style: TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                ),
                              )
                            else if (_aiSuggestedImageUrl != null)
                               Column(
                                 children: [
                                   Text("AI detected a generic product. Which image do you prefer?", 
                                     style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
                                   const SizedBox(height: 12),
                                   Row(
                                     children: [
                                       Expanded(
                                         child: GestureDetector(
                                           onTap: () => setState(() {
                                             imageUrl = null; 
                                             imagePath = _originalLocalImagePath; 
                                           }),
                                           child: Column(
                                             children: [
                                               ClipRRect(
                                                 borderRadius: BorderRadius.circular(12),
                                                 child: Container(
                                                   height: 80,
                                                   width: double.infinity,
                                                   decoration: BoxDecoration(
                                                     border: Border.all(color: imageUrl == null ? Colors.tealAccent : Colors.transparent, width: 2),
                                                   ),
                                                   child: imagePath != null ? Image.file(File(imagePath!), fit: BoxFit.cover) : const Icon(Icons.image),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text("My Image", style: TextStyle(color: imageUrl == null ? Colors.tealAccent : textColor, fontSize: 10)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(() {
                                              imageUrl = _aiSuggestedImageUrl;
                                              imagePath = null; 
                                            }),
                                            child: Column(
                                              children: [
                                                Stack(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: Container(
                                                        height: 80,
                                                        width: double.infinity,
                                                        decoration: BoxDecoration(
                                                          border: Border.all(color: imageUrl == _aiSuggestedImageUrl ? Colors.deepPurpleAccent : Colors.transparent, width: 2),
                                                        ),
                                                        child: CachedNetworkImage(imageUrl: _aiSuggestedImageUrl!, fit: BoxFit.cover),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      right: 4,
                                                      top: 4,
                                                      child: GestureDetector(
                                                        onTap: _refreshAiImage,
                                                        child: Container(
                                                          padding: const EdgeInsets.all(4),
                                                          decoration: BoxDecoration(
                                                            color: Colors.black54,
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: const Icon(Icons.refresh, color: Colors.white, size: 14),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text("AI Image", style: TextStyle(color: imageUrl == _aiSuggestedImageUrl ? Colors.deepPurpleAccent : textColor, fontSize: 10)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text("(Tap on image to select)", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 10, fontStyle: FontStyle.italic)),
                                  ],
                                ).animate().fadeIn(),

                            const SizedBox(height: 15),

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
                                id: widget.existingItem?.id,
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
                                reminderDate: selectedReminderDate,
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

                        const SizedBox(height: 100), 
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
