import 'package:flutter/material.dart';

class FridgeShelf extends StatelessWidget {
  final double depth;

  const FridgeShelf({super.key, required this.depth});

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.identity()
        ..translate(0.0, depth * 20),
      child: Container(
        height: 8,
        margin:
            const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius:
              BorderRadius.circular(4),
        ),
      ),
    );
  }
}
