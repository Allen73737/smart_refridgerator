import 'dart:math';
import 'package:flutter/material.dart';

class LiquidWaveBar extends StatefulWidget {
  final double percentage;
  const LiquidWaveBar({super.key, required this.percentage});

  @override
  State<LiquidWaveBar> createState() => _LiquidWaveBarState();
}

class _LiquidWaveBarState extends State<LiquidWaveBar>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return CustomPaint(
          painter: WavePainter(widget.percentage, controller.value),
          child: Container(
            height: 120,
          ),
        );
      },
    );
  }
}

class WavePainter extends CustomPainter {
  final double percentage;
  final double animationValue;

  WavePainter(this.percentage, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.green, Colors.tealAccent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final waveHeight = 10.0;
    final baseHeight = size.height * (1 - percentage);

    path.moveTo(0, baseHeight);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        baseHeight +
            sin((i / size.width * 2 * pi) + animationValue * 2 * pi) *
                waveHeight,
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
