import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class CreativeNavbar extends StatelessWidget {
  final VoidCallback onMenuPressed;
  
  const CreativeNavbar({super.key, required this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
              
              IconButton(
                icon: const Icon(Icons.ac_unit, color: Colors.tealAccent),
                onPressed: () {},
              ).animate().fade().slideX(begin: 0.5),
            ],
          ),
        ),
      ),
    );
  }
}
