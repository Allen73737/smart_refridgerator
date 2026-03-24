import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inventory_item.dart';
import '../services/secure_storage_service.dart';

class ApiService {
  // 🔹 DYNAMIC BACKEND SYSTEM
  static const String localIp = '192.168.0.101';
  static const String emulatorIp = '10.0.2.2';
  static const String localPort = '5002';
  static const String renderUrl = 'smridge-819t.onrender.com';

  // 🔹 Use ValueNotifier so other services (like SocketService) can listen for changes
  static final ValueNotifier<String> currentBaseUrl = ValueNotifier<String>('https://$renderUrl'); // Default to HTTPS
  
  static String? _manualIp; // 🔹 Added for manual override
  static bool get isLocal => currentBaseUrl.value.contains(localIp);
  static String get baseDomain => currentBaseUrl.value;
  static String get host => Uri.parse(currentBaseUrl.value).host; // 🔹 Added for legacy support
  static String get authUrl => '${currentBaseUrl.value}/api/auth';
  static String get userUrl => '${currentBaseUrl.value}/api/user';
  static String get baseUrl => '${currentBaseUrl.value}/api/items';
  static String get deviceUrl => '${currentBaseUrl.value}/api/device';

  /// 🔹 Initialize and determine the best backend to use
  static Future<void> initializeBackend() async {
    print("🌐 Determining best backend...");

    // 0. Check for Manual Override
    final prefs = await SharedPreferences.getInstance();
    _manualIp = prefs.getString('manual_backend_ip');
    if (_manualIp != null && _manualIp!.isNotEmpty) {
      print("🎯 Using Manual Backend Override: $_manualIp");
      currentBaseUrl.value = _manualIp!.startsWith('http') ? _manualIp! : 'http://$_manualIp:5002';
      return;
    }
    
    // 1. Try Physical Device IP (Laptop IP)
    try {
      final localTestUrl = 'http://$localIp:$localPort/health';
      print("🔍 Checking Physical Local: $localTestUrl");
      final response = await http.get(Uri.parse(localTestUrl)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        print("✅ Local Backend Detected (Physical)! Using: http://$localIp:$localPort");
        currentBaseUrl.value = 'http://$localIp:$localPort';
        return;
      }
    } catch (e) { print("ℹ️ Local (Physical) unreachable: $e"); }

    // 2. Try Emulator IP (10.0.2.2)
    try {
      final emuTestUrl = 'http://$emulatorIp:$localPort/health';
      print("🔍 Checking Emulator Local: $emuTestUrl");
      final response = await http.get(Uri.parse(emuTestUrl)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        print("✅ Local Backend Detected (Emulator)! Using: http://$emulatorIp:$localPort");
        currentBaseUrl.value = 'http://$emulatorIp:$localPort';
        return;
      }
    } catch (e) { print("ℹ️ Local (Emulator) unreachable: $e"); }

    // 3. Fallback to Render
    print("🌍 Falling back to Cloud Backend: https://$renderUrl");
    currentBaseUrl.value = 'https://$renderUrl';
  }

  static Future<void> setManualIp(String? ip) async {
    final prefs = await SharedPreferences.getInstance();
    if (ip == null || ip.isEmpty) {
      await prefs.remove('manual_backend_ip');
    } else {
      await prefs.setString('manual_backend_ip', ip);
    }
    
    // 🔥 CRITICAL: Clear token so the user is forced to log in to the NEW environment
    await SecureStorageService.deleteToken();
    
    await initializeBackend();
  }

