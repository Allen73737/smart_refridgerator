import 'dart:io';
import 'package:flutter/material.dart';
import '../models/inventory_item.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class InventoryListScreen extends StatelessWidget {

  final List<InventoryItem> inventory;

  const InventoryListScreen({
    super.key,
    required this.inventory,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    final isDark = themeType == ThemeType.dark;
    
    Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: isLight ? const Color(0xFFF3F6F8) : (isDark ? Colors.black : const Color(0xFF0E1215)),
      appBar: AppBar(
        backgroundColor: isLight ? Colors.teal : Colors.black,
        title: Text("Inventory List", style: TextStyle(color: isLight ? Colors.white : Colors.white)),
        iconTheme: IconThemeData(color: isLight ? Colors.white : Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: inventory.length,
        itemBuilder: (_, index) {

          final item = inventory[index];

          return Card(
            color: isLight ? Colors.white : Colors.white10,
            elevation: isLight ? 2 : 0,
            margin:
                const EdgeInsets.only(
                    bottom: 16),
            child: ListTile(
              leading: item.imagePath != null
                  ? Image.file(
                      File(item.imagePath!),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                  : Icon(
                      Icons.inventory,
                      color: isLight ? Colors.teal : Colors.white),
              title: Text(item.name,
                  style: TextStyle(
                      color: textColor)),
              subtitle: Text(
                "Qty: ${item.quantity}\nExpiry: ${item.expiryDate.toLocal()}",
                style: TextStyle(
                    color: isLight ? Colors.black54 : Colors.white70),
              ),
            ),
          );
        },
      ),
    );
  }
}
