import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/wave_background.dart';
import '../utils/snackbar_utils.dart';
import 'add_device_screen.dart';

class BackupCodesScreen extends StatefulWidget {
  final List<String> backupCodes;
  final String email;

  const BackupCodesScreen({super.key, required this.backupCodes, required this.email});

  @override
  State<BackupCodesScreen> createState() => _BackupCodesScreenState();
}

class _BackupCodesScreenState extends State<BackupCodesScreen> {
  bool _hasSaved = false;

  Future<void> _copyAll() async {
    final text = widget.backupCodes.asMap().entries.map((e) => "${e.key + 1}. ${e.value}").join("\n");
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) SnackbarUtils.showSuccess(context, "All codes copied to clipboard!");
  }

  Future<void> _downloadTxt() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/smridge-backup-codes.txt');
      final content = StringBuffer();
      content.writeln("═══════════════════════════════════");
      content.writeln("   SMRIDGE BACKUP CODES");
      content.writeln("═══════════════════════════════════");
      content.writeln("User: ${widget.email}");
      content.writeln("Generated: ${DateTime.now().toIso8601String()}");
      content.writeln("───────────────────────────────────");
      for (int i = 0; i < widget.backupCodes.length; i++) {
        content.writeln("  ${(i + 1).toString().padLeft(2)}.  ${widget.backupCodes[i]}");
      }
      content.writeln("───────────────────────────────────");
      content.writeln("⚠️  These are your ONLY recovery codes.");
      content.writeln("    If lost, your account CANNOT be recovered.");
      await file.writeAsString(content.toString());
      if (mounted) SnackbarUtils.showSuccess(context, "Saved to: ${file.path}");
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, "Failed to save file: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F2027), Color(0xFF203A43)],
              ),
            ),
          ),
          const Positioned.fill(child: WaveBackground()),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Header
                  const Icon(Icons.shield_outlined, color: Colors.tealAccent, size: 56)
                      .animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 12),
                  Text("BACKUP CODES",
                    style: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.3),
                  const SizedBox(height: 8),
                  Text("Save these codes in a secure location",
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.white60),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 20),

                  // Warning Banner
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "These are your ONLY recovery codes. If you lose them, your account cannot be recovered.",
                                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),

                  const SizedBox(height: 20),

                  // Codes Grid
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 3.2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: widget.backupCodes.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.tealAccent.withOpacity(0.15)),
                                  ),
                                  child: Text(
                                    widget.backupCodes[index],
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 15,
                                      color: Colors.tealAccent,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ).animate().fadeIn(delay: (500 + index * 60).ms).slideY(begin: 0.15);
                              },
                            ),
                            const SizedBox(height: 20),
                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.tealAccent.withOpacity(0.4)),
                                      foregroundColor: Colors.tealAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.copy_rounded, size: 18),
                                    label: Text("COPY ALL", style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12)),
                                    onPressed: _copyAll,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.tealAccent.withOpacity(0.4)),
                                      foregroundColor: Colors.tealAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.download_rounded, size: 18),
                                    label: Text("SAVE TXT", style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12)),
                                    onPressed: _downloadTxt,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 450.ms),

                  const SizedBox(height: 24),

                  // Checkbox
                  GestureDetector(
                    onTap: () => setState(() => _hasSaved = !_hasSaved),
                    child: Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _hasSaved ? Colors.tealAccent : Colors.white30, width: 2),
                            color: _hasSaved ? Colors.tealAccent.withOpacity(0.2) : Colors.transparent,
                          ),
                          child: _hasSaved ? const Icon(Icons.check, size: 16, color: Colors.tealAccent) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text("I have saved these codes securely",
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 1200.ms),

                  const SizedBox(height: 24),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasSaved ? Colors.tealAccent : Colors.white12,
                        foregroundColor: _hasSaved ? Colors.black : Colors.white30,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: _hasSaved ? 8 : 0,
                      ),
                      onPressed: _hasSaved
                          ? () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                PageRouteBuilder(
                                  transitionDuration: const Duration(milliseconds: 800),
                                  pageBuilder: (_, __, ___) => const AddDeviceScreen(),
                                  transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                                ),
                                (route) => false,
                              );
                            }
                          : null,
                      child: Text("CONTINUE",
                        style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 15),
                      ),
                    ),
                  ).animate().fadeIn(delay: 1400.ms).scale(begin: const Offset(0.95, 0.95)),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
