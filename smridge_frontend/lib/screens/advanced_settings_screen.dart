import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/fridge_customization_provider.dart';
import '../services/audio_service.dart';
import '../services/api_service.dart';
import '../widgets/smart_loader.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  bool _isSaving = false;

  Future<void> _saveAllSettings() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final customizationProvider = Provider.of<FridgeCustomizationProvider>(context, listen: false);

      // 1. Check if any custom audio needs uploading
      final categories = ['fridge_hum', 'door_open', 'notification', 'expiry', 'success'];
      for (var cat in categories) {
        final localPath = customizationProvider.getCustomSoundPath(cat);
        // If it's a local file path (doesn't start with http), upload it
        if (localPath != null && !localPath.startsWith('http')) {
          final cloudUrl = await ApiService.uploadAudio(localPath, token);
          if (cloudUrl != null) {
            customizationProvider.setCloudUrl(cat, cloudUrl);
          }
        }
      }

      // 2. Persist everything to cloud
      await customizationProvider.saveToCloud(token);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings saved to cloud! 🚀"), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final customizationProvider = Provider.of<FridgeCustomizationProvider>(context);

    bool isLight = themeType == ThemeType.light;
    bool isDark = themeType == ThemeType.dark;
    Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: isLight ? const Color(0xFFF3F6F8) : (isDark ? Colors.black : const Color(0xFF0E1215)),
      appBar: AppBar(
        title: Text("Advanced Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)).animate().fadeIn(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (!isLight && !isDark)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F2027), Color(0xFF203A43)],
                ),
              ),
            ),
          
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                _buildSectionHeader("Fridge Visuals", isLight),
                const SizedBox(height: 10),
                _buildColorPickerTile(
                  context,
                  title: "Exterior Color",
                  currentColor: customizationProvider.fridgeExteriorColor,
                  onColorChanged: customizationProvider.setExteriorColor,
                  isLight: isLight,
                ),
                const SizedBox(height: 10),
                _buildColorPickerTile(
                  context,
                  title: "Interior Color",
                  currentColor: customizationProvider.fridgeInteriorColor,
                  onColorChanged: customizationProvider.setInteriorColor,
                  isLight: isLight,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.restore),
                    label: const Text("Revert to Default Visuals"),
                    style: TextButton.styleFrom(
                      foregroundColor: isLight ? Colors.teal : Colors.tealAccent,
                    ),
                    onPressed: () {
                      customizationProvider.resetColorsToDefault();
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                _buildSectionHeader("Audio Customization", isLight),
                const SizedBox(height: 10),
                
                _buildSoundDropdown(
                  context: context,
                  title: "Fridge Working Sound",
                  currentIndex: customizationProvider.fridgeVibratingSoundIndex,
                  onChanged: (val) => customizationProvider.setVibratingSound(val!),
                  isLight: isLight,
                  soundCategory: "fridge_hum",
                ),
                const SizedBox(height: 10),
                _buildSoundDropdown(
                  context: context,
                  title: "Door Sound",
                  currentIndex: customizationProvider.fridgeDoorSoundIndex,
                  onChanged: (val) => customizationProvider.setDoorSound(val!),
                  isLight: isLight,
                  soundCategory: "door_open",
                ),
                const SizedBox(height: 10),
                _buildSoundDropdown(
                  context: context,
                  title: "General Notification",
                  currentIndex: customizationProvider.notificationSoundIndex,
                  onChanged: (val) => customizationProvider.setNotificationSound(val!),
                  isLight: isLight,
                  soundCategory: "notification",
                ),
                const SizedBox(height: 10),
                _buildSoundDropdown(
                  context: context,
                  title: "Expiry Notification",
                  currentIndex: customizationProvider.expiryNotificationSoundIndex,
                  onChanged: (val) => customizationProvider.setExpiryNotificationSound(val!),
                  isLight: isLight,
                  soundCategory: "notification",
                ),
                const SizedBox(height: 10),
                _buildSoundDropdown(
                  context: context,
                  title: "Inventory Save / Update",
                  currentIndex: customizationProvider.inventorySaveSoundIndex,
                  onChanged: (val) => customizationProvider.setInventorySaveSound(val!),
                  isLight: isLight,
                  soundCategory: "success",
                ),
                const SizedBox(height: 20),
                
                // --- STANDALONE AUDIO SAVE BUTTON ---
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isLight ? Colors.teal : Colors.tealAccent,
                      side: BorderSide(color: isLight ? Colors.teal : Colors.tealAccent.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : _saveAllSettings,
                    icon: const Icon(Icons.save_outlined, size: 20),
                    label: const Text("Save Audio Settings", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 40),
                
                // --- SAVE BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLight ? Colors.teal : Colors.tealAccent.withOpacity(0.8),
                      foregroundColor: isLight ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                    ),
                    onPressed: _isSaving ? null : _saveAllSettings,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Save All Settings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ).animate().scale(delay: 200.ms),
                
                const SizedBox(height: 30),
              ],
            ).animate().slideY(begin: 0.1).fadeIn(),
          ),
          
          if (_isSaving)
            const Positioned.fill(
              child: SmartLoader(message: "Syncing customizations..."),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isLight) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isLight ? Colors.teal : Colors.tealAccent,
      ),
    );
  }

  Widget _buildColorPickerTile(BuildContext context, {
    required String title,
    required Color currentColor,
    required ValueChanged<Color> onColorChanged,
    required bool isLight,
  }) {
    Color cardColor = isLight ? Colors.white : Colors.white.withOpacity(0.05);
    Color textColor = isLight ? Colors.black87 : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLight ? Colors.grey.shade300 : Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: textColor, fontSize: 16)),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  Color tempColor = currentColor;
                  return AlertDialog(
                    title: Text("Select $title"),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: currentColor,
                        onColorChanged: (color) => tempColor = color,
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                      TextButton(
                        onPressed: () {
                          onColorChanged(tempColor);
                          Navigator.pop(context);
                        },
                        child: const Text("Save"),
                      ),
                    ],
                  );
                },
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: isLight ? Colors.grey.shade400 : Colors.white54, width: 2),
              ),
            ),
          )
        ],
      ),
    );
  }

  /// Preview plays sound for the given category / index
  void _previewSound(BuildContext context, String category, int index) {
    if (index == -1) return; // None selected
    final provider = Provider.of<FridgeCustomizationProvider>(context, listen: false);
    final customPath = provider.getCustomSoundPath(category);

    switch (category) {
      case 'fridge_hum':
        AudioService.playFridgeHum(index: index, customPath: customPath);
        Future.delayed(const Duration(seconds: 2), () => AudioService.stopFridgeHum());
        break;
      case 'door_open':
        AudioService.playDoorOpen(index: index, customPath: customPath);
        break;
      case 'notification':
        AudioService.playNotification(index: index, customPath: customPath);
        break;
      case 'success':
        AudioService.playSuccess(index: index, customPath: customPath);
        break;
    }
  }

  Widget _buildSoundDropdown({
    required BuildContext context,
    required String title,
    required int currentIndex,
    required ValueChanged<int?> onChanged,
    required bool isLight,
    required String soundCategory,
  }) {
    Color cardColor = isLight ? Colors.white : Colors.white.withOpacity(0.05);
    Color textColor = isLight ? Colors.black87 : Colors.white;
    final customizationProvider = Provider.of<FridgeCustomizationProvider>(context);
    final customPath = customizationProvider.getCustomSoundPath(soundCategory);
    final hasCustom = customPath != null && customPath.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLight ? Colors.grey.shade300 : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: TextStyle(color: textColor, fontSize: 16)),
              ),
              // Set as Default button
              IconButton(
                icon: Icon(Icons.star_outline, color: isLight ? Colors.amber.shade700 : Colors.amber, size: 22),
                tooltip: "Set current as Default",
                onPressed: () {
                  customizationProvider.setAsDefault(soundCategory, currentIndex);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("'${currentIndex == 99 ? 'Custom' : currentIndex == -1 ? 'None' : currentIndex == 0 ? 'Default' : 'Sound $currentIndex'}' set as default for $title"),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              // Preview Button
              IconButton(
                icon: Icon(Icons.play_circle_outline, color: isLight ? Colors.teal : Colors.tealAccent, size: 28),
                tooltip: "Preview Sound",
                onPressed: () => _previewSound(context, soundCategory, currentIndex),
              ),
              DropdownButton<int>(
                value: currentIndex,
                dropdownColor: isLight ? Colors.white : const Color(0xFF1E2A33),
                underline: const SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: textColor),
                items: [
                  DropdownMenuItem(
                    value: -1,
                    child: Text("None", style: TextStyle(color: textColor)),
                  ),
                  ...List.generate(7, (index) {
                    return DropdownMenuItem(
                      value: index,
                      child: Text(index == 0 ? "Default" : "Sound $index", style: TextStyle(color: textColor)),
                    );
                  }),
                  if (hasCustom)
                    DropdownMenuItem(
                      value: 99,
                      child: Text("Custom ♪", style: TextStyle(color: isLight ? Colors.deepPurple : Colors.purpleAccent)),
                    ),
                ],
                onChanged: onChanged,
              ),
            ],
          ),
          // Pick from device button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: Icon(Icons.folder_open, size: 16, color: isLight ? Colors.teal : Colors.tealAccent),
              label: Text(
                hasCustom ? "Change Custom Audio" : "Pick Audio from Device",
                style: TextStyle(fontSize: 12, color: isLight ? Colors.teal : Colors.tealAccent),
              ),
              onPressed: () async {
                try {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.audio,
                    allowMultiple: false,
                  );
                  if (result != null && result.files.isNotEmpty) {
                    final path = result.files.single.path;
                    if (path != null) {
                      customizationProvider.setCustomSound(soundCategory, path);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Custom audio set for $title"), duration: const Duration(seconds: 2)),
                        );
                      }
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Could not pick audio file"), duration: Duration(seconds: 2)),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

