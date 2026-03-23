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

class _InventoryListScreenState extends State<InventoryListScreen> {
  String searchQuery = "";
  String sortBy = "name"; // name, expiry, quantity

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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Detailed Inventory", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, color: textColor),
            onSelected: (val) => setState(() => sortBy = val),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'name', child: Text("Sort by Name")),
              const PopupMenuItem(value: 'expiry', child: Text("Sort by Expiry")),
              const PopupMenuItem(value: 'quantity', child: Text("Sort by Quantity")),
            ],
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
                  : ListView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final freshnessColor = _getFreshnessColor(item);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isLight ? Colors.white : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: freshnessColor.withOpacity(0.3), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: freshnessColor.withOpacity(0.1),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                              child: ListTile(
                                onTap: () {
                                  if (widget.onItemTap != null) widget.onItemTap!(item);
                                },
                                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                leading: _buildItemImage(item, freshnessColor),
                                title: Text(item.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      "Qty: ${item.quantity}  •  ${item.category ?? 'Others'}",
                                      style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Expires: ${item.expiryDate.toString().split(' ')[0]}",
                                      style: TextStyle(color: freshnessColor, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                      onPressed: () {
                                        // 🚀 Redirect: Close this screen so the Home screen can show the edit flow
                                        Navigator.pop(context); 
                                        widget.onEdit(widget.inventory.indexOf(item), item);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () {
                                        widget.onDelete(widget.inventory.indexOf(item));
                                        // 🔄 Local Sync: Update the list immediately
                                        setState(() {}); 
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: (50 * (index % 10)).ms).slideX(begin: 0.1, end: 0);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(InventoryItem item, Color freshnessColor) {
    ImageProvider? provider;
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      final file = File(item.imagePath!);
      if (file.existsSync()) provider = FileImage(file);
    }
    if (provider == null && item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      provider = NetworkImage(item.imageUrl!);
    }

    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: freshnessColor.withOpacity(0.5), width: 1.5),
        image: provider != null ? DecorationImage(image: provider, fit: BoxFit.cover) : null,
      ),
      child: provider == null ? Icon(Icons.fastfood, color: freshnessColor.withOpacity(0.5)) : null,
    );
  }
}
