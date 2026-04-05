import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/notifications_screen.dart';

class CreativeNavbar extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final GlobalKey? walkthroughKey;
  final int notificationCount;
  
  const CreativeNavbar({
    super.key,
    required this.onMenuPressed,
    this.walkthroughKey,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ]
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: onMenuPressed,
              ).animate().fade().slideX(begin: -0.5),
              
              Text(
                "SMRIDGE",
                style: GoogleFonts.orbitron(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ).animate().fade().scale(delay: 200.ms),
              
              Stack(
                clipBehavior: Clip.none,
                children: [
                   IconButton(
                    key: walkthroughKey,
                    icon: const Icon(Icons.notifications_none_rounded, color: Colors.tealAccent, size: 30),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ).animate().fade().slideX(begin: 0.5),
                  if (notificationCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 4, spreadRadius: 1)
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            notificationCount > 99 ? "99+" : notificationCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ).animate().scale(duration: 400.ms, curve: Curves.bounceOut),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