  static Future<Map<String, dynamic>?> signup(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$authUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );
      if (response.statusCode == 201) return jsonDecode(response.body);
    } catch (e) {
      print("Signup Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    // 🔥 Always re-detect backend on login. Ensures local is used if now reachable,
    // even if the app started before the firewall was open.
    await initializeBackend();
    print("🎯 [Login] Using backend: ${currentBaseUrl.value}");
    try {
      final response = await http.post(
        Uri.parse('$authUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['msg'] ?? "Login failed");
      }
    } catch (e) {
      print("--- [API DEBUG] Login Error: $e ---");
      rethrow;
    }
  }

  static Future<bool> saveFcmToken(String fcmToken, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$userUrl/save-fcm-token'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: jsonEncode({'fcmToken': fcmToken}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Save FCM Token Error: $e");
    }
    return false;
  }

  static Future<Map<String, dynamic>?> googleLogin(String idToken) async {
    try {
      final url = Uri.parse('$authUrl/google');
      print("📡 [API] Google Login POST: $url");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      print("📋 [API] Google Login Response [${response.statusCode}]: ${response.body}");
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { print("❌ Google Login Error: $e"); }
    return null;
  }

  static Future<Map<String, dynamic>?> getProfile(String token) async {
    try {
      final url = Uri.parse('$userUrl/profile');
      print("📡 [API] Fetching Profile from: $url");
      final response = await http.get(
        url,
        headers: {'x-auth-token': token},
      );
      print("📋 [API] Profile Response [${response.statusCode}]");
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { print("❌ Profile Fetch Error: $e"); }
    return null;
  }

  static Future<bool> updateProfile(String name, String email, String token) async {
    try {
      final response = await http.put(
        Uri.parse('$userUrl/profile'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: jsonEncode({'name': name, 'email': email}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Update Profile Error: $e");
    }
    return false;
  }

  static Future<bool> uploadProfileImage(File image, String token) async {
    try {
      var request = http.MultipartRequest('PUT', Uri.parse('$userUrl/profile-image'));
      request.headers['x-auth-token'] = token;
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        image.path,
        contentType: MediaType('image', 'jpeg'),
      ));
      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print("Profile Image Upload Error: $e");
    }
    return false;
  }

  static Future<Map<String, dynamic>?> scanBarcode(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/barcode/$barcode'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { print("Barcode Scan Error: $e"); }
    return null;
  }

  static Future<List<InventoryItem>> getInventory(String token) async {
    try {
      print("📡 [API] Fetching Inventory from: $baseUrl");
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'x-auth-token': token},
      );
      print("📋 Inventory Response [${response.statusCode}]: ${response.body}");
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        return data.map((item) => InventoryItem.fromJson(item)).toList();
      } else {
        print("⚠️ Inventory Fetch Failed with status: ${response.statusCode}");
      }
    } catch (e) { print("❌ Inventory Fetch Error: $e"); }
    return [];
  }

  static Future<bool> addFood(InventoryItem item, String token) async {
    try {
      print("📡 Adding Food to: $baseUrl");
      
      // 🔹 Using MultipartRequest to support images and match backend requirements
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.headers['x-auth-token'] = token;
      
      // Add all fields from item
      final json = item.toJson();
      json.forEach((key, value) {
        if (value != null) request.fields[key] = value.toString();
      });

      // Add image if exists
      if (item.imagePath != null && File(item.imagePath!).existsSync()) {
        request.files.add(await http.MultipartFile.fromPath('image', item.imagePath!));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      print("📥 Add Food Response [${response.statusCode}]: ${response.body}");
      if (response.statusCode == 201) return true;
      print("⚠️ Add Food Failed with status: ${response.statusCode}");
    } catch (e) {
      print("❌ [API] Add Food Error: $e");
    }
    return false;
  }

  static Future<bool> uploadItemImage(String itemId, File image, String token) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/$itemId/image'));
      request.headers['x-auth-token'] = token;
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        image.path,
        contentType: MediaType('image', 'jpeg'),
      ));
      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) { print("Image Upload Error: $e"); }
    return false;
  }

  static Future<bool> updateFood(InventoryItem item, String token) async {
    try {
      final url = Uri.parse('$baseUrl/${item.id}');
      print("📡 [API] Updating Food: $url");
      final body = jsonEncode(item.toJson());
      
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: body,
      );
      
      print("📥 Update Food Response [${response.statusCode}]: ${response.body}");
      return response.statusCode == 200;
    } catch (e) { 
      print("❌ [API] Update Food Error: $e"); 
    }
    return false;
  }

  static Future<bool> deleteFood(String id, String token) async {
    try {
      final url = Uri.parse('$baseUrl/$id');
      print("📡 [API] Deleting Item: $url");
      final response = await http.delete(
        url,
        headers: {'x-auth-token': token},
      );
      print("📋 [API] Delete Item Response [${response.statusCode}]");
      return response.statusCode == 200;
    } catch (e) { print("❌ Delete Food Error: $e"); }
    return false;
  }

  static Future<List<dynamic>> getActivities(String token, {String period = 'all'}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseDomain/api/activities?period=$period'),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Error fetching activities: $e");
    }
    return [];
  }

  static Future<List<dynamic>> getActivityStats(String token, {String period = 'all'}) async {
    try {
      final url = '$baseDomain/api/activities/stats?period=$period';
      print("📡 Fetching Activity Stats from: $url");
      final response = await http.get(
        Uri.parse(url),
        headers: {'x-auth-token': token},
      );
      print("📊 Activity Stats Response [${response.statusCode}]: ${response.body}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('stats')) return data['stats'];
        return data;
      }
    } catch (e) {
      print("❌ Error fetching activity stats: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> autoDetectItemDetails(String name, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseDomain/api/ai/auto-detect'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: jsonEncode({'name': name}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Auto Detect Error: $e");
    }
    return null;
  }

  static Future<String?> uploadAudio(String filePath, String token) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseDomain/api/ai/upload-audio'));
      request.headers['x-auth-token'] = token;
      request.files.add(await http.MultipartFile.fromPath('audio', filePath));
      var response = await request.send();
      if (response.statusCode == 200) {
        final data = await http.Response.fromStream(response);
        return jsonDecode(data.body)['url'];
      }
    } catch (e) {
      print("Audio Upload Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getUserSettings(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseDomain/api/settings'),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Get Settings Error: $e");
    }
    return null;
  }

  static Future<bool> saveUserSettings(String token, Map<String, dynamic> settings) async {
    try {
      final response = await http.post(
        Uri.parse('$baseDomain/api/settings'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: jsonEncode(settings),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Save Settings Error: $e");
    }
    return false;
  }

  static Future<String?> askChatAssistant(String text, String token, {required List history}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseDomain/api/ai/chat'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: jsonEncode({'message': text, 'history': history}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'];
      }
    } catch (e) {
      print("Chat Assistant Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> analyzeFoodItem({required String name, required String token, required String expiryDate}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseDomain/api/ai/analyze'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: jsonEncode({'name': name, 'expiryDate': expiryDate}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Food Analysis Error: $e");
    }
    return null;
  }

  static Future<void> logActivity(String action, String details, String token) async {
    try {
      await http.post(
        Uri.parse('$baseDomain/api/activities/log'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token},
        body: jsonEncode({'action': action, 'details': details}),
      );
    } catch (e) { print("Log Activity Error: $e"); }
  }

  static Future<List<Map<String, dynamic>>> getNotifications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseDomain/api/notifications'),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print("Error fetching notifications: $e");
    }
    return [];
  }

  static Future<bool> markNotificationRead(String id, String token) async {
    try {
      final response = await http.put(
        Uri.parse('$baseDomain/api/notifications/$id/read'),
        headers: {'x-auth-token': token},
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error marking notification as read: $e");
    }
    return false;
  }

  static Future<bool> clearNotifications(String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseDomain/api/notifications/clear'),
        headers: {'x-auth-token': token},
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error clearing notifications: $e");
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> getNotificationHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseDomain/api/notifications/history'),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print("Error fetching notification history: $e");
    }
    return [];
  }

  static Future<bool> clearNotificationHistory(String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseDomain/api/notifications/history'),
        headers: {'x-auth-token': token},
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error clearing notification history: $e");
    }
    return false;
  }

  // 🔹 DEVICE MANAGEMENT
  
  static Future<List<dynamic>> getUserDevices(String token) async {
    try {
      final response = await http.get(
        Uri.parse(deviceUrl),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Get Devices Error: $e");
    }
    return [];
  }

  static Future<bool> connectToEsp(String ssid, String password) async {
    try {
      // 🟢 Local endpoint on ESP32 Access Point
      final url = Uri.parse('http://192.168.4.1/connect');
      print("📡 [ESP32] Sending WiFi credentials to: $url");
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ssid': ssid,
          'password': password,
          // We can also pass the userId if the ESP32 needs to register it
          'userId': await SecureStorageService.getUserId() ?? "", 
        }),
      ).timeout(const Duration(seconds: 10));

      print("📋 [ESP32] Response [${response.statusCode}]: ${response.body}");
      return response.statusCode == 200;
    } catch (e) {
      print("❌ ESP32 Connect Error: $e");
      return false;
    }
  }
}
