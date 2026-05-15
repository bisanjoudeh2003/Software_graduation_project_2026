import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class WarehouseOwnerOrderService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }
    return "http://10.0.2.2:3000/api";
  }

  static String get warehouseUrl => "$baseUrl/warehouse";

  static Future<List<dynamic>> getOwnerOrders() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.get(
      Uri.parse("$warehouseUrl/owner/orders"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body["orders"] ?? [];
    }

    throw Exception(body["message"] ?? "Failed to load received orders");
  }

  static Future<Map<String, dynamic>> getOwnerOrderById(int orderId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.get(
      Uri.parse("$warehouseUrl/owner/orders/$orderId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body["order"] ?? {};
    }

    throw Exception(body["message"] ?? "Failed to load received order details");
  }

  static Future<Map<String, dynamic>> updateOrderStatus({
    required int orderId,
    required String status,
    String? ownerResponse,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.put(
      Uri.parse("$warehouseUrl/owner/orders/$orderId/status"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "status": status,
        "owner_response": ownerResponse,
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(body);
    }

    throw Exception(body["message"] ?? "Failed to update order status");
  }
}