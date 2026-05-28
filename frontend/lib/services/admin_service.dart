import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AdminService {
  static String get baseUrl => "${AuthService.apiBase}/admin";

  static Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      final token = await AuthService.getToken();

      if (token == null) return null;

      final response = await http.get(
        Uri.parse("$baseUrl/dashboard"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("ADMIN DASHBOARD STATUS: ${response.statusCode}");
      print("ADMIN DASHBOARD BODY: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("ADMIN USERS STATUS: ${response.statusCode}");
      print("ADMIN USERS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["users"] ?? [];
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("ADMIN USER DETAILS STATUS: ${response.statusCode}");
      print("ADMIN USER DETAILS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["user"];
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("ADMIN GET NOTES STATUS: ${response.statusCode}");
      print("ADMIN GET NOTES BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["notes"] ?? [];
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "note": note,
        }),
      );

      print("ADMIN ADD NOTE STATUS: ${response.statusCode}");
      print("ADMIN ADD NOTE BODY: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["note"];
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
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
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("ADMIN ACTIVITY LOGS STATUS: ${response.statusCode}");
      print("ADMIN ACTIVITY LOGS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["logs"] ?? [];
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
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("ADMIN ONLY LOGS STATUS: ${response.statusCode}");
    print("ADMIN ONLY LOGS BODY: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["admin_logs"] ?? data["logs"] ?? [];
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
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("USER ONLY LOGS STATUS: ${response.statusCode}");
    print("USER ONLY LOGS BODY: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["user_logs"] ?? [];
    }

    return [];
  } catch (e) {
    print("USER ONLY LOGS ERROR: $e");
    return [];
  }
}
}