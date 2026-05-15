import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class WarehouseDashboardService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }

    return "http://10.0.2.2:3000/api";
  }

  static String get warehouseUrl => "$baseUrl/warehouse";

  static Future<Map<String, dynamic>> getDashboard() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.get(
      Uri.parse("$warehouseUrl/dashboard"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(body["stats"] ?? {});
    }

    throw Exception(body["message"] ?? "Failed to load dashboard");
  }
}