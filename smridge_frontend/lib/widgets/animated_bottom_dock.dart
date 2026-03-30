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
    List<IconData> icons = [
      Icons.home,          
      Icons.monitor_heart, 
      Icons.kitchen,       
      Icons.add_box,       
      Icons.settings,      
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, spreadRadius: 10)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
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
                    itemCount: icons.length,
                  ),
                ),
              ),
            
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(icons.length, (index) {
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.all(active ? 14 : 10),
                        decoration: BoxDecoration(
                          color: active ? Colors.tealAccent.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: AnimatedScale(
                          scale: active ? 1.25 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: AnimatedRotation(
                            turns: active ? 0.0 : -0.04,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            child: Icon(
                              icons[index],
                              color: active ? Colors.tealAccent : Colors.white60,
                              size: 26,
                              shadows: active ? [
                                Shadow(color: Colors.tealAccent.withOpacity(0.8), blurRadius: 15),
                                const Shadow(color: Colors.white, blurRadius: 2)
                              ] : null,
                            ),
                          ),
                        ),
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
