import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/inventory_item.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _expandedImageUrl;
  String? _expandedImagePath;

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
    // No automatic trigger here to save initial load, 
    // it will trigger on swipe in onPageChanged.
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) { setState(() => _isLoadingAnalysis = false); return; }
    final result = await ApiService.analyzeFoodItem(
      name: widget.item.name,
      token: token,
      expiryDate: widget.item.expiryDate.toIso8601String(),
    );
    if (mounted) setState(() { _groqAnalysis = result; _isLoadingAnalysis = false; });
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
            Text(a['overview']?.toString() ?? "Gathering overview...", 
              style: TextStyle(color: textColor, fontSize: 14, height: 1.6, letterSpacing: 0.2)),
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
                      title: Text(
                        r['title'] ?? "Recipe ${index + 1}",
                        style: TextStyle(
                          color: isLight ? Colors.teal.shade700 : Colors.tealAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                        ...(r['steps'] as List<dynamic>? ?? []).asMap().entries.map((entry) => 
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${entry.key + 1}. ", style: TextStyle(color: isLight ? Colors.teal : Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                Expanded(child: Text("${entry.value}", style: TextStyle(color: textColor, fontSize: 13, height: 1.4))),
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
            _sectionHeader(Icons.psychology, "AI Logic", isLight ? Colors.teal : Colors.tealAccent),
            const SizedBox(height: 8),
            Text(a['freshness_explanation']?.toString() ?? "", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            _sectionHeader(Icons.tips_and_updates, "Storage Guru", isLight ? Colors.teal : Colors.tealAccent),
            const SizedBox(height: 8),
            Text(a['storage_advice']?.toString() ?? "", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13, height: 1.4)),
          ],
        ),
      ),
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
                                          _expandedImageUrl = widget.item.imageUrl;
                                          _expandedImagePath = widget.item.imagePath;
                                          _isImageViewerOpen = true;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: 400.ms,
                                        height: _isFullScreen ? 260 : 200,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          image: _buildItemDecorationImage(),
                                        ),
                                        child: _buildItemImageFallback() ?? const SizedBox.shrink(),
                                      ),
                                    ),
                                    Container(
                                      height: _isFullScreen ? 260 : 200,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.8)],
                                        ),
                                      ),
                                    ),
                                    if (widget.item.expiryDate.isBefore(DateTime.now()))
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
                                          Text(widget.item.category?.toUpperCase() ?? "GENERAL", 
                                            style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                          ),
                                          Text(widget.item.name, 
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
                onTap: () => setState(() => _isImageViewerOpen = false),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.9),
                    child: Stack(
                      children: [
                        Center(
                          child: InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: _buildExpandedImage(),
                          ),
                        ),
                        Positioned(
                          top: 40,
                          right: 20,
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 30),
                              onPressed: () => setState(() => _isImageViewerOpen = false),
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
    if (_expandedImagePath != null && _expandedImagePath!.isNotEmpty) {
      final file = io.File(_expandedImagePath!);
      if (file.existsSync()) return Image.file(file, fit: BoxFit.contain);
    }
    if (_expandedImageUrl != null && _expandedImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _expandedImageUrl!,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.error, size: 50, color: Colors.white),
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
                  _buildModernInfoRow(Icons.branding_watermark, "Brand", widget.item.brand ?? 'N/A', textColor, isLight),
                  _buildModernInfoRow(Icons.production_quantity_limits, "Quantity", "${widget.item.quantity} units", textColor, isLight),
                  if (widget.item.weight != null && widget.item.weight! > 0)
                    _buildModernInfoRow(Icons.monitor_weight, "WeightBaseline", "${widget.item.weight} kg", textColor, isLight),
                  _buildModernInfoRow(Icons.calendar_month, "Expiry", widget.item.expiryDate.toLocal().toString().split(' ')[0], textColor, isLight),
                  _buildModernInfoRow(Icons.info_outline, "Auto-Estimation", widget.item.expirySource ?? 'Manual', textColor, isLight),
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

  DecorationImage? _buildItemDecorationImage() {
    if (widget.item.imagePath != null && widget.item.imagePath!.isNotEmpty) {
      final file = io.File(widget.item.imagePath!);
      if (file.existsSync()) {
        return DecorationImage(image: FileImage(file), fit: BoxFit.cover);
      }
    }
    if (widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty) {
      return DecorationImage(image: NetworkImage(widget.item.imageUrl!), fit: BoxFit.cover);
    }
    return null;
  }

  Widget? _buildItemImageFallback() {
    if ((widget.item.imageUrl == null || widget.item.imageUrl!.isEmpty) && 
        (widget.item.imagePath == null || widget.item.imagePath!.isEmpty)) {
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
