import 'package:flutter/material.dart';

class AnimatedGauge extends StatelessWidget {
  final double value;
  final String label;
  final Color color;

  const AnimatedGauge({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween(begin: 0.0, end: value),
      duration: const Duration(milliseconds: 800),
      builder: (context, double val, _) {
        return Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: val / 100,
                    strokeWidth: 6,
                    color: color,
                    backgroundColor:
                        Colors.white12,
                  ),
                ),
                Text(
                  val.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label),
          ],
        );
      },
    );
  }
}
