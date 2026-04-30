import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PhotographerReviewService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }

    return 'http://10.0.2.2:3000/api';
  }

  static Future<Map<String, dynamic>> createReview({
    required int bookingId,
    required int rating,
    String? comment,
  }) async {
    final token = await AuthService.getToken();

    final res = await http.post(
      Uri.parse("$baseUrl/photographer-reviews"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "booking_id": bookingId,
        "rating": rating,
        "comment": comment?.trim() ?? "",
      }),
    );

    final data = jsonDecode(res.body);

    return {
      "statusCode": res.statusCode,
      "data": data,
    };
  }
}