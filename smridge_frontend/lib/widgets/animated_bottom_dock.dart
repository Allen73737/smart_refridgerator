import 'package:flutter/material.dart';

class AnimatedBottomDock extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Function(int)? onDoubleTap;

  const AnimatedBottomDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {

    List<IconData> icons = [
      Icons.home,          // 0
      Icons.monitor_heart, // 1 Status
      Icons.kitchen,       // 2 Inventory
      Icons.add_box,       // 3 Add
      Icons.notifications, // 4
      Icons.settings,      // 5
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(icons.length, (index) {

            int visualIndex = currentIndex;
            if (currentIndex == 6) visualIndex = 1; // Analytics maps to Status
            if (currentIndex > 6) visualIndex = 5;  // Profile/Help/Privacy map to Settings

            bool active = visualIndex == index;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: GestureDetector(
                onTap: () => onTap(index),
                onDoubleTap: () => onDoubleTap?.call(index),
                child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, active ? -10 : 0, 0),
              padding: EdgeInsets.all(active ? 12 : 8),
              decoration: BoxDecoration(
                color: active ? Colors.tealAccent.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: active ? Border.all(color: Colors.tealAccent.withOpacity(0.5), width: 1.5) : Border.all(color: Colors.transparent),
                boxShadow: active
                    ? [BoxShadow(color: Colors.tealAccent.withOpacity(0.6), blurRadius: 20, spreadRadius: 2)]
                    : [],
              ),
              child: AnimatedScale(
                scale: active ? 1.3 : 1.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                child: AnimatedRotation(
                  turns: active ? 0.0 : -0.05,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    icons[index],
                    color: active ? Colors.tealAccent : Colors.white54,
                    shadows: active ? [const Shadow(color: Colors.white, blurRadius: 10)] : null,
                  ),
                  ),
                ),
              ),
            ));
          }),
        ),
      ),
    );
  }
}
