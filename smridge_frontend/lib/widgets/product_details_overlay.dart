import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/inventory_item.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import '../services/secure_storage_service.dart';
import '../services/notification_service.dart';
import '../utils/snackbar_utils.dart';
import 'package:intl/intl.dart';

class ProductDetailsOverlay extends StatefulWidget {
  final InventoryItem item;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductDetailsOverlay({
    super.key, 
    required this.item, 
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ProductDetailsOverlay> createState() => _ProductDetailsOverlayState();
}

class _ProductDetailsOverlayState extends State<ProductDetailsOverlay> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isFullScreen = false; 
  bool _isImageViewerOpen = false; // 🔹 Image viewer state
  bool _isImageZoomed = false;    // 🔹 Zoom toggle
  String? _expandedImageUrl;
  String? _expandedImagePath;

  late InventoryItem _item; // 🔹 Local state to reflect updates

  // AI States
  bool _isLoadingOverview = false;
  String? _aiOverview;
  bool _isLoadingRecipes = false;
  List<dynamic>? _aiRecipes;

  // Groq Unified Analysis State
  bool _isLoadingAnalysis = false;
  Map<String, dynamic>? _groqAnalysis;

  @override
  void initState() {
    super.initState();
    _item = widget.item; // 🔹 Initialize local state
    // 🔹 Prefetch analysis immediately for "Instant intelligence" experience
    _runGroqAnalysis();
  }

  // REMOVED: Separate fetchers. We now use Unified _runGroqAnalysis.

  Widget _buildSlideIndicator(bool isLight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return AnimatedContainer(
          duration: 300.ms,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index 
                ? (isLight ? Colors.teal : Colors.tealAccent) 
                : Colors.grey.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }


  Future<void> _runGroqAnalysis() async {
    if (_groqAnalysis != null) return;
    setState(() => _isLoadingAnalysis = true);
    final token = await SecureStorageService.getToken();
    if (token == null) { setState(() => _isLoadingAnalysis = false); return; }
    final result = await ApiService.analyzeFoodItem(
      name: _item.name,
      token: token,
      expiryDate: _item.expiryDate.toIso8601String(),
    );
    if (mounted) setState(() { _groqAnalysis = result; _isLoadingAnalysis = false; });
  }

  // 🔔 Local Reminder Picker
  Future<void> _pickReminder(bool isLight) async {
    final DateTime initial = widget.item.reminderDate ?? DateTime.now().add(const Duration(minutes: 30));
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: widget.item.expiryDate,
      helpText: "Set Reminder Date",
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        helpText: "Set Reminder Time",
      );

      if (pickedTime != null && mounted) {
        final fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (fullDateTime.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminder must be in the future!")));
          return;
        }

        setState(() => _isLoadingAnalysis = true); // Using as a general loader
        
        try {
          final token = await SecureStorageService.getToken();
          if (token != null) {
            // 🔹 Update backend
            if (_item.id == null) {
              if (mounted) SnackbarUtils.showError(context, "Error: Item ID is missing.");
              return;
            }

            final updatedItem = _item.copyWith(reminderDate: fullDateTime);
            final success = await ApiService.updateFood(updatedItem, token);

            if (success && mounted) {
              try {
                await NotificationService().scheduleLocalReminder(
                  _item.id.hashCode,
                  _item.name,
                  fullDateTime,
                );
              } catch (e) { print("Notif Error: $e"); }
              
              setState(() {
                _item = updatedItem;
                _isLoadingAnalysis = false;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: isLight ? Colors.teal : Colors.tealAccent,
                  content: Text("Reminder set for ${DateFormat('MMM dd, HH:mm').format(fullDateTime)} 🔔", 
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
                  ),
                ),
              );
            } else if (mounted) {
              SnackbarUtils.showError(context, "Failed to save reminder to server.");
            }
          }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        } finally {
          if (mounted) setState(() => _isLoadingAnalysis = false);
        }
      }
    }
  }

