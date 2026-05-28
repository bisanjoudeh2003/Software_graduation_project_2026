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

  static String get warehouseUrl => "$baseUrl/warehouse";

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

  static Map<String, dynamic> _decodeResponse(
    http.Response response,
    String url,
  ) {
    debugPrint("WAREHOUSE PAYMENT URL: $url");
    debugPrint("WAREHOUSE PAYMENT STATUS: ${response.statusCode}");
    debugPrint("WAREHOUSE PAYMENT BODY: ${response.body}");

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

  static Future<Map<String, dynamic>> createWarehousePaymentIntent({
    required int orderId,
  }) async {
    final url = "$warehouseUrl/my-orders/$orderId/payment-intent";

    final response = await http.post(
      Uri.parse(url),
      headers: await _headers(),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    throw Exception(
      body["message"]?.toString() ??
          body["error"]?.toString() ??
          "Failed to create payment intent",
    );
  }

  static Future<Map<String, dynamic>> confirmWarehousePayment({
    required int orderId,
    required String paymentIntentId,
  }) async {
    final url = "$warehouseUrl/my-orders/$orderId/payment-intent/confirm";

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

    throw Exception(
      body["message"]?.toString() ??
          body["error"]?.toString() ??
          "Failed to confirm payment",
    );
  }

  static Future<Map<String, dynamic>> createWarehouseCheckoutSession({
    required int orderId,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final origin = Uri.base.origin;

    final successUrl =
        "$origin/#/warehouse-orders?payment=success&order_id=$orderId&session_id={CHECKOUT_SESSION_ID}";

    final cancelUrl =
        "$origin/#/warehouse-orders?payment=cancelled&order_id=$orderId";

    final url = "$warehouseUrl/my-orders/$orderId/checkout-session";

    final response = await http.post(
      Uri.parse(url),
      headers: await _headers(),
      body: jsonEncode({
        "success_url": successUrl,
        "cancel_url": cancelUrl,
      }),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    throw Exception(
      body["message"]?.toString() ??
          body["error"]?.toString() ??
          "Failed to create checkout session",
    );
  }

  static Future<Map<String, dynamic>> confirmWarehouseCheckoutSession({
    required int orderId,
    required String sessionId,
  }) async {
    final url = "$warehouseUrl/my-orders/$orderId/checkout-session/confirm";

    final response = await http.put(
      Uri.parse(url),
      headers: await _headers(),
      body: jsonEncode({
        "session_id": sessionId,
      }),
    );

    final body = _decodeResponse(response, url);

    if (response.statusCode == 200) {
      return body;
    }

    throw Exception(
      body["message"]?.toString() ??
          body["error"]?.toString() ??
          "Failed to confirm checkout payment",
    );
  }
}