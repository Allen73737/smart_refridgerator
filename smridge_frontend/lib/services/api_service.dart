import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/inventory_item.dart';

class ApiService {
  // 🔹 TOGGLE THIS: Set to true if using ngrok/localtunnel, false if using local Wi-Fi
  static const bool usePublicTunnel = false; 

  // 🔹 Update these with your current tunnel URL or Local IP
  static const String publicHost = 'your-tunnel-url-here.loca.lt'; 
  static const String localHost = '192.168.0.101:5001';

  static String get host => usePublicTunnel ? publicHost : localHost;

  static String get baseUrl => 'http://$host/api/items'; 
  static String get authUrl => 'http://$host/api/auth';
  static String get baseDomain => 'http://$host';

  static Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$authUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'];
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['msg'] ?? "Login failed");
      }
    } catch (e) {
      print("--- [API DEBUG] Login Error: $e ---");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> googleLogin(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$authUrl/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Google Login API Error: $e");
    }
    return null;
  }

  static Future<bool> signup(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$authUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("Error signing up: $e");
    }
    return false;
  }

  static Future<Map<String, dynamic>?> getProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseDomain/api/user/profile'),
        headers: {'x-auth-token': token},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error getting profile: $e");
    }
    return null;
  }

  static Future<bool> updateProfile(String name, String email, String token) async {
    try {
      final response = await http.put(
        Uri.parse('$baseDomain/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token
        },
        body: jsonEncode({'name': name, 'email': email}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Warning: Profile Update failed - $e");
      return false;
    }
  }

  static Future<bool> saveFcmToken(String fcmToken, String authToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseDomain/api/user/save-fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': authToken
        },
        body: jsonEncode({'token': fcmToken}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error saving FCM Token: $e");
      return false;
    }
  }

  static Future<bool> uploadProfileImage(File image, String token) async {
    try {
      var request = http.MultipartRequest('PUT', Uri.parse('$baseDomain/api/user/profile-image'));
      request.headers['x-auth-token'] = token;
      
      request.files.add(
        await http.MultipartFile.fromPath('image', image.path)
      );

      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print("Error uploading profile image: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getAnalytics(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseDomain/api/analytics/temperature'),
        headers: {'x-auth-token': token},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return {'temperature': jsonDecode(response.body)};
      }
    } catch (e) {
      print("Error getting analytics: $e");
    }
    return null;
  }

  static Future<void> pushSensorData(int temp, int humidity, int freshness) async {
    try {
      final gasLevel = (100 - freshness) * 10;
      await http.post(
        Uri.parse('$baseDomain/api/sensors/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'temperature': temp,
          'humidity': humidity,
          'gasLevel': gasLevel,
          'weight': 0.0,
          'doorStatus': 'closed'
        }),
      );
    } catch (_) {}
  }

  static Future<List<InventoryItem>> getInventory(String token) async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'x-auth-token': token},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) {
           return InventoryItem(
              id: json['_id'],
              name: json['name'] ?? 'Unknown',
              category: json['category'],
              isPackaged: json['packaged'] ?? true,
              quantity: json['quantity'] ?? 1,
              weight: (json['weight'] as num?)?.toDouble(),
              barcode: json['barcode'],
              brand: json['brand'],
              expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate']) : DateTime.now(),
              expirySource: json['expirySource'],
              reminderDate: json['reminderDate'] != null ? DateTime.parse(json['reminderDate']) : null,
              notes: json['notes'],
              dateAdded: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
              // Assuming backend uses base domain for local images
              imageUrl: json['image'] != null && json['image'].isNotEmpty 
                  ? (json['image'].startsWith('http') ? json['image'] : '$baseDomain/uploads/${json['image']}')
                  : null,
           );
        }).toList();
      }
    } catch (e) {
      print("Error getting inventory: $e");
    }
    return [];
  }

  static Future<bool> deleteFood(String id, String token) async {
     try {
       final response = await http.delete(
         Uri.parse('$baseUrl/$id'),
         headers: {'x-auth-token': token},
       );
       return response.statusCode == 200;
     } catch(e) {
       print("Error deleting item: $e");
     }
     return false;
  }

  static Future<List<Map<String, dynamic>>> getNotifications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseDomain/api/notifications'),
        headers: {'x-auth-token': token},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch(e) {
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
    } catch(e) {
      print("Error marking notification as read: $e");
    }
    return false;
  }

  static Future<Map<String, dynamic>?> scanBarcode(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];
          
          // Helper to safely extract items
          final productName = product['product_name'] ?? '';
          final brand = product['brands'] ?? '';
          final categoryStr = product['categories'] ?? '';
          final category = categoryStr.isNotEmpty ? categoryStr.split(',')[0].trim() : 'Unknown';
          final quantityStr = product['quantity']?.toString() ?? '';
          final imageUrl = product['image_url'] ?? '';

          // Estimate expiry logic
          int expiryDays = 7;
          final catLower = category.toLowerCase();
          if (catLower.contains('milk')) expiryDays = 5;
          else if (catLower.contains('yogurt') || catLower.contains('yoghurt')) expiryDays = 7;
          else if (catLower.contains('cheese')) expiryDays = 14;
          else if (catLower.contains('bread')) expiryDays = 4;
          else if (catLower.contains('sauce')) expiryDays = 30;
          else if (catLower.contains('chocolate')) expiryDays = 180;

          return {
            'name': productName,
            'brand': brand,
            'category': category,
            'weight': quantityStr.isNotEmpty ? double.tryParse(quantityStr) : null,
            'imageUrl': imageUrl,
            'expiryDate': DateTime.now().add(Duration(days: expiryDays)).toIso8601String(),
            'expirySource': 'estimated',
          };
        }
      }
      return null;
    } catch (e) {
      print("Error scanning barcode directly: $e");
      return null;
    }
  }

  static Future<bool> addFood(InventoryItem item, String token) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.headers['x-auth-token'] = token;

      request.fields['name'] = item.name;
      if (item.category != null) request.fields['category'] = item.category!;
      request.fields['packaged'] = item.isPackaged.toString();
      request.fields['quantity'] = item.quantity.toString();
      if (item.weight != null) request.fields['weight'] = item.weight.toString();
      if (item.barcode != null) request.fields['barcode'] = item.barcode!;
      if (item.brand != null) request.fields['brand'] = item.brand!;
      request.fields['expiryDate'] = item.expiryDate.toIso8601String();
      if (item.expirySource != null) request.fields['expirySource'] = item.expirySource!;
      if (item.reminderDate != null) request.fields['reminderDate'] = item.reminderDate!.toIso8601String();
      if (item.notes != null) request.fields['notes'] = item.notes!;
      if (item.imageUrl != null) request.fields['imageUrl'] = item.imageUrl!;

      if (item.imagePath != null && item.imagePath!.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          item.imagePath!,
        ));
      }

      var response = await request.send();
      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        final respBody = await response.stream.bytesToString();
        print("Backend Error adding food [${response.statusCode}]: $respBody");
        return false;
      }
    } catch (e) {
      print("Error adding food: $e");
      return false;
    }
  }

  static Future<bool> updateFood(InventoryItem item, String token) async {
    try {
      if (item.id == null) return false;
      var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/${item.id}'));
      request.headers['x-auth-token'] = token;

      request.fields['name'] = item.name;
      if (item.category != null) request.fields['category'] = item.category!;
      request.fields['packaged'] = item.isPackaged.toString();
      request.fields['quantity'] = item.quantity.toString();
      if (item.weight != null) request.fields['weight'] = item.weight.toString();
      if (item.barcode != null) request.fields['barcode'] = item.barcode!;
      if (item.brand != null) request.fields['brand'] = item.brand!;
      request.fields['expiryDate'] = item.expiryDate.toIso8601String();
      if (item.expirySource != null) request.fields['expirySource'] = item.expirySource!;
      if (item.reminderDate != null) request.fields['reminderDate'] = item.reminderDate!.toIso8601String();
      if (item.notes != null) request.fields['notes'] = item.notes!;
      if (item.imageUrl != null) request.fields['imageUrl'] = item.imageUrl!;

      if (item.imagePath != null && item.imagePath!.isNotEmpty) {
        // Only upload if it's a local file path
        if (!item.imagePath!.startsWith('http')) {
          request.files.add(await http.MultipartFile.fromPath(
            'image',
            item.imagePath!,
          ));
        }
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        return true;
      } else {
        final respBody = await response.stream.bytesToString();
        print("Backend Error updating food [${response.statusCode}]: $respBody");
        return false;
      }
    } catch (e) {
      print("Error updating food: $e");
      return false;
    }
  }

  // --- AI INTEGRATION ENDPOINTS ---

  static Future<Map<String, dynamic>?> autoDetectItemDetails(String name, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseDomain/api/ai/auto-detect'),
        headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error auto-detecting item details: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getSuggestedImage(String imagePath, String token) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('http://$host/api/ai/suggest-image'));
      request.headers['x-auth-token'] = token;
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      
      var response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return jsonDecode(responseData);
      }
    } catch (e) {
      print("Error getting AI image suggestion: $e");
    }
    return null;
  }

  static Future<String?> fetchAiOverview(String name, String category, String brand, String token) async {
    try {
      final response = await http.post(
        Uri.parse('http://$host/api/ai/overview'),
        headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'category': category, 'brand': brand}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['overview'];
      }
    } catch (e) {
      print("Error fetching AI overview: $e");
    }
    return null;
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
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getNotificationHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseDomain/api/notifications/history'),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      print("Error fetching notification history: $e");
    }
    return [];
  }

  static Future<List<dynamic>?> generateRecipes(String token) async {
    try {
      final response = await http.post(
        Uri.parse('http://$host/api/ai/recipes'),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['recipes'];
      }
    } catch (e) {
      print("Error generating recipes: $e");
    }
    return null;
  }

  static Future<String?> askChatAssistant(String message, String token, {List<Map<String, String>> history = const []}) async {
    try {
      final response = await http.post(
        Uri.parse('http://$host/api/ai/chat'),
        headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'history': history,
        }),
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'];
      } else {
        print("Backend returned status code: ${response.statusCode} - ${response.body}");
        return "Backend Error ${response.statusCode}: ${response.body}";
      }
    } catch (e) {
      print("Error asking AI chat: $e");
      return "Network Exception: $e";
    }
  }

  static Future<Map<String, dynamic>?> analyzeFoodItem({
    required String name,
    required String token,
    String? expiryDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://$host/api/ai/analyze'),
        headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'expiryDate': expiryDate}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Groq Analyze Error ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error analyzing food item: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getUserSettings(String token) async {
    try {
      final response = await http.get(
        Uri.parse('http://$host/api/settings/user-settings'),
        headers: {
          'x-auth-token': token,
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching user settings: $e");
    }
    return null;
  }

  static Future<bool> saveUserSettings(String token, Map<String, dynamic> settings) async {
    try {
      final response = await http.post(
        Uri.parse('http://$host/api/settings/user-settings'),
        headers: {
          'x-auth-token': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(settings),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error saving user settings: $e");
      return false;
    }
  }

  static Future<String?> uploadAudio(String filePath, String token) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('http://$host/api/settings/upload-audio'));
      request.headers['x-auth-token'] = token;
      request.files.add(await http.MultipartFile.fromPath('audio', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'];
      } else {
        print("Audio upload failed [${response.statusCode}]: ${response.body}");
      }
    } catch (e) {
      print("Error uploading audio: $e");
    }
    return null;
  }
}
