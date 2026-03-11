import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LiquidFreshnessBar extends StatelessWidget {
  final double value;
  const LiquidFreshnessBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            width: MediaQuery.of(context).size.width * value * 0.8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Colors.green, Colors.tealAccent],
              ),
            ),
          ).animate().fade().slideX(begin: -0.2),
        ],
      ),
    );
  }
}
