import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeType { defaultTheme, light, dark }

class ThemeProvider extends ChangeNotifier {
  ThemeType _currentTheme = ThemeType.defaultTheme;

  ThemeType get currentTheme => _currentTheme;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme');
    
    if (savedTheme == 'light') {
      _currentTheme = ThemeType.light;
    } else if (savedTheme == 'dark') {
      _currentTheme = ThemeType.dark;
    } else {
      _currentTheme = ThemeType.defaultTheme;
    }
    notifyListeners();
  }

  Future<void> setTheme(ThemeType theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    
    switch (theme) {
      case ThemeType.light:
        await prefs.setString('app_theme', 'light');
        break;
      case ThemeType.dark:
        await prefs.setString('app_theme', 'dark');
        break;
      case ThemeType.defaultTheme:
        await prefs.setString('app_theme', 'default');
        break;
    }
    notifyListeners();
  }
}
