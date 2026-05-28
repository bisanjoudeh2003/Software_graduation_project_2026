import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AdminPhotographerService {
  static String get baseUrl => "${AuthService.apiBase}/admin/photographers";

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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("ADMIN PHOTOGRAPHERS STATUS: ${response.statusCode}");
      print("ADMIN PHOTOGRAPHERS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return {
          "summary": data["summary"] ?? {},
          "photographers": data["photographers"] ?? [],
        };
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("ADMIN PHOTOGRAPHER DETAILS STATUS: ${response.statusCode}");
      print("ADMIN PHOTOGRAPHER DETAILS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["photographer"];
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("ADMIN PHOTOGRAPHER PORTFOLIO STATUS: ${response.statusCode}");
      print("ADMIN PHOTOGRAPHER PORTFOLIO BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic>) {
          return data;
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
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