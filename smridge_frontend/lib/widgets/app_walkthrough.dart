import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/haptic_service.dart';

class WalkthroughStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final Alignment tooltipAlignment;

  WalkthroughStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.tooltipAlignment = Alignment.bottomCenter,
  });
}

class AppWalkthrough extends StatefulWidget {
  final List<WalkthroughStep> steps;
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  const AppWalkthrough({
    super.key,
    required this.steps,
    required this.onFinish,
    required this.onSkip,
  });

  @override
  State<AppWalkthrough> createState() => _AppWalkthroughState();
}

class _AppWalkthroughState extends State<AppWalkthrough> {
  int _currentStepIndex = 0;
  Rect? _targetRect;
  int _retryCount = 0;
  static const int _maxRetries = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollAndCalculate());
  }

  /// 🎯 Auto-scroll to the target widget, then calculate its position
  Future<void> _scrollAndCalculate() async {
    if (_currentStepIndex >= widget.steps.length) return;
    _retryCount = 0;
    
    final key = widget.steps[_currentStepIndex].targetKey;
    
    // 🔹 Try to scroll the target into view first
    if (key.currentContext != null) {
      try {
        await Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.3, // Position target at 30% from top for comfortable viewing
        );
      } catch (_) {
        // Not all widgets are inside a Scrollable — that's OK
      }
      // Wait for scroll animation to complete before measuring
      await Future.delayed(const Duration(milliseconds: 450));
    }
    
    _calculateTargetRect();
  }

  void _calculateTargetRect() {
    if (_currentStepIndex >= widget.steps.length) return;
    
    final key = widget.steps[_currentStepIndex].targetKey;
    final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    
    if (renderBox != null && mounted) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final rect = offset & renderBox.size;
      
      // Safety check: if the rect is zero-sized, retry
      if (rect.width == 0 || rect.height == 0) {
        _retryWithDelay();
        return;
      }
      
      // Safety check: if the rect is off-screen, try scrolling again
      final screenHeight = MediaQuery.of(context).size.height;
      if (rect.top > screenHeight || rect.bottom < 0) {
        _retryWithDelay(scrollFirst: true);
        return;
      }
      
      setState(() {
        _targetRect = rect;
      });
    } else {
      _retryWithDelay();
    }
  }

  void _retryWithDelay({bool scrollFirst = false}) {
    if (_retryCount >= _maxRetries) {
      // Give up on this step — skip to next
      debugPrint("⚠️ Walkthrough: Could not find target for step $_currentStepIndex, skipping.");
      _nextStep();
      return;
    }
    _retryCount++;
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (scrollFirst) {
        _scrollAndCalculate();
      } else {
        _calculateTargetRect();
      }
    });
  }

  void _nextStep() {
    HapticService.light();
    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _targetRect = null; 
      });
      // 🔹 Use scrollAndCalculate instead of just calculateTargetRect
      Future.delayed(100.ms, () => _scrollAndCalculate());
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targetRect == null) return const SizedBox.shrink();

    final step = widget.steps[_currentStepIndex];
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Full-screen Dark Overlay with Cutout
          Positioned.fill(
            child: GestureDetector(
              onTap: _nextStep,
              child: CustomPaint(
                painter: CutoutPainter(
                  rect: _targetRect!.inflate(8), 
                  color: Colors.black.withOpacity(0.85),
                ),
              ),
            ),
          ),

          // 2. Pulsing Highlight Border
          Positioned.fromRect(
            rect: _targetRect!.inflate(12),
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.tealAccent, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.tealAccent.withOpacity(0.4), blurRadius: 20, spreadRadius: 0)
                  ],
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(begin: const Offset(1, 1), end: const Offset(1.03, 1.03), duration: 800.ms)
               .fadeIn(duration: 800.ms),
            ),
          ),

          // 3. The Instruction Tooltip
          _buildTooltip(step, size.width, size.height, padding),

          // 4. Skip Button (High Contrast)
          Positioned(
            top: padding.top + 20,
            right: 20,
            child: SafeArea(
              child: TextButton(
                onPressed: widget.onSkip,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  "SKIP TOUR",
                  style: GoogleFonts.orbitron(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(WalkthroughStep step, double screenWidth, double screenHeight, EdgeInsets padding) {
    // Advanced positioning logic
    double tooltipHeight = 200; // Realistic height
    double top = _targetRect!.bottom + 24;
    
    // Switch to top-position if it doesn't fit at bottom
    if (top + tooltipHeight > screenHeight - padding.bottom - 40) {
      top = _targetRect!.top - tooltipHeight - 24;
    }
    
    // Final Clamp to ensure it's ALWAYS visible in SafeArea
    top = top.clamp(padding.top + 80, screenHeight - padding.bottom - tooltipHeight - 20);

    return Positioned(
      top: top,
      left: 20,
      width: screenWidth - 40,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF162129),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.tealAccent.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40, offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.tealAccent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.title.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      color: Colors.tealAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              step.description,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.9),
                fontSize: 15,
                height: 1.6,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${_currentStepIndex + 1} / ${widget.steps.length}",
                    style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 5,
                  ),
                  child: Text(
                    _currentStepIndex == widget.steps.length - 1 ? "GET STARTED" : "NEXT STEP",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().slideY(begin: 0.1).fadeIn(duration: 400.ms),
    );
  }
}

class CutoutPainter extends CustomPainter {
  final Rect rect;
  final Color color;

  CutoutPainter({required this.rect, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    
    final path = Path.combine(PathOperation.difference, fullPath, cutoutPath);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CutoutPainter oldDelegate) => oldDelegate.rect != rect;
}
