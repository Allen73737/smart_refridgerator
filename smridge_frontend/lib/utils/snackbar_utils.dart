import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SnackbarUtils {
  static void showCustomSnackbar(
    BuildContext context, 
    String message, 
    {
      IconData icon = Icons.info_outline, 
      Color bgColor = const Color(0xFF203A43),
      Color iconColor = Colors.tealAccent,
    }
  ) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50.0,
        left: 20.0,
        right: 20.0,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                GestureDetector(
                  onTap: () => overlayEntry.remove(),
                  child: const Icon(Icons.close, color: Colors.white54, size: 20),
                )
              ],
            ),
          ).animate().slideY(begin: -1.0, duration: 400.ms, curve: Curves.easeOutBack).fade(),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  static void showSuccess(BuildContext context, String message) {
    showCustomSnackbar(
      context, 
      message, 
      icon: Icons.check_circle_outline, 
      iconColor: Colors.greenAccent,
      bgColor: const Color(0xFF1E3A2F),
    );
  }

  static void showError(BuildContext context, String message) {
    showCustomSnackbar(
      context, 
      message, 
      icon: Icons.error_outline, 
      iconColor: Colors.redAccent,
      bgColor: const Color(0xFF3A1E1E),
    );
  }

  static void showWarning(BuildContext context, String message) {
    showCustomSnackbar(
      context, 
      message, 
      icon: Icons.warning_amber_rounded, 
      iconColor: Colors.orangeAccent,
      bgColor: const Color(0xFF3A2E1E),
    );
  }

  static void showInfo(BuildContext context, String message) {
    showCustomSnackbar(
      context, 
      message, 
      icon: Icons.info_outline, 
      iconColor: Colors.tealAccent,
      bgColor: const Color(0xFF1E2A33),
    );
  }
}
