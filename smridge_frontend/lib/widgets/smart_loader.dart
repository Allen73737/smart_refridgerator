import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class SmartLoader extends StatelessWidget {
  final String message;
  
  const SmartLoader({
    super.key, 
    this.message = "Authenticating..."
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: Colors.black.withOpacity(0.2),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Glowing Spinner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.tealAccent.withOpacity(0.6),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                  BoxShadow(
                    color: Colors.tealAccent.withOpacity(0.4),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
              child: const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat())
             .shimmer(duration: 2000.ms, color: Colors.tealAccent)
             .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1000.ms, curve: Curves.easeInOutSine),
             
            const SizedBox(height: 35),
            
            /// Loading Message
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
                decoration: TextDecoration.none,
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .fade(duration: 1200.ms, begin: 0.4, end: 1.0),
          ],
        ),
      ),
    );
  }
}
