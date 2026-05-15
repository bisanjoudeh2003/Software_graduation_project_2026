import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class WarehouseOrderService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }
    return "http://10.0.2.2:3000/api";
  }

  static String get warehouseUrl => "$baseUrl/warehouse";

  static Future<List<dynamic>> getMyOrders() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.get(
      Uri.parse("$warehouseUrl/my-orders"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body["orders"] ?? [];
    }

    throw Exception(body["message"] ?? "Failed to load orders");
  }

  static Future<Map<String, dynamic>> getMyOrderById(int orderId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.get(
      Uri.parse("$warehouseUrl/my-orders/$orderId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body["order"] ?? {};
    }

    throw Exception(body["message"] ?? "Failed to load order details");
  }

  static Future<Map<String, dynamic>> cancelOrder(int orderId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.put(
      Uri.parse("$warehouseUrl/my-orders/$orderId/cancel"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body;
    }

    throw Exception(body["message"] ?? "Failed to cancel order");
  }

  static Future<Map<String, dynamic>> markOrderPaid({
    required int orderId,
    required String paymentIntentId,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.put(
      Uri.parse("$warehouseUrl/my-orders/$orderId/paid"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "payment_intent_id": paymentIntentId,
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body;
    }

    throw Exception(body["message"] ?? "Failed to update payment status");
  }
}