import 'package:flutter/material.dart';

class InventoryListMode extends StatelessWidget {
  final List inventory;

  const InventoryListMode({
    super.key,
    required this.inventory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: ListView.builder(
        itemCount: inventory.length,
        itemBuilder: (context, index) {
          final item = inventory[index];

          return ListTile(
            leading:
                const Icon(Icons.local_drink),
            title: Text(item.name),
            subtitle: Text(
                "Expires in ${item.daysLeft} days"),
          );
        },
      ),
    );
  }
}
