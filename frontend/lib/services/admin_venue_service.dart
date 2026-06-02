import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AdminVenueService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api/admin/venues";
    }

    return "http://10.0.2.2:3000/api/admin/venues";
  }

  static Map<String, String> _headers(String token) {
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Future<Map<String, dynamic>> getVenues({
    String q = "",
    String filter = "all",
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        return {
          "summary": {},
          "venues": [],
        };
      }

      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          "filter": filter,
          if (q.trim().isNotEmpty) "q": q.trim(),
        },
      );

      final response = await http.get(
        uri,
        headers: _headers(token),
      );

      print("ADMIN VENUES STATUS: ${response.statusCode}");
      print("ADMIN VENUES BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map) {
          return {
            "summary": decoded["summary"] ?? {},
            "venues": decoded["venues"] ?? [],
          };
        }
      }

      return {
        "summary": {},
        "venues": [],
      };
    } catch (e) {
      print("ADMIN VENUES ERROR: $e");

      return {
        "summary": {},
        "venues": [],
      };
    }
  }

  static Future<Map<String, dynamic>?> getVenueDetails(int venueId) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return null;

      final response = await http.get(
        Uri.parse("$baseUrl/$venueId/details"),
        headers: _headers(token),
      );

      print("ADMIN VENUE DETAILS STATUS: ${response.statusCode}");
      print("ADMIN VENUE DETAILS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded["venue"] is Map<String, dynamic>) {
          return decoded["venue"];
        }

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      return null;
    } catch (e) {
      print("ADMIN VENUE DETAILS ERROR: $e");
      return null;
    }
  }

  static Future<bool> updateVisibility({
    required int venueId,
    required String visibility,
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/$venueId/visibility"),
        headers: _headers(token),
        body: jsonEncode({
          "visibility": visibility,
        }),
      );

      print("ADMIN VENUE VISIBILITY STATUS: ${response.statusCode}");
      print("ADMIN VENUE VISIBILITY BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN VENUE VISIBILITY ERROR: $e");
      return false;
    }
  }

  static Future<bool> updateReviewed({
    required int venueId,
    required bool reviewed,
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/$venueId/reviewed"),
        headers: _headers(token),
        body: jsonEncode({
          "reviewed": reviewed,
        }),
      );

      print("ADMIN VENUE REVIEWED STATUS: ${response.statusCode}");
      print("ADMIN VENUE REVIEWED BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN VENUE REVIEWED ERROR: $e");
      return false;
    }
  }

  static Future<bool> updateFlag({
    required int venueId,
    required bool flagged,
    String reason = "",
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/$venueId/flag"),
        headers: _headers(token),
        body: jsonEncode({
          "flagged": flagged,
          "reason": reason,
        }),
      );

      print("ADMIN VENUE FLAG STATUS: ${response.statusCode}");
      print("ADMIN VENUE FLAG BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN VENUE FLAG ERROR: $e");
      return false;
    }
  }
}