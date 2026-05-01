import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PhotographerService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    } else {
      return "http://10.0.2.2:3000/api";
    }
  }

  static Future<List> getAllPhotographers() async {
    try {
      final token = await AuthService.getToken();
      final res = await http.get(
        Uri.parse("$baseUrl/photographer"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("📸 Status: ${res.statusCode}");
      print("📸 Body: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data is List) return data;
        if (data is Map && data["photographers"] is List) {
          return data["photographers"];
        }

        return [];
      }

      return [];
    } catch (e) {
      print("📸 Error: $e");
      return [];
    }
  }


  static Future<List<dynamic>> getNearbyPhotographers({
  required double lat,
  required double lng,
}) async {
  final token = await AuthService.getToken();

  final res = await http.get(
    Uri.parse('${AuthService.apiBase}/photographer/nearby?lat=$lat&lng=$lng'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    return data['photographers'] ?? [];
  } else {
    throw Exception('Failed to load nearby photographers');
  }
} 
}