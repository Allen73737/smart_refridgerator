import 'package:flutter/material.dart';
import '../models/inventory_item.dart';

class FridgeShelves extends StatelessWidget {

  final List<InventoryItem> inventory;
  final Function(int) onDelete;

  const FridgeShelves({
    super.key,
    required this.inventory,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.only(top: 120),
        child: GridView.builder(
          itemCount: inventory.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {

            final item = inventory[index];

            return TweenAnimationBuilder(
              tween: Tween(begin: 0.8, end: 1),
              duration:
                  const Duration(milliseconds: 400),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale.toDouble(),
                  child: child,
                );
              },
              child: buildItemCard(item, index),
            );
          },
        ),
      ),
    );
  }

  Widget buildItemCard(
      InventoryItem item, int index) {

    Color borderColor;

    if (item.isExpired) {
      borderColor = Colors.red;
    } else if (item.isCritical) {
      borderColor = Colors.orange;
    } else {
      borderColor = Colors.green;
    }

    return GestureDetector(
      onLongPress: () => onDelete(index),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [

            Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 4),

            Text(
              "${item.quantity} pcs",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              item.isExpired
                  ? "Expired"
                  : "${item.daysLeft} days",
              style: TextStyle(
                fontSize: 11,
                color: borderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
