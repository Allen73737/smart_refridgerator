import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/haptic_service.dart';

class AnimatedBottomDock extends StatefulWidget {
  final int currentIndex;
  final int notificationCount;
  final List<GlobalKey>? itemKeys;
  final Function(int) onTap;
  final Function(int)? onDoubleTap;

  const AnimatedBottomDock({
    super.key,
    required this.currentIndex,
    this.notificationCount = 0,
    this.itemKeys,
    required this.onTap,
    this.onDoubleTap,
  });

  @override
  State<AnimatedBottomDock> createState() => _AnimatedBottomDockState();
}

class _AnimatedBottomDockState extends State<AnimatedBottomDock> with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  int? _lastIndex;
  int? _targetIndex;
  bool _isRippleActive = false;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        setState(() {});
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _isRippleActive = false;
            _lastIndex = _targetIndex;
          });
        }
      });
    _lastIndex = _resolveVisualIndex(widget.currentIndex);
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  void _triggerRipple(int index) {
    if (_rippleController.isAnimating) return;
    
    _targetIndex = index;
    _isRippleActive = true;
    _rippleController.forward(from: 0.0);
    widget.onTap(index);
  }

  int _resolveVisualIndex(int rawIndex) {
    if (rawIndex == 6) return 1;
    if (rawIndex == 10) return 4; 
    if (rawIndex >= 4) return 4;
    return rawIndex;
  }
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> navItems = [
      {'icon': Icons.home, 'label': 'Home'},
      {'icon': Icons.insert_chart_outlined, 'label': 'Status'}, // ⚡ Index 1: Activity -> Status
      {'icon': Icons.kitchen, 'label': 'Fridge'},
      {'icon': Icons.add_circle_outline, 'label': 'Add'}, // ⚡ Index 3: Scan -> Add
      {'icon': Icons.settings, 'label': 'Settings'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white12, width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, spreadRadius: 10)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🌊 Smooth Teal Ripple Layer
            if (_isRippleActive && _lastIndex != null && _targetIndex != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: RipplePainter(
                    progress: _rippleController.value,
                    startIndex: _lastIndex!,
                    endIndex: _targetIndex!,
                    itemCount: navItems.length,
                  ),
                ),
              ),
            
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(navItems.length, (index) {
                  int visualIndex = _resolveVisualIndex(widget.currentIndex);
                  bool active = visualIndex == index;

                  return GestureDetector(
                    key: (widget.itemKeys != null && index < widget.itemKeys!.length) ? widget.itemKeys![index] : null,
                    onTap: () {
                      HapticService.light();
                      _triggerRipple(index);
                    },
                    onDoubleTap: () {
                      HapticService.heavy();
                      widget.onDoubleTap?.call(index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: EdgeInsets.symmetric(
                        vertical: 12, 
                        horizontal: active ? 20 : 12
                      ),
                      decoration: BoxDecoration(
                        color: active ? Colors.tealAccent.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                        border: active ? Border.all(color: Colors.tealAccent.withOpacity(0.3), width: 0.5) : null,
                      ),
                      child: Row(
                        children: [
                          AnimatedRotation(
                            turns: active ? 0 : -0.023, // 📐 Straightens from -0.15 rad on selection
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutBack,
                            child: Icon(
                              navItems[index]['icon'],
                              color: active ? Colors.tealAccent : Colors.white60,
                              size: 24,
                              shadows: active ? [
                                Shadow(color: Colors.tealAccent.withOpacity(0.8), blurRadius: 15),
                                const Shadow(color: Colors.white, blurRadius: 1)
                              ] : null,
                            ),
                          ).animate(target: active ? 1 : 0).scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.1, 1.1),
                          ),
                          
                          // 🔹 Expanding Label for Active Tab
                          if (active) ...[
                            const SizedBox(width: 10),
                            Text(
                              navItems[index]['label'],
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2, end: 0),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final double progress;
  final int startIndex;
  final int endIndex;
  final int itemCount;

  RipplePainter({
    required this.progress,
    required this.startIndex,
    required this.endIndex,
    required this.itemCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.3 * (1 - progress))
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    final itemWidth = size.width / itemCount;
    final startX = (startIndex + 0.5) * itemWidth;
    final endX = (endIndex + 0.5) * itemWidth;
    
    // Smooth interpolation for the ripple position
    final currentX = startX + (endX - startX) * Curves.easeInOutCubic.transform(progress);
    
    // Draw an expanding and fading teal glow
    final radius = itemWidth * 1.5 * progress;
    canvas.drawCircle(Offset(currentX, size.height / 2), radius, paint);
    
    // Add a trailing line
    final trailPaint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.15 * (1 - progress))
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
      
    canvas.drawLine(
      Offset(startX, size.height / 2),
      Offset(currentX, size.height / 2),
      trailPaint,
    );
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) => true;
}
