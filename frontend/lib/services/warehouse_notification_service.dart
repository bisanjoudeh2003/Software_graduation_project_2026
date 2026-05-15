import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class NotificationService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api";
    }

    return "http://10.0.2.2:3000/api";
  }

  static String get notificationsUrl => "$baseUrl/notifications";

  static Future<Map<String, dynamic>> getMyNotifications() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.get(
      Uri.parse(notificationsUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(body);
    }

    throw Exception(body["message"] ?? "Failed to load notifications");
  }

  static Future<void> markAsRead(int notificationId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.patch(
      Uri.parse("$notificationsUrl/$notificationId/read"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) return;

    final body = jsonDecode(response.body);
    throw Exception(body["message"] ?? "Failed to mark notification as read");
  }

  static Future<void> markAllAsRead() async {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final response = await http.patch(
      Uri.parse("$notificationsUrl/read-all"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) return;

    final body = jsonDecode(response.body);
    throw Exception(body["message"] ?? "Failed to mark all as read");
  }
}