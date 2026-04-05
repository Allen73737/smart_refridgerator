import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';

class LiquidCard extends StatefulWidget {
  final Widget child;
  const LiquidCard({super.key, required this.child});

  @override
  State<LiquidCard> createState() => _LiquidCardState();
}

class _LiquidCardState extends State<LiquidCard>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: Stack(
            children: [

              // Dynamic distortion overlay
              CustomPaint(
                painter: DistortionPainter(controller.value),
                child: Container(),
              ),

              // Optimized blur for better performance
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(),
              ),

              // Glass gradient
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                  ),
                ),
                child: child,
              ),
            ],
          ),
        );
      },
      child: RepaintBoundary(child: widget.child),
    );
  }
}

class DistortionPainter extends CustomPainter {
  final double animationValue;
  DistortionPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02);

    for (double i = 0; i < size.width; i += 20) {
      double offset =
          sin((i / size.width * 2 * pi) + animationValue * 2 * pi) * 5;

      canvas.drawRect(
        Rect.fromLTWH(i, offset, 10, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
