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

  static Map<String, dynamic> _decodeResponse(
    http.Response response,
    String url,
  ) {
    debugPrint("WAREHOUSE ORDER URL: $url");
    debugPrint("WAREHOUSE ORDER STATUS: ${response.statusCode}");
    debugPrint("WAREHOUSE ORDER BODY: ${response.body}");

    final rawBody = response.body.trim();

    if (rawBody.isEmpty) {
      return {};
    }

    if (rawBody.startsWith("<!DOCTYPE html") || rawBody.startsWith("<html")) {
      throw Exception(
        "The server returned HTML instead of JSON. Check this API URL: $url",
      );
    }

    try {
      final decoded = jsonDecode(rawBody);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        "success": false,
        "message": "Unexpected response format from server",
        "data": decoded,
      };
    } catch (_) {
      throw Exception("Failed to read server response as JSON. URL: $url");
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Future<List<dynamic>> getMyOrders() async {
    final url = "$warehouseUrl/my-orders";

    final response = await http.get(
      Uri.parse(url),
      headers: await _headers(),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200) {
      return body["orders"] ?? [];
    }

    throw Exception(body["message"] ?? "Failed to load orders");
  }

  static Future<Map<String, dynamic>> getMyOrderById(int orderId) async {
    final url = "$warehouseUrl/my-orders/$orderId";

    final response = await http.get(
      Uri.parse(url),
      headers: await _headers(),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200) {
      return body["order"] ?? {};
    }

    throw Exception(body["message"] ?? "Failed to load order details");
  }

  static Future<Map<String, dynamic>> cancelOrder(int orderId) async {
    final url = "$warehouseUrl/my-orders/$orderId/cancel";

    final response = await http.put(
      Uri.parse(url),
      headers: await _headers(),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200) {
      return body;
    }

    throw Exception(body["message"] ?? "Failed to cancel order");
  }

  static Future<Map<String, dynamic>> markOrderPaid({
    required int orderId,
    required String paymentIntentId,
  }) async {
    final url = "$warehouseUrl/my-orders/$orderId/paid";

    final response = await http.put(
      Uri.parse(url),
      headers: await _headers(),
      body: jsonEncode({
        "payment_intent_id": paymentIntentId,
      }),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200) {
      return body;
    }

    throw Exception(body["message"] ?? "Failed to update payment status");
  }
}
