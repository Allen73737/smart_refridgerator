import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/haptic_service.dart';

class SmridgeTimerOverlay extends StatefulWidget {
  final Duration duration;
  final String title;
  final VoidCallback onFinish;

  const SmridgeTimerOverlay({
    super.key,
    required this.duration,
    required this.title,
    required this.onFinish,
  });

  @override
  State<SmridgeTimerOverlay> createState() => _SmridgeTimerOverlayState();
}

class _SmridgeTimerOverlayState extends State<SmridgeTimerOverlay> {
  late int _secondsRemaining;
  Timer? _timer;
  late double _initialSeconds;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.duration.inSeconds;
    _initialSeconds = _secondsRemaining.toDouble();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
        if (_secondsRemaining <= 3) HapticService.light();
      } else {
        _timer?.cancel();
        _handleFinish();
      }
    });
  }

  void _handleFinish() {
    HapticService.heavy();
    Future.delayed(1.seconds, () {
      if (mounted) widget.onFinish();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  String _getSmridgeEmojiText() {
    double percent = _secondsRemaining / _initialSeconds;
    if (_secondsRemaining == 0) return "💥"; // BOOM
    if (_secondsRemaining <= 5) return "😱"; // Panicking
    if (percent < 0.2) return "🥶"; // Very anxious/freezing
    if (percent < 0.5) return "👀"; // Watching closely
    return "🧊"; // Happy Smridge
  }

  Color _getTimerColor() {
    double percent = _secondsRemaining / _initialSeconds;
    if (_secondsRemaining <= 5) return Colors.redAccent;
    if (percent < 0.3) return Colors.orangeAccent;
    return Colors.tealAccent;
  }

  @override
  Widget build(BuildContext context) {
    double progress = _secondsRemaining / _initialSeconds;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2A33),
            borderRadius: BorderRadius.circular(32),
            border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1), width: 2),
                left: BorderSide(color: Colors.white.withOpacity(0.1), width: 2),
                right: BorderSide(color: Colors.white.withOpacity(0.1), width: 2),
                bottom: BorderSide(color: _getTimerColor().withOpacity(0.8), width: 8), // 🧊 Premium Chunky Border
            ),
            boxShadow: [
              BoxShadow(
                color: _getTimerColor().withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title.toUpperCase(),
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              
              // 🕒 CIRCULAR TIMER
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.white10,
                      color: _getTimerColor(),
                    ),
                  ).animate(target: _secondsRemaining <= 5 ? 1 : 0)
                   .shimmer(duration: 1.seconds, color: Colors.white24)
                   .shake(hz: 4, curve: Curves.easeInOut),

                  // 👾 SMRIDGE EMOJI
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getSmridgeEmojiText(),
                        style: const TextStyle(fontSize: 55),
                      ).animate(key: ValueKey(_getSmridgeEmojiText()))
                       .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 600.ms)
                       .fadeIn(),
                      const SizedBox(height: 10),
                      Text(
                        _formatTime(_secondsRemaining),
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              GestureDetector(
                onTap: () {
                  _timer?.cancel();
                  widget.onFinish();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 6), // Chunky bottom border
                    ),
                  ),
                  child: Text(
                    "CANCEL TIMER",
                    style: GoogleFonts.orbitron(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ).animate().scale(curve: Curves.elasticOut),
            ],
          ),
        ),
      ).animate().scale(begin: const Offset(0.6, 0.6), curve: Curves.elasticOut, duration: 600.ms).fadeIn(),
    );
  }
}
