import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AdminPostSessionService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api/admin/post-session";
    }

    return "http://10.0.2.2:3000/api/admin/post-session";
  }

  static Map<String, String> _headers(String token) {
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return {};

    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {};
  }

  static Future<Map<String, dynamic>> getPostSessionMonitor() async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("You are not logged in.");
      }

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: _headers(token),
      );

      print("ADMIN POST SESSION STATUS: ${response.statusCode}");
      print("ADMIN POST SESSION BODY: ${response.body}");

      final data = _decode(response.body);

      if (response.statusCode == 200) {
        return data;
      }

      throw Exception(
        data["message"] ?? data["error"] ?? "Failed to load post-session data.",
      );
    } catch (e) {
      print("ADMIN POST SESSION ERROR: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getSummary() async {
    final data = await getPostSessionMonitor();

    final summary = data["summary"];

    if (summary is Map<String, dynamic>) {
      return summary;
    }

    return {};
  }

  static Future<List<dynamic>> getSessions() async {
    final data = await getPostSessionMonitor();

    final sessions = data["sessions"];

    if (sessions is List) {
      return sessions;
    }

    return [];
  }

  static Future<Map<String, dynamic>> sendDeliveryReminder(
    int bookingId,
  ) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("You are not logged in.");
      }

      final response = await http.post(
        Uri.parse("$baseUrl/$bookingId/delivery-reminder"),
        headers: _headers(token),
      );

      print("DELIVERY REMINDER STATUS: ${response.statusCode}");
      print("DELIVERY REMINDER BODY: ${response.body}");

      final data = _decode(response.body);

      if (response.statusCode == 200) {
        return data;
      }

      throw Exception(
        data["message"] ?? data["error"] ?? "Failed to send delivery reminder.",
      );
    } catch (e) {
      print("DELIVERY REMINDER ERROR: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> sendPhotographerReviewReminder(
    int bookingId,
  ) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("You are not logged in.");
      }

      final response = await http.post(
        Uri.parse("$baseUrl/$bookingId/photographer-review-reminder"),
        headers: _headers(token),
      );

      print("PHOTOGRAPHER REVIEW REMINDER STATUS: ${response.statusCode}");
      print("PHOTOGRAPHER REVIEW REMINDER BODY: ${response.body}");

      final data = _decode(response.body);

      if (response.statusCode == 200) {
        return data;
      }

      throw Exception(
        data["message"] ??
            data["error"] ??
            "Failed to send photographer review reminder.",
      );
    } catch (e) {
      print("PHOTOGRAPHER REVIEW REMINDER ERROR: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> sendVenueReviewReminder(
    int bookingId,
  ) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("You are not logged in.");
      }

      final response = await http.post(
        Uri.parse("$baseUrl/$bookingId/venue-review-reminder"),
        headers: _headers(token),
      );

      print("VENUE REVIEW REMINDER STATUS: ${response.statusCode}");
      print("VENUE REVIEW REMINDER BODY: ${response.body}");

      final data = _decode(response.body);

      if (response.statusCode == 200) {
        return data;
      }

      throw Exception(
        data["message"] ??
            data["error"] ??
            "Failed to send venue review reminder.",
      );
    } catch (e) {
      print("VENUE REVIEW REMINDER ERROR: $e");
      rethrow;
    }
  }
}