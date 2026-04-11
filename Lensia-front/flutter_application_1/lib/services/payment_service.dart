import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PaymentService {

  static String get baseUrl => AuthService.apiBase;

  static Future<Map<String, dynamic>?> createPaymentIntent(
      int bookingId) async {
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

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)["error"] ?? "Failed");
  }

  static Future<bool> confirmPayment(
      int bookingId, String paymentIntentId) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

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

    return res.statusCode == 200;
  }
}