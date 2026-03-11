import 'package:flutter/material.dart';

class ReflectionSweep extends StatefulWidget {
  const ReflectionSweep({super.key});

  @override
  State<ReflectionSweep> createState() =>
      _ReflectionSweepState();
}

class _ReflectionSweepState
    extends State<ReflectionSweep>
    with SingleTickerProviderStateMixin {

  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Positioned.fill(
          child: FractionallySizedBox(
            alignment: Alignment(
                controller.value * 2 - 1, 0),
            widthFactor: 0.3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white
                        .withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
