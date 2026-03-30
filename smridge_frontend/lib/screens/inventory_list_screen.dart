import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../providers/theme_provider.dart';
import '../widgets/wave_background.dart';
import '../services/socket_service.dart'; // 📡 Added for real-time sync

class InventoryListScreen extends StatefulWidget {
  final List<InventoryItem> inventory;
  final Function(int) onDelete;
  final Function(int, InventoryItem) onEdit;
  final Function(InventoryItem)? onItemTap;

  const InventoryListScreen({
    super.key, 
    required this.inventory,
    required this.onDelete,
    required this.onEdit,
    this.onItemTap,
  });

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

enum ViewMode { list, cards }

class _InventoryListScreenState extends State<InventoryListScreen> {
  String searchQuery = "";
  String sortBy = "name"; // name, expiry, quantity
  ViewMode _viewMode = ViewMode.cards;
  
  // Selection Mode
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    // 📡 Listen for remote inventory changes (AI updates, other devices)
    SocketService.on('inventory_update', _handleInventoryUpdate);
  }

  @override
  void dispose() {
    SocketService.off('inventory_update');
    super.dispose();
  }

  void _handleInventoryUpdate(dynamic data) {
    if (mounted) {
      print("📡 InventoryListScreen: Received real-time update, refreshing UI...");
      setState(() {}); 
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIndices.add(index);
        _isSelectionMode = true;
      }
    });
  }

  void _deleteSelected() {
    final sortedIndices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
    for (var index in sortedIndices) {
      widget.onDelete(index);
    }
    setState(() {
      _selectedIndices.clear();
      _isSelectionMode = false;
    });
  }

  Color _getFreshnessColor(InventoryItem item) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(item.expiryDate.year, item.expiryDate.month, item.expiryDate.day);
    
    if (exp.isBefore(today)) return Colors.redAccent;
    final diff = exp.difference(today).inDays;
    if (diff <= 3) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLight = themeProvider.currentTheme == ThemeType.light;
    Color textColor = isLight ? Colors.black87 : Colors.white;

    List<InventoryItem> filteredList = widget.inventory.where((item) => 
      item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
      (item.category ?? "").toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    if (sortBy == "name") {
      filteredList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (sortBy == "expiry") {
      filteredList.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    } else if (sortBy == "quantity") {
      filteredList.sort((a, b) => b.quantity.compareTo(a.quantity));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode 
          ? IconButton(icon: Icon(Icons.close, color: textColor), onPressed: () => setState(() { _isSelectionMode = false; _selectedIndices.clear(); }))
          : IconButton(icon: Icon(Icons.arrow_back_ios, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Text(_isSelectionMode ? "${_selectedIndices.length} Selected" : "Detailed Inventory", 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          if (!_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.tealAccent, size: 28),
              onPressed: () {
                Navigator.pop(context, "TRIGGER_ADD"); // 🚀 Signals HomeScreen to open Add Tab
              },
            ),
            IconButton(
              icon: Icon(_viewMode == ViewMode.list ? Icons.grid_view_rounded : Icons.view_list_rounded, color: textColor),
              onPressed: () => setState(() => _viewMode = _viewMode == ViewMode.list ? ViewMode.cards : ViewMode.list),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.sort, color: textColor),
              onSelected: (val) => setState(() => sortBy = val),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'name', child: Text("Sort by Name")),
                const PopupMenuItem(value: 'expiry', child: Text("Sort by Expiry")),
                const PopupMenuItem(value: 'quantity', child: Text("Sort by Quantity")),
              ],
            ),
          ] else 
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: _deleteSelected,
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isLight ? const Color(0xFFF3F6F8) : Colors.black,
              gradient: isLight ? null : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F2027), Color(0xFF203A43)],
              ),
            ),
          ),
          const Positioned.fill(child: WaveBackground()),

          SafeArea(
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => searchQuery = val),
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: "Search ingredients...",
                            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                            border: InputBorder.none,
                            icon: Icon(Icons.search, color: textColor.withOpacity(0.5)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: filteredList.isEmpty 
                  ? Center(child: Text("No items found", style: TextStyle(color: textColor.withOpacity(0.5))))
                  : _viewMode == ViewMode.list 
                    ? _buildListView(filteredList, isLight, textColor)
                    : _buildCardView(filteredList, isLight, textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<InventoryItem> items, bool isLight, Color textColor) {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final freshnessColor = _getFreshnessColor(item);
        final isSelected = _selectedIndices.contains(index);
        
        return Dismissible(
          key: Key("list_${item.id}"),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
          ),
          onDismissed: (_) {
            widget.onDelete(widget.inventory.indexOf(item));
            setState(() {});
          },
          child: GestureDetector(
            onLongPress: () => _toggleSelection(index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.tealAccent.withOpacity(0.1) : (isLight ? Colors.white : Colors.white.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? Colors.tealAccent : freshnessColor.withOpacity(0.3), width: 1.5),
              ),
              child: ListTile(
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(index);
                  } else if (widget.onItemTap != null) {
                    widget.onItemTap!(item);
                  }
                },
                leading: Stack(
                  children: [
                    _buildItemImage(item, freshnessColor),
                    if (isSelected) 
                      const Positioned.fill(child: Center(child: Icon(Icons.check_circle, color: Colors.tealAccent))),
                  ],
                ),
                title: Text(item.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Text("Qty: ${item.quantity} • Expires: ${item.expiryDate.toString().split(' ')[0]}", 
                  style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                trailing: _isSelectionMode ? null : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blueAccent), onPressed: () { Navigator.pop(context); widget.onEdit(widget.inventory.indexOf(item), item); }),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent), onPressed: () { widget.onDelete(widget.inventory.indexOf(item)); setState(() {}); }),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(delay: (50 * (index % 10)).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutBack);
      },
    );
  }

  Widget _buildCardView(List<InventoryItem> items, bool isLight, Color textColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final freshnessColor = _getFreshnessColor(item);
        final isSelected = _selectedIndices.contains(index);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _toggleSelection(index),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(index);
            } else if (widget.onItemTap != null) {
              widget.onItemTap!(item);
            }
          },
          child: Container(
            height: 220,
            margin: const EdgeInsets.only(bottom: 25),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: isSelected ? Colors.tealAccent : freshnessColor.withOpacity(0.2), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  // PHOTO SECTION (LEFT)
                  SizedBox(
                    width: 160,
                    height: double.infinity,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _buildItemImage(item, freshnessColor, size: double.infinity, radius: 0),
                        ),
                        if (isSelected) 
                          Container(
                            color: Colors.tealAccent.withOpacity(0.3), 
                            child: const Center(child: Icon(Icons.check_circle, color: Colors.white, size: 40)),
                          ),
                      ],
                    ),
                  ),
                  
                  // INFO SECTIONS (RIGHT)
                  Expanded(
                    child: Stack(
                      children: [
                        PageView(
                          children: [
                            _buildCardSlide1(item, textColor, freshnessColor),
                            _buildCardSlide2(item, textColor, isLight),
                            _buildCardSlide3(item, textColor),
                          ],
                        ),
                        Positioned(
                          bottom: 15,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMiniDot(true),
                              const SizedBox(width: 4),
                              _buildMiniDot(false),
                              const SizedBox(width: 4),
                              _buildMiniDot(false),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().scale(
          begin: const Offset(0.01, 0.01), 
          delay: (100 * (index % 5)).ms, 
          duration: 400.ms, 
          curve: Curves.easeOutBack,
        );
      },
    );
  }

  Widget _buildCardSlide1(InventoryItem item, Color textColor, Color freshnessColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.category?.toUpperCase() ?? "GENERAL", style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          Text(item.name, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: freshnessColor),
              const SizedBox(width: 4),
              Text(item.expiryDate.difference(DateTime.now()).inDays < 0 ? "EXPIRED" : "${item.expiryDate.difference(DateTime.now()).inDays} days left", 
                style: TextStyle(color: freshnessColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerRight, child: Icon(Icons.chevron_right, color: Colors.white24, size: 20)),
        ],
      ),
    );
  }

  Widget _buildCardSlide2(InventoryItem item, Color textColor, bool isLight) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMiniRow(Icons.production_quantity_limits, "Qty: ${item.quantity}", textColor),
          const SizedBox(height: 10),
          _buildMiniRow(Icons.branding_watermark, item.brand ?? "No Brand", textColor),
          const SizedBox(height: 10),
          _buildMiniRow(Icons.monitor_weight, item.weight != null ? "${item.weight}kg" : "N/A", textColor),
          const Spacer(),
          const Align(alignment: Alignment.centerLeft, child: Icon(Icons.chevron_left, color: Colors.white24, size: 20)),
        ],
      ),
    );
  }

  Widget _buildCardSlide3(InventoryItem item, Color textColor) {
    String displayNotes = item.notes ?? "";

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("NOTES & INSIGHTS", style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                displayNotes,
                style: TextStyle(
                  color: textColor.withOpacity(0.9), 
                  fontSize: 13, 
                  height: 1.6, 
                  fontStyle: item.notes == null ? FontStyle.italic : FontStyle.normal,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: Icon(Icons.chevron_left, color: Colors.white24, size: 20)),
        ],
      ),
    );
  }

  Widget _buildMiniDot(bool active) {
    return Container(
      width: active ? 12 : 4,
      height: 4,
      decoration: BoxDecoration(
        color: active ? Colors.tealAccent : Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildMiniRow(IconData icon, String text, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: textColor, fontSize: 12)),
      ],
    );
  }

  Widget _buildItemImage(InventoryItem item, Color freshnessColor, {double size = 55, double radius = 10}) {
    ImageProvider? provider;
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      final file = File(item.imagePath!);
      if (file.existsSync()) provider = FileImage(file);
    }
    if (provider == null && item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      provider = NetworkImage(item.imageUrl!);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(radius),
        image: provider != null ? DecorationImage(image: provider, fit: BoxFit.cover) : null,
      ),
      child: provider == null ? Center(child: Icon(Icons.fastfood, color: freshnessColor.withOpacity(0.5), size: size/2)) : null,
    );
  }
}