  Color _freshnessColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    if (score >= 20) return Colors.deepOrange;
    return Colors.red;
  }

  // 🟢 SLIDE 2: OVERVIEW & NUTRITION
  Widget _buildOverviewNutritionSlide(bool isLight, Color textColor) {
    if (_isLoadingAnalysis) return _buildLoadingState();
    if (_groqAnalysis == null) return _buildLoadingState();

    final a = _groqAnalysis!;
    final nutrition = a['nutritional_values'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.info_outline, "Product Overview", isLight ? Colors.teal : Colors.tealAccent),
            const SizedBox(height: 12),
            MarkdownBody(
              data: a['overview']?.toString() ?? "Gathering overview...",
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: textColor, fontSize: 14, height: 1.6),
                listBullet: TextStyle(color: isLight ? Colors.teal : Colors.tealAccent),
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader(Icons.restaurant_menu, "Nutritional Facts", isLight ? Colors.teal : Colors.tealAccent),
            const SizedBox(height: 12),
            if (nutrition != null)
              _buildNutritionGrid(nutrition, isLight, textColor)
            else
              const Text("Nutritional data unavailable for this item."),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionGrid(Map<String, dynamic> n, bool isLight, Color textColor) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _buildNutritionCard("Calories", (n['calories'] ?? "--").toString(), Colors.redAccent, isLight),
        _buildNutritionCard("Protein", (n['protein'] ?? "--").toString(), Colors.greenAccent, isLight),
        _buildNutritionCard("Carbs", (n['carbs'] ?? "--").toString(), Colors.blueAccent, isLight),
        _buildNutritionCard("Fats", (n['fats'] ?? "--").toString(), Colors.orangeAccent, isLight),
      ],
    );
  }

  Widget _buildNutritionCard(String label, String value, Color color, bool isLight) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: isLight ? Colors.black54 : Colors.white54)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // 🟢 SLIDE 3: SMART RECIPES (Dedicated)
  Widget _buildDedicatedRecipesSlide(bool isLight, Color textColor) {
    if (_isLoadingAnalysis) return _buildLoadingState();
    if (_groqAnalysis == null) return _buildLoadingState();

    // 🔹 Resilient parsing: check 'recipes' (list) or fallback to 'recipe_suggestion' (string)
    List<dynamic> recipesList = [];
    if (_groqAnalysis!['recipes'] is List) {
      recipesList = _groqAnalysis!['recipes'];
    } else if (_groqAnalysis!['recipe_suggestion'] != null) {
      recipesList = [{
        'title': 'Chef\'s Recommendation',
        'ingredients': ['Check description'],
        'steps': [_groqAnalysis!['recipe_suggestion']]
      }];
    }

    if (recipesList.isEmpty) {
      return Center(child: Text("No recipes found for this item.", style: TextStyle(color: textColor.withOpacity(0.5))));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.auto_awesome, "Masterclass Recipes", isLight ? Colors.teal : Colors.tealAccent),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: false, // ListView within Expanded is better with shrinkWrap false
              itemCount: recipesList.length,
              itemBuilder: (context, index) {
                final r = recipesList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: (isLight ? Colors.teal : Colors.tealAccent).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (isLight ? Colors.teal : Colors.tealAccent).withOpacity(0.2)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      shape: const RoundedRectangleBorder(side: BorderSide.none),
                      collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['title'] ?? (r['name'] ?? "Recipe ${index + 1}"),
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (r['type'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                r['type'].toString().toUpperCase(),
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                      iconColor: isLight ? Colors.teal : Colors.tealAccent,
                      collapsedIconColor: isLight ? Colors.teal : Colors.tealAccent,
                      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1, color: Colors.white10),
                        const SizedBox(height: 12),
                        Text("Ingredients:", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ...(r['ingredients'] as List<dynamic>? ?? []).map((ing) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text("• $ing", style: TextStyle(color: textColor, fontSize: 13)),
                        )),
                        const SizedBox(height: 12),
                        Text("Instructions:", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                        ...(r['steps'] as List<dynamic>? ?? []).map((s) => s.toString().trim().replaceFirst(RegExp(r'^\d+[\.\:\s]+'), '')).where((s) => s.length > 3).toList().asMap().entries.map((entry) => 
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${entry.key + 1}. ", style: TextStyle(color: isLight ? Colors.teal : Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                Expanded(child: Text(entry.value, style: TextStyle(color: textColor, fontSize: 13, height: 1.4))),
                              ],
                            ),
                          )
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 SLIDE 4: FRESHNESS MASTERY
  Widget _buildDetailedFreshnessSlide(bool isLight, Color textColor) {
    if (_isLoadingAnalysis) return _buildLoadingState();
    if (_groqAnalysis == null) return _buildLoadingState();

    final a = _groqAnalysis!;
    // Resilient parsing for freshness score
    final scoreValue = a['freshness_score'];
    final int score = (scoreValue is num) ? scoreValue.toInt() : (int.tryParse(scoreValue?.toString() ?? '0') ?? 0);
    final String status = a['freshness_status']?.toString() ?? 'Unknown';
    final scoreColor = _freshnessColor(score);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.health_and_safety, "Freshness Mastery", isLight ? Colors.teal : Colors.tealAccent),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120, height: 120,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("$score", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: scoreColor)),
                      Text(status, style: TextStyle(fontSize: 14, color: scoreColor, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 🔹 Sensor Telemetry Dashboard
            if (a['sensors'] != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withOpacity(0.03) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (isLight ? Colors.teal : Colors.tealAccent).withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniSensorItem(Icons.gas_meter, "Gas", "${a['sensors']['gas']} ppm", Colors.orangeAccent),
                    _buildMiniSensorItem(Icons.thermostat, "Temp", "${a['sensors']['temp']}°C", Colors.redAccent),
                    _buildMiniSensorItem(Icons.water_drop, "Hum", "${a['sensors']['humidity']}%", Colors.blueAccent),
                  ],
                ),
              ),
            // Unsplash Reference
            if (a['image_url'] != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedImageUrl = a['image_url'];
                    _expandedImagePath = null;
                    _isImageViewerOpen = true;
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(a['image_url'], height: 140, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 16),
            _sectionHeader(Icons.psychology, "AI Analysis Logic", isLight ? Colors.teal : Colors.tealAccent),
            const SizedBox(height: 8),
            Text(a['freshness_explanation']?.toString() ?? "Generating detailed insights...", style: TextStyle(color: textColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            _sectionHeader(Icons.timer_outlined, "Estimated Remainder", isLight ? Colors.teal : Colors.tealAccent),
            const SizedBox(height: 8),
            Text("Remaining: ${a['estimated_remaining_days'] ?? 'N/A'} days", style: TextStyle(color: textColor.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _sectionHeader(Icons.tips_and_updates, "Storage Guru Tips", isLight ? Colors.teal : Colors.tealAccent),
            const SizedBox(height: 8),
            Text(a['storage_advice']?.toString() ?? "Calculating optimal storage...", style: TextStyle(color: textColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isLight ? Colors.teal : Colors.tealAccent).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (isLight ? Colors.teal : Colors.tealAccent).withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: isLight ? Colors.teal : Colors.tealAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Based on live sensor telemetry and deep learning analysis.", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSensorItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.teal),
          SizedBox(height: 16),
          Text("AI is analyzing...", style: TextStyle(color: Colors.teal)),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // REMOVED: Mock Slides and fragmented builds.
  // Replaced by Slide 2 (Overview/Nutrition), Slide 3 (Recipes), Slide 4 (Freshness-Mastery).

  Widget _buildInfoRow(IconData icon, String title, String value, Color textColor, bool isLight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 22, color: isLight ? Colors.teal.withOpacity(0.7) : Colors.white54),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(color: isLight ? Colors.black54 : Colors.white60, fontSize: 16)),
          const Spacer(),
          Text(value, 
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500), 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Provider.of<ThemeProvider>(context).currentTheme == ThemeType.light;
    final textColor = isLight ? Colors.black87 : Colors.white;
    final glassColor = isLight ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05);
    final borderColor = isLight ? Colors.teal.withOpacity(0.2) : Colors.white.withOpacity(0.1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 🔹 Main Details Layer
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // consume taps inside dialog
                  child: AnimatedContainer(
                  duration: 400.ms,
                  curve: Curves.easeInOut,
                  margin: _isFullScreen ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  width: MediaQuery.of(context).size.width,
                  height: _isFullScreen ? MediaQuery.of(context).size.height : MediaQuery.of(context).size.height * 0.85,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_isFullScreen ? 0 : 32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: glassColor,
                          borderRadius: BorderRadius.circular(_isFullScreen ? 0 : 32),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, spreadRadius: -5)
                          ],
                        ),
                          child: SafeArea(
                            bottom: false,
                            child: Column(
                              children: [
                                // 🔹 Premium Hero Header
                                Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _expandedImageUrl = _item.imageUrl;
                                          _expandedImagePath = _item.imagePath;
                                          _isImageViewerOpen = true;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: 400.ms,
                                        height: _isFullScreen ? 260 : 200,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          image: _buildItemDecorationImage(_isImageZoomed ? BoxFit.contain : BoxFit.cover),
                                        ),
                                        child: _buildItemImageFallback() ?? const SizedBox.shrink(),
                                      ),
                                    ),
                                    // 🔹 Visual Indicator for Full Image
                                    Positioned(
                                      bottom: 10,
                                      right: 10,
                                      child: GestureDetector(
                                        onTap: () => setState(() => _isImageZoomed = !_isImageZoomed),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                                          child: Icon(_isImageZoomed ? Icons.aspect_ratio : Icons.zoom_out_map, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                    IgnorePointer(
                                      child: Container(
                                        height: _isFullScreen ? 260 : 200,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.8)],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_item.expiryDate.isBefore(DateTime.now()))
                                      Positioned(
                                        top: 30,
                                        right: -30,
                                        child: Transform.rotate(
                                          angle: 0.785,
                                          child: Container(
                                            width: 150,
                                            color: Colors.redAccent,
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: const Center(
                                              child: Text("EXPIRED", 
                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Row(
                                        children: [
                                          _buildCircleAction(
                                            icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                            onTap: () => setState(() => _isFullScreen = !_isFullScreen),
                                          ),
                                          const SizedBox(width: 10),
                                          _buildCircleAction(
                                            icon: Icons.close,
                                            onTap: widget.onClose,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 20,
                                      left: 24,
                                      right: 24,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_item.category?.toUpperCase() ?? "GENERAL", 
                                            style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                          ),
                                          Text(_item.name, 
                                            style: TextStyle(color: Colors.white, fontSize: _isFullScreen ? 34 : 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: PageView(
                                    controller: _pageController,
                                    onPageChanged: (index) {
                                      setState(() => _currentPage = index);
                                      if (index > 0 && _groqAnalysis == null && !_isLoadingAnalysis) {
                                        _runGroqAnalysis();
                                      }
                                    },
                                    children: [
                                      _buildBasicInfoSlide(isLight, textColor),
                                      _buildOverviewNutritionSlide(isLight, textColor),
                                      _buildDedicatedRecipesSlide(isLight, textColor),
                                      _buildDetailedFreshnessSlide(isLight, textColor),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24, top: 8),
                                  child: _buildSlideIndicator(isLight),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              ),
            ),
          ),
          
          // 🔹 Full-Screen Image Viewer Overlay
          if (_isImageViewerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() {
                  _isImageViewerOpen = false;
                  _isImageZoomed = false;
                }),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.9),
                    child: Stack(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: () => setState(() => _isImageZoomed = !_isImageZoomed),
                            onDoubleTap: () => setState(() => _isImageZoomed = !_isImageZoomed),
                            child: InteractiveViewer(
                              panEnabled: true,
                              minScale: 0.1,
                              maxScale: 5.0,
                              child: _buildExpandedImage(),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 40,
                          right: 80,
                          child: InkWell(
                            onTap: () => setState(() => _isImageZoomed = !_isImageZoomed),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_isImageZoomed ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 18),
                                  const SizedBox(width: 4),
                                  Text(_isImageZoomed ? "Original" : "Full View", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 40,
                          right: 20,
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 30),
                              onPressed: () => setState(() {
                                _isImageViewerOpen = false;
                                _isImageZoomed = false;
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }



  Widget _buildExpandedImage() {
    final fit = _isImageZoomed ? BoxFit.none : BoxFit.contain;
    if (_expandedImagePath != null && _expandedImagePath!.isNotEmpty) {
      final file = io.File(_expandedImagePath!);
      if (file.existsSync()) return Image.file(file, fit: fit);
    }
    if (_expandedImageUrl != null && _expandedImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _expandedImageUrl!,
        fit: fit,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
        errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
      );
    }
    return const Icon(Icons.restaurant, size: 100, color: Colors.white54);
  }

  Widget _buildCircleAction({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildBasicInfoSlide(bool isLight, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildModernInfoRow(Icons.branding_watermark, "Brand", _item.brand ?? 'N/A', textColor, isLight),
                  _buildModernInfoRow(Icons.production_quantity_limits, "Quantity", "${_item.quantity} units", textColor, isLight),
                  if (_item.weight != null && _item.weight! > 0)
                    _buildModernInfoRow(Icons.monitor_weight, "WeightBaseline", "${_item.weight} kg", textColor, isLight),
                  _buildModernInfoRow(Icons.calendar_month, "Expiry", DateFormat('MMM dd, yyyy - HH:mm').format(_item.expiryDate), textColor, isLight),
                  _buildModernInfoRow(Icons.info_outline, "Auto-Estimation", (_item.expirySource == 'estimated' || _item.expirySource == 'AI' || _item.expirySource == 'AI_EDIT') ? 'AI' : (_item.expirySource ?? 'Manual'), textColor, isLight),
                  if (_item.reminderDate != null)
                    _buildModernInfoRow(Icons.alarm, "Reminder", DateFormat('MMM dd, yyyy - HH:mm').format(_item.reminderDate!), textColor, isLight),
                  
                  // 🔹 Local Reminder Sync Action
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: InkWell(
                      onTap: () => _pickReminder(isLight),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: (isLight ? Colors.orange : Colors.orangeAccent).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: (isLight ? Colors.orange : Colors.orangeAccent).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alarm_add, size: 18, color: isLight ? Colors.orange : Colors.orangeAccent),
                            const SizedBox(width: 10),
                            Text(
                              _item.reminderDate != null ? "Update Reminder" : "Set Custom Reminder", 
                              style: TextStyle(color: isLight ? Colors.orange.shade900 : Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 🔹 Action Buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note, size: 20),
                    label: const Text("Refine Details"),
                    onPressed: widget.onEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLight ? Colors.teal : Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.white10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_sweep, size: 20),
                    label: const Text("Discard"),
                    onPressed: widget.onDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5252).withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow(IconData icon, String title, String value, Color textColor, bool isLight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isLight ? Colors.teal : Colors.tealAccent).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: isLight ? Colors.teal : Colors.tealAccent),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: isLight ? Colors.black54 : Colors.white54, fontSize: 13)),
              Text(value, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  DecorationImage? _buildItemDecorationImage([BoxFit fit = BoxFit.cover]) {
    if (_item.imagePath != null && _item.imagePath!.isNotEmpty) {
      final file = io.File(_item.imagePath!);
      if (file.existsSync()) {
        return DecorationImage(image: FileImage(file), fit: fit);
      }
    }
    if (_item.imageUrl != null && _item.imageUrl!.isNotEmpty) {
      return DecorationImage(image: NetworkImage(_item.imageUrl!), fit: fit);
    }
    return null;
  }

  Widget? _buildItemImageFallback() {
    if ((_item.imageUrl == null || _item.imageUrl!.isEmpty) && 
        (_item.imagePath == null || _item.imagePath!.isEmpty)) {
      return Center(
        child: Icon(
          Icons.restaurant, 
          size: 80, 
          color: Provider.of<ThemeProvider>(context).currentTheme == ThemeType.light 
            ? Colors.teal.withOpacity(0.5) 
            : Colors.tealAccent.withOpacity(0.3)
        ),
      );
    }
    return null;
  }
}
