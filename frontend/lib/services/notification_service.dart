import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class NotificationService {
  static String get baseUrl => "${AuthService.apiBase}/notifications";

  static Future<Map<String, dynamic>?> getMyNotifications() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("GET NOTIFICATIONS STATUS: ${response.statusCode}");
      debugPrint("GET NOTIFICATIONS BODY: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      debugPrint("GET NOTIFICATIONS ERROR: $e");
      return null;
    }
  }

  static Future<int> getUnreadCount() async {
    final data = await getMyNotifications();
    if (data == null) return 0;
    return data["unread_count"] ?? 0;
  }

  static Future<bool> markAsRead(int notificationId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.patch(
        Uri.parse("$baseUrl/$notificationId/read"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("MARK AS READ STATUS: ${response.statusCode}");
      debugPrint("MARK AS READ BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("MARK AS READ ERROR: $e");
      return false;
    }
  }

  static Future<bool> markAllAsRead() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.patch(
        Uri.parse("$baseUrl/read-all"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("MARK ALL AS READ STATUS: ${response.statusCode}");
      debugPrint("MARK ALL AS READ BODY: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("MARK ALL AS READ ERROR: $e");
      return false;
    }
  }
}