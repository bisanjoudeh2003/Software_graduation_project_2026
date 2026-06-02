import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AdminService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api/admin";
    }

    return "http://10.0.2.2:3000/api/admin";
  }

  static Map<String, String> _headers(String token) {
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return null;

      final response = await http.get(
        Uri.parse("$baseUrl/dashboard"),
        headers: _headers(token),
      );

      print("ADMIN DASHBOARD STATUS: ${response.statusCode}");
      print("ADMIN DASHBOARD BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }

        return {};
      }

      return null;
    } catch (e) {
      print("ADMIN DASHBOARD ERROR: $e");
      return null;
    }
  }

  static Future<List<dynamic>> getUsers({
    String role = "all",
    String status = "all",
    String q = "",
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return [];

      final uri = Uri.parse("$baseUrl/users").replace(
        queryParameters: {
          "role": role,
          "status": status,
          if (q.trim().isNotEmpty) "q": q.trim(),
        },
      );

      final response = await http.get(
        uri,
        headers: _headers(token),
      );

      print("ADMIN USERS STATUS: ${response.statusCode}");
      print("ADMIN USERS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded["users"] is List) {
          return decoded["users"];
        }

        if (decoded is List) {
          return decoded;
        }

        return [];
      }

      return [];
    } catch (e) {
      print("ADMIN USERS ERROR: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getUserDetails(int userId) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return null;

      final response = await http.get(
        Uri.parse("$baseUrl/users/$userId/details"),
        headers: _headers(token),
      );

      print("ADMIN USER DETAILS STATUS: ${response.statusCode}");
      print("ADMIN USER DETAILS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded["user"] is Map<String, dynamic>) {
          return decoded["user"];
        }

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }

        return null;
      }

      return null;
    } catch (e) {
      print("ADMIN USER DETAILS ERROR: $e");
      return null;
    }
  }

  static Future<bool> updateUserStatus({
    required int userId,
    required String status,
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/users/$userId/status"),
        headers: _headers(token),
        body: jsonEncode({
          "status": status,
        }),
      );

      print("ADMIN UPDATE USER STATUS: ${response.statusCode}");
      print("ADMIN UPDATE USER BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN UPDATE USER ERROR: $e");
      return false;
    }
  }

  static Future<List<dynamic>> getUserAdminNotes(int userId) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return [];

      final response = await http.get(
        Uri.parse("$baseUrl/users/$userId/notes"),
        headers: _headers(token),
      );

      print("ADMIN GET NOTES STATUS: ${response.statusCode}");
      print("ADMIN GET NOTES BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded["notes"] is List) {
          return decoded["notes"];
        }

        if (decoded is List) {
          return decoded;
        }

        return [];
      }

      return [];
    } catch (e) {
      print("ADMIN GET NOTES ERROR: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addUserAdminNote({
    required int userId,
    required String note,
  }) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return null;

      final response = await http.post(
        Uri.parse("$baseUrl/users/$userId/notes"),
        headers: _headers(token),
        body: jsonEncode({
          "note": note,
        }),
      );

      print("ADMIN ADD NOTE STATUS: ${response.statusCode}");
      print("ADMIN ADD NOTE BODY: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded["note"] is Map<String, dynamic>) {
          return decoded["note"];
        }

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }

        return null;
      }

      return null;
    } catch (e) {
      print("ADMIN ADD NOTE ERROR: $e");
      return null;
    }
  }

  static Future<bool> deleteAdminNote(int noteId) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return false;

      final response = await http.delete(
        Uri.parse("$baseUrl/notes/$noteId"),
        headers: _headers(token),
      );

      print("ADMIN DELETE NOTE STATUS: ${response.statusCode}");
      print("ADMIN DELETE NOTE BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("ADMIN DELETE NOTE ERROR: $e");
      return false;
    }
  }

  static Future<List<dynamic>> getUserActivityLogs(int userId) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return [];

      final response = await http.get(
        Uri.parse("$baseUrl/users/$userId/activity-logs"),
        headers: _headers(token),
      );

      print("ADMIN ACTIVITY LOGS STATUS: ${response.statusCode}");
      print("ADMIN ACTIVITY LOGS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded["logs"] is List) {
          return decoded["logs"];
        }

        if (decoded is List) {
          return decoded;
        }

        return [];
      }

      return [];
    } catch (e) {
      print("ADMIN ACTIVITY LOGS ERROR: $e");
      return [];
    }
  }

  static Future<List<dynamic>> getAdminActivityLogs(int userId) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return [];

      final response = await http.get(
        Uri.parse("$baseUrl/users/$userId/activity-logs"),
        headers: _headers(token),
      );

      print("ADMIN ONLY LOGS STATUS: ${response.statusCode}");
      print("ADMIN ONLY LOGS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded["admin_logs"] is List) {
          return decoded["admin_logs"];
        }

        if (decoded is Map && decoded["logs"] is List) {
          return decoded["logs"];
        }

        if (decoded is List) {
          return decoded;
        }

        return [];
      }

      return [];
    } catch (e) {
      print("ADMIN ONLY LOGS ERROR: $e");
      return [];
    }
  }

  static Future<List<dynamic>> getUserOnlyActivityLogs(int userId) async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return [];

      final response = await http.get(
        Uri.parse("$baseUrl/users/$userId/activity-logs"),
        headers: _headers(token),
      );

      print("USER ONLY LOGS STATUS: ${response.statusCode}");
      print("USER ONLY LOGS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded["user_logs"] is List) {
          return decoded["user_logs"];
        }

        return [];
      }

      return [];
    } catch (e) {
      print("USER ONLY LOGS ERROR: $e");
      return [];
    }
  }
}