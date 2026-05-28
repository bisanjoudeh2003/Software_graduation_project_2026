import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AdminClientService {
  static String get baseUrl => "${AuthService.apiBase}/admin/clients";

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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("ADMIN CLIENTS STATUS: ${response.statusCode}");
      print("ADMIN CLIENTS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return {
          "summary": data["summary"] ?? {},
          "clients": data["clients"] ?? [],
        };
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("ADMIN CLIENT DETAILS STATUS: ${response.statusCode}");
      print("ADMIN CLIENT DETAILS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["client"];
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
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