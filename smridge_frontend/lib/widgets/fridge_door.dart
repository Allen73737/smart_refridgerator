import 'package:flutter/material.dart';

class FridgeDoor extends StatelessWidget {
  final double height;
  final double angle;
  final Widget embeddedChild;
  final Function(double) onDrag;
  final VoidCallback onRelease;

  const FridgeDoor({
    super.key,
    required this.height,
    required this.angle,
    required this.embeddedChild,
    required this.onDrag,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) =>
          onDrag(details.delta.dx),
      onHorizontalDragEnd: (_) => onRelease(),
      child: Transform(
        alignment: Alignment.centerLeft,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(angle),
        child: Container(
          width: 320,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF6E7C86),
                Color(0xFF2F3940),
              ],
            ),
          ),
          child: Stack(
            children: [

              Positioned(
                left: 6,
                top: height / 2 - 40,
                child: Container(
                  width: 12,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(6),
                    color: Colors.grey[300],
                  ),
                ),
              ),

              embeddedChild,
            ],
          ),
        ),
      ),
    );
  }
}
