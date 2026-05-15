import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class WarehousePaymentService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }
    return "http://10.0.2.2:3000/api";
  }

  static Future<Map<String, dynamic>> createWarehousePaymentIntent({
    required int orderId,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.post(
      Uri.parse("$baseUrl/payments/create-warehouse-payment-intent"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "order_id": orderId,
      }),
    );

    Map<String, dynamic> body = {};

    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      throw Exception(
        "Payment endpoint returned HTML, not JSON. Check /api/payments route.",
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    throw Exception(body["message"] ?? body["error"] ?? "Failed to create payment intent");
  }

  static Future<Map<String, dynamic>> confirmWarehousePayment({
    required int orderId,
    required String paymentIntentId,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.post(
      Uri.parse("$baseUrl/payments/confirm-warehouse-payment"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "order_id": orderId,
        "payment_intent_id": paymentIntentId,
      }),
    );

    Map<String, dynamic> body = {};

    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      throw Exception(
        "Confirm payment endpoint returned HTML, not JSON. Check /api/payments route.",
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    throw Exception(body["message"] ?? body["error"] ?? "Failed to confirm payment");
  }
}