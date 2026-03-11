import 'package:flutter/material.dart';

class StatusOverlay extends StatefulWidget {
  const StatusOverlay({super.key});

  @override
  State<StatusOverlay> createState() =>
      _StatusOverlayState();
}

class _StatusOverlayState
    extends State<StatusOverlay>
    with SingleTickerProviderStateMixin {

  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity:
          Tween(begin: 0.7, end: 1.0)
              .animate(controller),
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: const Center(
          child: Text(
            "FRIDGE STATUS",
            style: TextStyle(
                fontSize: 22,
                letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}
