import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AdminClientService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api/admin/clients";
    }

    return "http://10.0.2.2:3000/api/admin/clients";
  }

  static Map<String, String> _headers(String token) {
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Future<Map<String, dynamic>> getClients({
    String q = "",
    String filter = "all",
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        return {
          "summary": {},
          "clients": [],
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

      print("ADMIN CLIENTS STATUS: ${response.statusCode}");
      print("ADMIN CLIENTS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map) {
          return {
            "summary": decoded["summary"] ?? {},
            "clients": decoded["clients"] ?? [],
          };
        }
      }

      return {
        "summary": {},
        "clients": [],
      };
    } catch (e) {
      print("ADMIN CLIENTS ERROR: $e");

      return {
        "summary": {},
        "clients": [],
      };
    }
  }

  static Future<Map<String, dynamic>?> getClientDetails(int clientId) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return null;

      final response = await http.get(
        Uri.parse("$baseUrl/$clientId/details"),
        headers: _headers(token),
      );

      print("ADMIN CLIENT DETAILS STATUS: ${response.statusCode}");
      print("ADMIN CLIENT DETAILS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded["client"] is Map<String, dynamic>) {
          return decoded["client"];
        }

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      return null;
    } catch (e) {
      print("ADMIN CLIENT DETAILS ERROR: $e");
      return null;
    }
  }

  static Future<bool> updateClientFlag({
    required int clientId,
    required bool flagged,
    String reason = "",
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/$clientId/flag"),
        headers: _headers(token),
        body: jsonEncode({
          "flagged": flagged,
          "reason": reason,
        }),
      );

      print("ADMIN CLIENT FLAG STATUS: ${response.statusCode}");
      print("ADMIN CLIENT FLAG BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN CLIENT FLAG ERROR: $e");
      return false;
    }
  }

  static Future<bool> updateBookingRestriction({
    required int clientId,
    required bool restricted,
    String reason = "",
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/$clientId/booking-restriction"),
        headers: _headers(token),
        body: jsonEncode({
          "restricted": restricted,
          "reason": reason,
        }),
      );

      print("ADMIN CLIENT BOOKING RESTRICTION STATUS: ${response.statusCode}");
      print("ADMIN CLIENT BOOKING RESTRICTION BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN CLIENT BOOKING RESTRICTION ERROR: $e");
      return false;
    }
  }
}