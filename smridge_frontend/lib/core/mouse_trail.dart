import 'package:flutter/material.dart';

class MouseTrail extends StatefulWidget {
  final Widget child;
  const MouseTrail({super.key, required this.child});

  @override
  State<MouseTrail> createState() => _MouseTrailState();
}

class _MouseTrailState extends State<MouseTrail> {
  Offset? position;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (event) {
        setState(() => position = event.position);
      },
      child: Stack(
        children: [
          widget.child,
          if (position != null)
            Positioned(
              left: position!.dx - 30,
              top: position!.dy - 30,
              child: IgnorePointer(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.blueAccent.withOpacity(0.4),
                        Colors.transparent
                      ],
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}
