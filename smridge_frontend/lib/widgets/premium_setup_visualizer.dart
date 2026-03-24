import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumSetupVisualizer extends StatefulWidget {
  const PremiumSetupVisualizer({super.key});

  @override
  State<PremiumSetupVisualizer> createState() => _PremiumSetupVisualizerState();
}

class _PremiumSetupVisualizerState extends State<PremiumSetupVisualizer> with SingleTickerProviderStateMixin {
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
    return SizedBox(
      height: 220,
      width: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 🔹 Outer Tech Rings
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(200, 200),
                  painter: _TechRingPainter(
                    color: Colors.tealAccent.withOpacity(0.2),
                    segments: 8,
                    gap: 0.4,
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_controller.value * 2 * math.pi * 1.5,
                child: CustomPaint(
                  size: const Size(160, 160),
                  painter: _TechRingPainter(
                    color: Colors.white.withOpacity(0.1),
                    segments: 12,
                    gap: 0.2,
                    strokeWidth: 1,
                  ),
                ),
              );
            },
          ),

          // 🔹 Pulsing Pulse Rings
          ...List.generate(3, (index) => 
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.tealAccent.withOpacity(0.3), width: 1.5),
              ),
            ).animate(onPlay: (c) => c.repeat()).scale(
              duration: 2500.ms,
              delay: (index * 800).ms,
              begin: const Offset(0.3, 0.3),
              end: const Offset(1.1, 1.1),
              curve: Curves.easeOutCirc,
            ).fadeOut(duration: 2500.ms)
          ),

          // 🔹 Center Core
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.tealAccent.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0A0F14),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.tealAccent.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.wifi_tethering,
                color: Colors.tealAccent,
                size: 48,
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
          ),

          // 🔹 Moving Particles (Simulated with simple dots)
          ...List.generate(4, (index) {
            final angle = (index * math.pi / 2) + (math.pi / 4);
            return _FloatingParticle(
              angle: angle,
              radius: 90,
              delay: (index * 400).ms,
            );
          }),
        ],
      ),
    );
  }
}

class _FloatingParticle extends StatelessWidget {
  final double angle;
  final double radius;
  final Duration delay;

  const _FloatingParticle({required this.angle, required this.radius, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: 3.seconds,
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final currentRadius = radius + (math.sin(value * math.pi * 2) * 10);
        return Transform.translate(
          offset: Offset(math.cos(angle) * currentRadius, math.sin(angle) * currentRadius),
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.tealAccent,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {},
    ).animate(onPlay: (c) => c.repeat()).fadeIn().fadeOut(delay: 2.seconds);
  }
}

class _TechRingPainter extends CustomPainter {
  final Color color;
  final int segments;
  final double gap;
  final double strokeWidth;

  _TechRingPainter({
    required this.color,
    this.segments = 8,
    this.gap = 0.5,
    this.strokeWidth = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final segmentAngle = (2 * math.pi) / segments;

    for (int i = 0; i < segments; i++) {
        final startAngle = i * segmentAngle;
        final sweepAngle = segmentAngle * (1 - gap);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
