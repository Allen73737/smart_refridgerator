import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/wave_background.dart';
import '../services/api_service.dart';
import '../utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AccountProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const AccountProfileScreen({super.key, this.onBack});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool isLoading = true;
  File? _selectedImage;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token != null && token.isNotEmpty && token != 'mock-token') {
      final profile = await ApiService.getProfile(token);
      if (profile != null) {
        setState(() {
          _nameController.text = profile['name'] ?? '';
          _emailController.text = profile['email'] ?? '';
          if (profile['profileImage'] != null) {
            String imageStr = profile['profileImage'];
            _profileImageUrl = imageStr.startsWith('http') ? imageStr : 'http://${ApiService.host}/uploads/$imageStr';
          }
          isLoading = false;
        });
        return;
      }
    }
    setState(() {
        _nameController.text = 'Guest User';
        _emailController.text = 'Please login';
        isLoading = false;
    });
  }

  Future<void> _updateProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token != null) {
      final success = await ApiService.updateProfile(_nameController.text, _emailController.text, token);
      if (success) {
        if (_selectedImage != null) {
           final imageSuccess = await ApiService.uploadProfileImage(_selectedImage!, token);
           if (!imageSuccess && mounted) {
             SnackbarUtils.showError(context, 'Profile updated, but failed to upload image.');
             return;
           }
        }
        if (!mounted) return;
        SnackbarUtils.showSuccess(context, 'Profile Updated Successfully!');
        _loadProfile(); // Refresh to show new image URL
      } else {
        if (!mounted) return;
        SnackbarUtils.showError(context, 'Failed to update profile.');
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLight = themeProvider.currentTheme == ThemeType.light;
    final isDark = themeProvider.currentTheme == ThemeType.dark;
    Color textColor = isLight ? Colors.black87 : Colors.white;

    DecorationImage? profileDecoImage;
    if (_selectedImage != null) {
      profileDecoImage = DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover);
    } else if (_profileImageUrl != null) {
      profileDecoImage = DecorationImage(image: NetworkImage(_profileImageUrl!), fit: BoxFit.cover);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text("Account Profile", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)).animate().fadeIn(),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isLight ? const Color(0xFFF3F6F8) : (isDark ? Colors.black : null),
              gradient: (isLight || isDark) ? null : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2027), Color(0xFF203A43)],
              ),
            ),
          ),
          const Positioned.fill(child: WaveBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                children: [
                  // Avatar Section
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.tealAccent.withOpacity(0.5), width: 3),
                              boxShadow: [
                                BoxShadow(color: Colors.tealAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                              ],
                              color: Colors.white.withOpacity(0.1),
                              image: profileDecoImage,
                            ),
                            child: profileDecoImage == null
                                ? Icon(Icons.person, size: 60, color: isLight ? Colors.black38 : Colors.white54)
                                : null,
                          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.tealAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Color(0xFF0F2027), size: 20),
                          ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Form Section
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.white : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isLight ? Colors.transparent : Colors.white.withOpacity(0.15)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isLight ? 0.05 : 0.2), blurRadius: 30)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Display Name", style: TextStyle(color: isLight ? Colors.teal : Colors.tealAccent, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _nameController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isLight ? Colors.grey.shade200 : Colors.black.withOpacity(0.3),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                prefixIcon: Icon(Icons.person_outline, color: isLight ? Colors.black54 : Colors.white54),
                              ),
                            ),
                            
                            const SizedBox(height: 25),
                            
                            Text("Email Address", style: TextStyle(color: isLight ? Colors.teal : Colors.tealAccent, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _emailController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isLight ? Colors.grey.shade200 : Colors.black.withOpacity(0.3),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                prefixIcon: Icon(Icons.email_outlined, color: isLight ? Colors.black54 : Colors.white54),
                              ),
                            ),

                            const SizedBox(height: 35),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.tealAccent,
                                  foregroundColor: const Color(0xFF0F2027),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  elevation: 10,
                                  shadowColor: Colors.tealAccent.withOpacity(0.5),
                                ),
                                onPressed: _updateProfile,
                                child: const Text("Save Changes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ).animate().fadeIn().slideY(begin: 0.1),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
