import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

class PaymentService {
static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }
    return "http://10.0.2.2:3000/api";
  }
  static Future<Map<String, dynamic>?> createPaymentIntent(int bookingId) async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    final res = await http.post(
      Uri.parse("$baseUrl/payments/create-intent"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"booking_id": bookingId}),
    );

    print("CREATE PAYMENT INTENT STATUS: ${res.statusCode}");
    print("CREATE PAYMENT INTENT BODY: ${res.body}");

    if (res.statusCode == 200) return jsonDecode(res.body);

    final body = jsonDecode(res.body);
    throw Exception(body["error"] ?? "Failed");
  }

  static Future<Map<String, dynamic>> confirmPayment(
    int bookingId,
    String paymentIntentId,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        "success": false,
        "message": "User not authenticated",
      };
    }

    final res = await http.post(
      Uri.parse("$baseUrl/payments/confirm"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "booking_id": bookingId,
        "payment_intent_id": paymentIntentId,
      }),
    );

    print("CONFIRM PAYMENT STATUS: ${res.statusCode}");
    print("CONFIRM PAYMENT BODY: ${res.body}");

    if (res.statusCode == 200) {
      return {
        "success": true,
        "message": "Deposit paid successfully",
      };
    }

    try {
      final body = jsonDecode(res.body);
      return {
        "success": false,
        "message": body["error"] ?? "Payment confirmation failed",
      };
    } catch (_) {
      return {
        "success": false,
        "message": "Payment confirmation failed",
      };
    }
  }
}