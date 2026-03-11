import 'package:flutter/material.dart';
import 'dart:math';

class Hover3D extends StatefulWidget {
  final Widget child;
  const Hover3D({super.key, required this.child});

  @override
  State<Hover3D> createState() => _Hover3DState();
}

class _Hover3DState extends State<Hover3D> {
  double dx = 0;
  double dy = 0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        final size = context.size!;
        setState(() {
          dx = (event.localPosition.dx - size.width / 2) / size.width;
          dy = (event.localPosition.dy - size.height / 2) / size.height;
        });
      },
      onExit: (_) {
        setState(() {
          dx = 0;
          dy = 0;
        });
      },
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(-dy * pi / 12)
          ..rotateY(dx * pi / 12),
        child: widget.child,
      ),
    );
  }
}
