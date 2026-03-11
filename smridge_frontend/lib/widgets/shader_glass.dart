import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ShaderGlass extends StatefulWidget {
  final Widget child;
  const ShaderGlass({super.key, required this.child});

  @override
  State<ShaderGlass> createState() => _ShaderGlassState();
}

class _ShaderGlassState extends State<ShaderGlass>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  FragmentProgram? program;
  FragmentShader? shader;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();

    if (!kIsWeb) {
      loadShader();
    }
  }

  Future<void> loadShader() async {
    program =
        await FragmentProgram.fromAsset('shaders/glass_distortion.frag');
    shader = program!.fragmentShader();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 On Web → fallback glass effect
    if (kIsWeb || shader == null) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ShaderPainter(
            shader: shader!,
            time: _controller.value * 10,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final FragmentShader shader;
  final double time;

  _ShaderPainter({
    required this.shader,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, 0.5)
      ..setFloat(4, 0.5);

    final paint = Paint()..shader = shader;

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
