import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FridgeCustomizationProvider extends ChangeNotifier {
  // Fridge Colors
  Color _fridgeExteriorColor = const Color(0xFF2B4162);
  Color _fridgeInteriorColor = Colors.white;

  // Sound Options (indices: -1=None, 0=Default, 1-6=built-in, 99=custom from device)
  int _fridgeVibratingSoundIndex = 0;
  int _fridgeDoorSoundIndex = 0;
  int _notificationSoundIndex = 0;
  int _expiryNotificationSoundIndex = 0;
  int _inventorySaveSoundIndex = 0;

  // Custom sound file paths (from device storage)
  String? _customVibratingSoundPath;
  String? _customDoorSoundPath;
  String? _customNotificationSoundPath;
  String? _customExpiryNotificationSoundPath;
  String? _customInventorySaveSoundPath;

  // Default sound indices per category (which built-in sound is treated as "Default")
  int _defaultVibratingSound = 0;
  int _defaultDoorSound = 0;
  int _defaultNotificationSound = 0;
  int _defaultExpirySoundDefault = 0;
  int _defaultInventorySaveSound = 0;

  // Getters
  Color get fridgeExteriorColor => _fridgeExteriorColor;
  Color get fridgeInteriorColor => _fridgeInteriorColor;
  int get fridgeVibratingSoundIndex => _fridgeVibratingSoundIndex;
  int get fridgeDoorSoundIndex => _fridgeDoorSoundIndex;
  int get notificationSoundIndex => _notificationSoundIndex;
  int get expiryNotificationSoundIndex => _expiryNotificationSoundIndex;
  int get inventorySaveSoundIndex => _inventorySaveSoundIndex;

  String? get customVibratingSoundPath => _customVibratingSoundPath;
  String? get customDoorSoundPath => _customDoorSoundPath;
  String? get customNotificationSoundPath => _customNotificationSoundPath;
  String? get customExpiryNotificationSoundPath => _customExpiryNotificationSoundPath;
  String? get customInventorySaveSoundPath => _customInventorySaveSoundPath;

  int get defaultVibratingSound => _defaultVibratingSound;
  int get defaultDoorSound => _defaultDoorSound;
  int get defaultNotificationSound => _defaultNotificationSound;
  int get defaultExpirySoundDefault => _defaultExpirySoundDefault;
  int get defaultInventorySaveSound => _defaultInventorySaveSound;

  /// Load all saved settings from SharedPreferences
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _fridgeExteriorColor = Color(prefs.getInt('extColor') ?? 0xFF2B4162);
    _fridgeInteriorColor = Color(prefs.getInt('intColor') ?? 0xFFFFFFFF);
    _fridgeVibratingSoundIndex = (prefs.getInt('vibSound') ?? 0).clamp(-1, 99);
    _fridgeDoorSoundIndex = (prefs.getInt('doorSound') ?? 0).clamp(-1, 99);
    _notificationSoundIndex = (prefs.getInt('notifSound') ?? 0).clamp(-1, 99);
    _expiryNotificationSoundIndex = (prefs.getInt('expirySound') ?? 0).clamp(-1, 99);
    _inventorySaveSoundIndex = (prefs.getInt('saveSound') ?? 0).clamp(-1, 99);

    _customVibratingSoundPath = prefs.getString('customVibPath');
    _customDoorSoundPath = prefs.getString('customDoorPath');
    _customNotificationSoundPath = prefs.getString('customNotifPath');
    _customExpiryNotificationSoundPath = prefs.getString('customExpiryPath');
    _customInventorySaveSoundPath = prefs.getString('customSavePath');

    _defaultVibratingSound = prefs.getInt('defVibSound') ?? 0;
    _defaultDoorSound = prefs.getInt('defDoorSound') ?? 0;
    _defaultNotificationSound = prefs.getInt('defNotifSound') ?? 0;
    _defaultExpirySoundDefault = prefs.getInt('defExpirySound') ?? 0;
    _defaultInventorySaveSound = prefs.getInt('defSaveSound') ?? 0;

    notifyListeners();
  }

  /// Save all current settings to SharedPreferences
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('extColor', _fridgeExteriorColor.value);
    await prefs.setInt('intColor', _fridgeInteriorColor.value);
    await prefs.setInt('vibSound', _fridgeVibratingSoundIndex);
    await prefs.setInt('doorSound', _fridgeDoorSoundIndex);
    await prefs.setInt('notifSound', _notificationSoundIndex);
    await prefs.setInt('expirySound', _expiryNotificationSoundIndex);
    await prefs.setInt('saveSound', _inventorySaveSoundIndex);

    if (_customVibratingSoundPath != null) await prefs.setString('customVibPath', _customVibratingSoundPath!);
    if (_customDoorSoundPath != null) await prefs.setString('customDoorPath', _customDoorSoundPath!);
    if (_customNotificationSoundPath != null) await prefs.setString('customNotifPath', _customNotificationSoundPath!);
    if (_customExpiryNotificationSoundPath != null) await prefs.setString('customExpiryPath', _customExpiryNotificationSoundPath!);
    if (_customInventorySaveSoundPath != null) await prefs.setString('customSavePath', _customInventorySaveSoundPath!);

    await prefs.setInt('defVibSound', _defaultVibratingSound);
    await prefs.setInt('defDoorSound', _defaultDoorSound);
    await prefs.setInt('defNotifSound', _defaultNotificationSound);
    await prefs.setInt('defExpirySound', _defaultExpirySoundDefault);
    await prefs.setInt('defSaveSound', _defaultInventorySaveSound);
  }

  // Setters
  void setExteriorColor(Color color) {
    _fridgeExteriorColor = color;
    notifyListeners();
    _saveToPrefs();
  }

  void setInteriorColor(Color color) {
    _fridgeInteriorColor = color;
    notifyListeners();
    _saveToPrefs();
  }

  void setVibratingSound(int index) {
    _fridgeVibratingSoundIndex = index;
    notifyListeners();
    _saveToPrefs();
  }

  void setDoorSound(int index) {
    _fridgeDoorSoundIndex = index;
    notifyListeners();
    _saveToPrefs();
  }

  void setNotificationSound(int index) {
    _notificationSoundIndex = index;
    notifyListeners();
    _saveToPrefs();
  }

  void setExpiryNotificationSound(int index) {
    _expiryNotificationSoundIndex = index;
    notifyListeners();
    _saveToPrefs();
  }

  void setInventorySaveSound(int index) {
    _inventorySaveSoundIndex = index;
    notifyListeners();
    _saveToPrefs();
  }

  // Custom sound from device
  void setCustomSound(String category, String filePath) {
    switch (category) {
      case 'fridge_hum':
        _customVibratingSoundPath = filePath;
        _fridgeVibratingSoundIndex = 99;
        break;
      case 'door_open':
        _customDoorSoundPath = filePath;
        _fridgeDoorSoundIndex = 99;
        break;
      case 'notification':
        _customNotificationSoundPath = filePath;
        _notificationSoundIndex = 99;
        break;
      case 'expiry':
        _customExpiryNotificationSoundPath = filePath;
        _expiryNotificationSoundIndex = 99;
        break;
      case 'success':
        _customInventorySaveSoundPath = filePath;
        _inventorySaveSoundIndex = 99;
        break;
    }
    notifyListeners();
    _saveToPrefs();
  }

  String? getCustomSoundPath(String category) {
    switch (category) {
      case 'fridge_hum': return _customVibratingSoundPath;
      case 'door_open': return _customDoorSoundPath;
      case 'notification': return _customNotificationSoundPath;
      case 'expiry': return _customExpiryNotificationSoundPath;
      case 'success': return _customInventorySaveSoundPath;
      default: return null;
    }
  }

  // Set current sound as the default for a category
  void setAsDefault(String category, int index) {
    switch (category) {
      case 'fridge_hum': _defaultVibratingSound = index; break;
      case 'door_open': _defaultDoorSound = index; break;
      case 'notification': _defaultNotificationSound = index; break;
      case 'expiry': _defaultExpirySoundDefault = index; break;
      case 'success': _defaultInventorySaveSound = index; break;
    }
    notifyListeners();
    _saveToPrefs();
  }

  void resetColorsToDefault() {
    _fridgeExteriorColor = const Color(0xFF2B4162);
    _fridgeInteriorColor = Colors.white;
    notifyListeners();
    _saveToPrefs();
  }

  void resetAudioToDefault() {
    _fridgeVibratingSoundIndex = _defaultVibratingSound;
    _fridgeDoorSoundIndex = _defaultDoorSound;
    _notificationSoundIndex = _defaultNotificationSound;
    _expiryNotificationSoundIndex = _defaultExpirySoundDefault;
    _inventorySaveSoundIndex = _defaultInventorySaveSound;
    notifyListeners();
    _saveToPrefs();
  }

  void resetToDefault() {
    resetColorsToDefault();
    resetAudioToDefault();
  }
}
