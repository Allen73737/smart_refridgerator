import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/inventory_item.dart';

class FridgeInterior extends StatefulWidget {
  final double bottomDoorAngle;
  final List<InventoryItem> inventory;
  final Function(int) onDelete;

  const FridgeInterior({
    super.key,
    required this.bottomDoorAngle,
    required this.inventory,
    required this.onDelete,
  });

  @override
  State<FridgeInterior> createState() =>
      _FridgeInteriorState();
}

class _FridgeInteriorState
    extends State<FridgeInterior>
    with SingleTickerProviderStateMixin {

  late Timer timer;
  double lightPulse = 0;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) {
        setState(() {
          lightPulse =
              (sin(DateTime.now()
                          .millisecondsSinceEpoch /
                      300) +
                  1) /
                  2;
        });
      },
    );
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    double doorOpenRatio =
        (widget.bottomDoorAngle /
                (pi / 1.05))
            .clamp(0.0, 1.0);

    double interiorGlow =
        doorOpenRatio * (0.6 + lightPulse * 0.4);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              Colors.white.withOpacity(
                  interiorGlow * 0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: widget.inventory.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          itemBuilder: (context, index) {

            final item =
                widget.inventory[index];

            Color expiryColor;

            if (item.isExpired) {
              expiryColor = Colors.red;
            } else if (item.daysLeft <= 2) {
              expiryColor = Colors.orange;
            } else {
              expiryColor = Colors.green;
            }

            return GestureDetector(
              onLongPress: () =>
                  widget.onDelete(index),
              child: Container(
                margin:
                    const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                          12),
                  color: Colors.white
                      .withOpacity(0.15),
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [

                    Text(
                      item.name,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                        height: 4),

                    Text(
                      "${item.units} units",
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(
                        height: 4),

                    Text(
                      item.isExpired
                          ? "Expired"
                          : "${item.daysLeft} days left",
                      style: TextStyle(
                        color:
                            expiryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
