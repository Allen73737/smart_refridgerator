import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/inventory_item.dart';

class ApiService {
  static const String host = '192.168.0.101:5001';
  static const String baseUrl = 'http://$host/api/items'; 
  static const String authUrl = 'http://$host/api/auth';

  static Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$authUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token']; // The JWT token
      }
    } catch (e) {
      print("Error logging in: $e");
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
        Uri.parse('http://$host/api/user/profile'),
        headers: {'x-auth-token': token},
      );
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
        Uri.parse('http://$host/api/user/profile'),
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

  static Future<bool> uploadProfileImage(File image, String token) async {
    try {
      var request = http.MultipartRequest('PUT', Uri.parse('http://$host/api/user/profile-image'));
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
        Uri.parse('http://$host/api/analytics/temperature'),
        headers: {'x-auth-token': token},
      );
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
        Uri.parse('http://$host/api/sensor'),
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
      );

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
              notes: json['notes'],
              // Assuming backend uses base domain for local images
              imageUrl: json['image'] != null && json['image'].isNotEmpty 
                  ? (json['image'].startsWith('http') ? json['image'] : 'http://$host/uploads/${json['image']}')
                  : null,
              dateAdded: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
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
        Uri.parse('http://$host/api/notifications'),
        headers: {'x-auth-token': token},
      );
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
        Uri.parse('http://$host/api/notifications/$id/read'),
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
      if (item.notes != null) request.fields['notes'] = item.notes!;
      if (item.imageUrl != null) request.fields['imageUrl'] = item.imageUrl!;

      if (item.imagePath != null && item.imagePath!.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          item.imagePath!,
        ));
      }

      var response = await request.send();
      return response.statusCode == 201;
    } catch (e) {
      print("Error adding food: $e");
      return false;
    }
  }
}
