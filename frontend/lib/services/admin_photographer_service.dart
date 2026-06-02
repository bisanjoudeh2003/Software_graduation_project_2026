import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AdminPhotographerService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api/admin/photographers";
    }

    return "http://10.0.2.2:3000/api/admin/photographers";
  }

  static Map<String, String> _headers(String token) {
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Future<Map<String, dynamic>> getPhotographers({
    String q = "",
    String filter = "all",
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        return {
          "summary": {},
          "photographers": [],
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

      print("ADMIN PHOTOGRAPHERS STATUS: ${response.statusCode}");
      print("ADMIN PHOTOGRAPHERS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map) {
          return {
            "summary": decoded["summary"] ?? {},
            "photographers": decoded["photographers"] ?? [],
          };
        }
      }

      return {
        "summary": {},
        "photographers": [],
      };
    } catch (e) {
      print("ADMIN PHOTOGRAPHERS ERROR: $e");

      return {
        "summary": {},
        "photographers": [],
      };
    }
  }

  static Future<Map<String, dynamic>?> getPhotographerDetails(
    int photographerId,
  ) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return null;

      final response = await http.get(
        Uri.parse("$baseUrl/$photographerId/details"),
        headers: _headers(token),
      );

      print("ADMIN PHOTOGRAPHER DETAILS STATUS: ${response.statusCode}");
      print("ADMIN PHOTOGRAPHER DETAILS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded["photographer"] is Map<String, dynamic>) {
          return decoded["photographer"];
        }

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      return null;
    } catch (e) {
      print("ADMIN PHOTOGRAPHER DETAILS ERROR: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getPhotographerPortfolio(
    int photographerId,
  ) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return null;

      final response = await http.get(
        Uri.parse("$baseUrl/$photographerId/portfolio"),
        headers: _headers(token),
      );

      print("ADMIN PHOTOGRAPHER PORTFOLIO STATUS: ${response.statusCode}");
      print("ADMIN PHOTOGRAPHER PORTFOLIO BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      return null;
    } catch (e) {
      print("ADMIN PHOTOGRAPHER PORTFOLIO ERROR: $e");
      return null;
    }
  }

  static Future<bool> updateVisibility({
    required int photographerId,
    required String visibility,
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/$photographerId/visibility"),
        headers: _headers(token),
        body: jsonEncode({
          "visibility": visibility,
        }),
      );

      print("ADMIN PHOTOGRAPHER VISIBILITY STATUS: ${response.statusCode}");
      print("ADMIN PHOTOGRAPHER VISIBILITY BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN PHOTOGRAPHER VISIBILITY ERROR: $e");
      return false;
    }
  }

  static Future<bool> updatePortfolioReviewed({
    required int photographerId,
    required bool reviewed,
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/$photographerId/portfolio-reviewed"),
        headers: _headers(token),
        body: jsonEncode({
          "reviewed": reviewed,
        }),
      );

      print("ADMIN PHOTOGRAPHER REVIEWED STATUS: ${response.statusCode}");
      print("ADMIN PHOTOGRAPHER REVIEWED BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN PHOTOGRAPHER REVIEWED ERROR: $e");
      return false;
    }
  }

  static Future<bool> updateFlag({
    required int photographerId,
    required bool flagged,
    String reason = "",
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/$photographerId/flag"),
        headers: _headers(token),
        body: jsonEncode({
          "flagged": flagged,
          "reason": reason,
        }),
      );

      print("ADMIN PHOTOGRAPHER FLAG STATUS: ${response.statusCode}");
      print("ADMIN PHOTOGRAPHER FLAG BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN PHOTOGRAPHER FLAG ERROR: $e");
      return false;
    }
  }
}