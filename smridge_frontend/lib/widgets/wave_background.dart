import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class WaveBackground extends StatefulWidget {
  const WaveBackground({super.key});

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _WavePainter(_controller.value, themeProvider.currentTheme),
          size: Size.infinite,
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final ThemeType themeType;

  _WavePainter(this.animationValue, this.themeType);

  @override
  void paint(Canvas canvas, Size size) {
    Color c1, c2, c3;

    if (themeType == ThemeType.light) {
      c1 = Colors.blueAccent.withOpacity(0.05);
      c2 = Colors.lightBlue.withOpacity(0.15);
      c3 = Colors.cyan.withOpacity(0.08);
    } else if (themeType == ThemeType.dark) {
      c1 = Colors.white.withOpacity(0.02);
      c2 = Colors.grey.withOpacity(0.05);
      c3 = Colors.white.withOpacity(0.03);
    } else {
      // Default Glassmorphic Blue
      c1 = Colors.tealAccent.withOpacity(0.05);
      c2 = const Color(0xFF0D2B4D).withOpacity(0.15);
      c3 = Colors.cyanAccent.withOpacity(0.08);
    }

    var paint1 = Paint()
      ..color = c1
      ..style = PaintingStyle.fill;

    var paint2 = Paint()
      ..color = c2
      ..style = PaintingStyle.fill;
      
    var paint3 = Paint()
      ..color = c3
      ..style = PaintingStyle.fill;

    _drawWave(canvas, size, paint2, 1.2, 0.5, 0);
    _drawWave(canvas, size, paint1, 1.0, 0.4, 0.3);
    _drawWave(canvas, size, paint3, 1.5, 0.6, 0.6);
  }

  void _drawWave(Canvas canvas, Size size, Paint paint, double speedMultiplier, double heightRatio, double phaseOffset) {
    var path = Path();
    path.moveTo(0, size.height);

    for (double i = 0; i <= size.width; i++) {
      // Calculate sine wave Y position
      double y = sin((i / size.width * 2 * pi) + (animationValue * 2 * pi * speedMultiplier) + phaseOffset);
      y = y * 40 + (size.height * heightRatio);
      path.lineTo(i, y);
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
